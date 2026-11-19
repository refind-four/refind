import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../model/model.dart';
import 'input_checks.dart';
import 'refind_repository.dart';
import 'repository_exception.dart';

/// Betrieb über Supabase (Konzept 4.2.3, Schnittstelle I2).
///
/// Konto: Supabase Auth. Daten: Tabellen aus supabase/01_tabellen.sql.
/// Was jemand lesen und schreiben darf, entscheiden die RLS-Regeln in der
/// Datenbank (supabase/02_rls_regeln.sql), nicht diese Klasse.
///
/// Umgesetzt sind UC1 (Konto), UC3 (Gesuch erfassen, Meine Gesuche),
/// UC6 (Angebot senden) und UC7 (Angebote ansehen und annehmen).
/// Die übrigen Methoden folgen mit ihren Use Cases.
class SupabaseRefindRepository implements RefindRepository {
  SupabaseRefindRepository(this._client, {this.photoBucket});

  final SupabaseClient _client;

  /// Name des Buckets in Supabase Storage für die Fotos der Angebote.
  /// Solange er leer ist (Dateiablage noch nicht eingerichtet), speichert
  /// [createOffer] das Angebot ohne Fotos. Siehe ABWEICHUNGEN.md.
  final String? photoBucket;

  // ---------------------------------------------------------------------
  // Hilfsfunktionen
  // ---------------------------------------------------------------------

  /// Id der angemeldeten Person. Ohne Sitzung: nichtBerechtigt.
  String get _me {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const RepositoryException(
        RepositoryErrorKind.nichtBerechtigt,
        'Bitte zuerst anmelden.',
      );
    }
    return id;
  }

  /// Führt einen Aufruf aus und übersetzt Fehler von Supabase in eine
  /// RepositoryException, wie sie auch das Mock wirft.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e, stack) {
      Error.throwWithStackTrace(mapSupabaseError(e), stack);
    }
  }

  // ---------------------------------------------------------------------
  // Konto (UC1, UC2)
  // ---------------------------------------------------------------------

  @override
  Future<void> signUp(String displayName, String email, String password) async {
    final name = displayName.trim();
    final mail = email.trim().toLowerCase();
    checkSignUp(name, mail, password);
    await _guard(() async {
      // display_name übernimmt der Trigger on_auth_user_created ins Profil.
      final res = await _client.auth.signUp(
        email: mail,
        password: password,
        data: {'display_name': name},
      );
      // Ist die Mailbestätigung im Projekt ausgeschaltet, meldet Supabase
      // sofort an. Die App erwartet aber wie beim Mock, dass man sich danach
      // selbst anmeldet. Darum die Sitzung gleich wieder schliessen.
      if (res.session != null) {
        await _client.auth.signOut(scope: SignOutScope.local);
      }
    });
  }

  @override
  Future<User> signIn(String email, String password) {
    return _guard(() async {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return _loadProfile(_me);
    });
  }

  /// Verrät nicht, ob es das Konto gibt: Fehler vom Server werden
  /// verschluckt, ausser «keine Verbindung» und «zu viele Versuche».
  @override
  Future<void> resendConfirmation(String email) {
    return _guard(() async {
      try {
        await _client.auth.resend(
          type: OtpType.signup,
          email: email.trim().toLowerCase(),
        );
      } on AuthRetryableFetchException {
        rethrow;
      } on AuthException catch (e) {
        if (_isRateLimit(e)) rethrow;
      }
    });
  }

  @override
  Future<void> registerPushToken(String token) {
    return _guard(() async {
      await _client.from('push_token').upsert({
        'token': token,
        'profile_id': _me,
      });
    });
  }

  @override
  Future<void> signOut() {
    return _guard(() async {
      final id = _client.auth.currentUser?.id;
      if (id != null) {
        // Nach dem Abmelden sollen keine Mitteilungen mehr kommen.
        await _client.from('push_token').delete().eq('profile_id', id);
      }
      await _client.auth.signOut();
    });
  }

  @override
  Future<User> getMyProfile() => _guard(() => _loadProfile(_me));

  Future<User> _loadProfile(String id) async {
    final row = await _client.from('profile').select().eq('id', id).single();
    return userFromRow(row);
  }

  @override
  Future<User> updateProfile(
    String displayName,
    int cityId,
    int radiusKm,
    File? avatar,
  ) =>
      throw UnimplementedError('updateProfile folgt mit UC2.');

  @override
  Future<void> deleteAccount() =>
      throw UnimplementedError('deleteAccount folgt mit UC2.');

  /// Sucht nach Postleitzahl (nur Ziffern) oder nach Ortsname.
  @override
  Future<List<Place>> searchPlaces(String query) {
    final q = query.trim();
    if (q.isEmpty || q.length > 50) return Future.value(const []);
    return _guard(() async {
      final base = _client.from('place').select();
      final List<Map<String, dynamic>> rows;
      if (RegExp(r'^\d{1,4}$').hasMatch(q)) {
        // «30» findet 3000 bis 3099, wie «beginnt mit» beim Mock.
        final factor = [1000, 100, 10, 1][q.length - 1];
        final from = int.parse(q) * factor;
        rows = await base
            .gte('plz', from)
            .lt('plz', from + factor)
            .order('plz')
            .limit(20);
      } else {
        // % und _ sind in ilike Platzhalter. Aus der Eingabe gelten sie
        // als normale Zeichen.
        final escaped = q.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
        rows = await base.ilike('name', '%$escaped%').order('name').limit(20);
      }
      return rows.map(placeFromRow).toList();
    });
  }

  @override
  Future<Place> getPlace(int placeId) {
    return _guard(() async {
      _me;
      final row =
          await _client.from('place').select().eq('id', placeId).maybeSingle();
      if (row == null) {
        throw const RepositoryException(
          RepositoryErrorKind.ungueltigeEingabe,
          'Ortschaft nicht gefunden.',
        );
      }
      return placeFromRow(row);
    });
  }

  // ---------------------------------------------------------------------
  // Gesuche (UC3, UC4)
  // ---------------------------------------------------------------------

  @override
  Future<Want> createWant(WantDraft draft) async {
    checkWantDraft(draft);
    return _guard(() async {
      final description = draft.description.trim();
      final row = await _client
          .from('want')
          .insert({
            'owner_id': _me,
            'title': draft.title.trim(),
            'category': draft.category,
            'description': description.isEmpty ? null : description,
            'budget_max': draft.budgetMaxRappen,
            'condition': draft.condition,
            'region_id': draft.regionId,
            'radius_km': draft.radiusKm,
            // Ablaufdatum rechnet die App aus (siehe ABWEICHUNGEN.md).
            'expires_at': DateTime.now()
                .toUtc()
                .add(Duration(days: draft.durationDays))
                .toIso8601String(),
          })
          .select()
          .single();
      return wantFromRow(row);
    });
  }

  @override
  Future<List<WantSummary>> getMyWants() {
    return _guard(() async {
      // Ein Aufruf: Gesuche mit Region und dem Status aller Angebote.
      final rows = await _client
          .from('want')
          .select('*, region:place(*), offer(status)')
          .eq('owner_id', _me)
          .order('created_at', ascending: false);
      return rows.map((row) {
        final offers = (row['offer'] as List).cast<Map<String, dynamic>>();
        return WantSummary(
          want: wantFromRow(row),
          offerCount: offers.length,
          newOfferCount: offers.where((o) => o['status'] == 'neu').length,
          region: placeFromRow(row['region'] as Map<String, dynamic>),
        );
      }).toList();
    });
  }

  @override
  Future<Want> updateWant(String wantId, WantDraft draft) =>
      throw UnimplementedError('updateWant folgt mit UC4.');

  @override
  Future<void> setWantStatus(String wantId, WantStatus status) =>
      throw UnimplementedError('setWantStatus folgt mit UC4.');

  @override
  Future<Want> republishWant(String wantId) =>
      throw UnimplementedError('republishWant folgt mit UC4.');

  // ---------------------------------------------------------------------
  // Entdecken und Angebote (UC5 bis UC7)
  // ---------------------------------------------------------------------

  /// VORLÄUFIG, bis UC5 umgesetzt ist: nur damit man auf dem Handy ein
  /// Gesuch für «Angebot senden» wählen kann. Kategorie wird in der
  /// Datenbank gefiltert, Suchtext und Umkreis in der App. Gesuche, bei
  /// denen schon ein Angebot angenommen ist, erscheinen noch (die App darf
  /// fremde Angebote nicht lesen). Siehe ABWEICHUNGEN.md.
  @override
  Future<List<FeedItem>> getFeed(FeedFilter filter) {
    return _guard(() async {
      var query = _client
          .from('want')
          .select('*, region:place(*), owner:profile(display_name)')
          .neq('owner_id', _me)
          .eq('status', 'aktiv')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      if (filter.category != null) query = query.eq('category', filter.category!);
      final rows = await query.order('created_at', ascending: false).limit(50);

      final origin = filter.placeId == null ? null : await getPlace(filter.placeId!);
      final text = filter.query?.trim().toLowerCase() ?? '';
      final items = <FeedItem>[];
      for (final row in rows) {
        final item = feedItemFromRow(row, origin: origin);
        if (text.isNotEmpty &&
            !item.want.title.toLowerCase().contains(text) &&
            !item.want.description.toLowerCase().contains(text)) {
          continue;
        }
        final distance = item.distanceKm;
        if (distance != null && filter.radiusKm != null && distance > filter.radiusKm!) {
          continue;
        }
        items.add(item);
      }
      return items;
    });
  }

  /// UC6: Angebot speichern, dann die Fotos hochladen.
  ///
  /// Ablauf: 1. Zeile in `offer` (RLS offer_insert prüft: nicht das eigene
  /// Gesuch, Gesuch aktiv und offen). 2. Jedes Foto nach Storage unter
  /// `<offerId>/<n>.jpg`. 3. Je Foto eine Zeile in `photo` mit diesem Pfad.
  @override
  Future<Offer> createOffer(
    String wantId,
    int priceRappen,
    String message,
    List<File> photos,
  ) async {
    checkOffer(priceRappen, message, photos.length);
    final text = message.trim();
    final me = _me;
    final row = await _guard(() async {
      try {
        return await _client
            .from('offer')
            .insert({
              'want_id': wantId,
              'seller_id': me,
              'price': priceRappen,
              'message': text.isEmpty ? null : text,
            })
            .select('*, seller:profile(display_name)')
            .single();
      } on PostgrestException catch (e) {
        // Beim Einfügen heisst 42501: RLS offer_insert sagt nein. Das ist
        // ein eigenes Gesuch oder eines, das keine Angebote mehr annimmt.
        if (e.code == '42501') {
          throw const RepositoryException(
            RepositoryErrorKind.konflikt,
            'Auf dieses Gesuch kannst du kein Angebot (mehr) senden.',
          );
        }
        rethrow;
      }
    });
    final offer = offerFromRow(row);
    // Das Angebot ist jetzt gespeichert. Scheitern danach die Fotos, soll
    // die Person es nicht nochmals senden (sonst gibt es zwei Angebote).
    // Darum: Angebot ohne (alle) Fotos zurückgeben, die Maske meldet das.
    List<Photo> saved;
    try {
      saved = await _uploadOfferPhotos(offer.id, photos);
    } on RepositoryException catch (e) {
      if (kDebugMode) debugPrint('Fotos nicht gespeichert: $e');
      saved = const [];
    }
    return Offer(
      id: offer.id,
      wantId: offer.wantId,
      sellerId: offer.sellerId,
      priceRappen: offer.priceRappen,
      message: offer.message,
      createdAt: offer.createdAt,
      status: offer.status,
      photos: saved,
      sellerName: offer.sellerName,
    );
  }

  /// Lädt die Fotos hoch und trägt sie in `photo` ein. Ohne [photoBucket]
  /// (Dateiablage noch nicht eingerichtet) passiert nichts.
  Future<List<Photo>> _uploadOfferPhotos(String offerId, List<File> photos) async {
    final bucket = photoBucket;
    if (photos.isEmpty) return const [];
    if (bucket == null) {
      if (kDebugMode) {
        debugPrint('Fotos nicht hochgeladen: Dateiablage noch nicht eingerichtet.');
      }
      return const [];
    }
    return _guard(() async {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < photos.length; i++) {
        final path = '$offerId/${i + 1}.jpg';
        await _client.storage.from(bucket).upload(
              path,
              photos[i],
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        rows.add({'offer_id': offerId, 'url': path});
      }
      final saved = await _client.from('photo').insert(rows).select();
      return saved.map(photoFromRow).toList();
    });
  }

  /// UC7: Angebote zu einem Gesuch. Die RLS-Regel offer_select liefert dem
  /// Besitzer alle Angebote, allen anderen nur die eigenen.
  @override
  Future<List<Offer>> getOffers(String wantId, OfferSort sort) {
    return _guard(() async {
      final base = _client
          .from('offer')
          .select('*, photo(*), seller:profile(display_name)')
          .eq('want_id', wantId);
      final rows = switch (sort) {
        OfferSort.neueste => await base.order('created_at', ascending: false),
        OfferSort.guenstigste => await base.order('price', ascending: true),
      };
      final offers = rows.map(offerFromRow).toList();
      return _withPhotoUrls(offers);
    });
  }

  /// Ersetzt die Pfade der Fotos durch Links, die eine Stunde gültig sind.
  /// Klappt das nicht, bleiben die Pfade (die App zeigt dann ein Symbol).
  Future<List<Offer>> _withPhotoUrls(List<Offer> offers) async {
    final bucket = photoBucket;
    final paths = [for (final o in offers) ...o.photos.map((p) => p.url)];
    if (bucket == null || paths.isEmpty) return offers;
    try {
      final signed = await _client.storage.from(bucket).createSignedUrls(paths, 3600);
      final urlByPath = {for (final s in signed) s.path: s.signedUrl};
      return [
        for (final o in offers)
          Offer(
            id: o.id,
            wantId: o.wantId,
            sellerId: o.sellerId,
            priceRappen: o.priceRappen,
            message: o.message,
            createdAt: o.createdAt,
            status: o.status,
            sellerName: o.sellerName,
            photos: [
              for (final p in o.photos)
                Photo(id: p.id, offerId: p.offerId, url: urlByPath[p.url] ?? p.url),
            ],
          ),
      ];
    } on StorageException catch (e) {
      if (kDebugMode) debugPrint('Fotos ohne Link: $e');
      return offers;
    }
  }

  /// UC7: Der Käufer darf den Status eines Angebots wegen RLS nicht selbst
  /// ändern. Darum ruft die App die Funktion mark_offers_seen auf
  /// (supabase/09_angebote.sql).
  @override
  Future<void> markOffersSeen(String wantId) {
    return _guard(() async {
      await _client.rpc('mark_offers_seen', params: {'p_want_id': wantId});
    });
  }

  /// UC7 / F-12: Angebot annehmen über die Funktion accept_offer
  /// (supabase/08_angebot_annehmen.sql). Sie nimmt an, sagt die übrigen
  /// ab und legt den Chat an, alles in einer Transaktion.
  @override
  Future<ChatThread> acceptOffer(String offerId) {
    return _guard(() async {
      final threadId =
          await _client.rpc('accept_offer', params: {'p_offer_id': offerId}) as String;
      final row =
          await _client.from('chat_thread').select().eq('id', threadId).single();
      return chatThreadFromRow(row);
    });
  }

  @override
  Future<List<ChatSummary>> getChats() =>
      throw UnimplementedError('getChats folgt mit UC8.');

  @override
  Stream<List<Message>> watchMessages(String threadId) =>
      throw UnimplementedError('watchMessages folgt mit UC8.');

  @override
  Future<Message> sendText(String threadId, String text) =>
      throw UnimplementedError('sendText folgt mit UC8.');

  @override
  Future<Message> sendPhoto(String threadId, File photo) =>
      throw UnimplementedError('sendPhoto folgt mit UC8.');

  @override
  Future<void> markRead(String threadId) =>
      throw UnimplementedError('markRead folgt mit UC8.');

  @override
  Future<void> setHandover(String threadId, DateTime at, String place) =>
      throw UnimplementedError('setHandover folgt mit UC8.');

  @override
  Future<void> closeDeal(String threadId, int agreedPriceRappen) =>
      throw UnimplementedError('closeDeal folgt mit UC9.');

  @override
  Future<void> rateUser(String threadId, int stars) =>
      throw UnimplementedError('rateUser folgt mit UC9.');

  @override
  Future<ProfileStats> getProfileStats(String userId) =>
      throw UnimplementedError('getProfileStats folgt mit UC2.');
}

// -----------------------------------------------------------------------
// Umwandlung Datenbankzeile → Modell. Öffentlich, damit Tests sie prüfen
// können, ohne Supabase zu brauchen.
// -----------------------------------------------------------------------

Place placeFromRow(Map<String, dynamic> row) => Place(
      id: row['id'] as int,
      plz: row['plz'] as int,
      name: row['name'] as String,
      e: row['e'] as int,
      n: row['n'] as int,
    );

User userFromRow(Map<String, dynamic> row) => User(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      cityId: row['city_id'] as int?,
      avatarUrl: row['avatar_url'] as String?,
      radiusKm: row['radius_km'] as int,
      memberSince: DateTime.parse(row['member_since'] as String),
    );

/// Ein aktives Gesuch, dessen Ablaufdatum vorbei ist, zeigt die App als
/// «abgelaufen», auch wenn in der Datenbank noch «aktiv» steht.
Want wantFromRow(Map<String, dynamic> row, {DateTime? now}) {
  final expiresAt = DateTime.parse(row['expires_at'] as String).toLocal();
  var status = WantStatus.values.byName(row['status'] as String);
  if (status == WantStatus.aktiv && expiresAt.isBefore(now ?? DateTime.now())) {
    status = WantStatus.abgelaufen;
  }
  return Want(
    id: row['id'] as String,
    ownerId: row['owner_id'] as String,
    title: row['title'] as String,
    category: row['category'] as String,
    description: (row['description'] as String?) ?? '',
    budgetMaxRappen: row['budget_max'] as int,
    condition: row['condition'] as String,
    regionId: row['region_id'] as int,
    radiusKm: row['radius_km'] as int,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    expiresAt: expiresAt,
    status: status,
  );
}

/// Angebot mit Fotos (`photo(*)`) und Name des Verkäufers
/// (`seller:profile(display_name)`), beides freiwillig mitgeladen.
Offer offerFromRow(Map<String, dynamic> row) {
  final photos = (row['photo'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final seller = row['seller'] as Map<String, dynamic>?;
  return Offer(
    id: row['id'] as String,
    wantId: row['want_id'] as String,
    sellerId: row['seller_id'] as String,
    priceRappen: row['price'] as int,
    message: (row['message'] as String?) ?? '',
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: OfferStatus.values.byName(row['status'] as String),
    photos: photos.map(photoFromRow).toList(),
    sellerName: seller?['display_name'] as String?,
  );
}

Photo photoFromRow(Map<String, dynamic> row) => Photo(
      id: row['id'] as String,
      offerId: row['offer_id'] as String,
      url: row['url'] as String,
    );

ChatThread chatThreadFromRow(Map<String, dynamic> row) {
  DateTime? time(String key) =>
      row[key] == null ? null : DateTime.parse(row[key] as String).toLocal();
  return ChatThread(
    id: row['id'] as String,
    offerId: row['offer_id'] as String,
    wantId: row['want_id'] as String,
    buyerId: row['buyer_id'] as String,
    sellerId: row['seller_id'] as String,
    lastActivity: time('last_activity')!,
    handoverAt: time('handover_at'),
    handoverPlace: row['handover_place'] as String?,
    agreedPriceRappen: row['agreed_price'] as int?,
    closedAt: time('closed_at'),
  );
}

/// Gesuch im Feed mit Region (`region:place(*)`) und Name des Käufers
/// (`owner:profile(display_name)`).
FeedItem feedItemFromRow(Map<String, dynamic> row, {Place? origin}) {
  final region = placeFromRow(row['region'] as Map<String, dynamic>);
  final owner = row['owner'] as Map<String, dynamic>?;
  return FeedItem(
    want: wantFromRow(row),
    buyerName: (owner?['display_name'] as String?) ?? 'Unbekannt',
    region: region,
    distanceKm: origin?.distanceKmTo(region),
  );
}

// -----------------------------------------------------------------------
// Fehler übersetzen
// -----------------------------------------------------------------------

bool _isRateLimit(AuthException e) =>
    e.statusCode == '429' ||
    e.code == 'over_request_rate_limit' ||
    e.code == 'over_email_send_rate_limit';

/// Übersetzt einen Fehler von Supabase in eine RepositoryException.
///
/// Die Meldungen sind verständlich, verraten aber keine Details vom Server
/// (Factsheet Inputvalidierung). Den Originalfehler sieht man nur beim
/// Entwickeln in der Konsole. Fehler, die nicht von Supabase oder vom Netz
/// kommen (Programmierfehler), werden unverändert weitergegeben.
Object mapSupabaseError(Object e) {
  if (e is RepositoryException) return e;
  if (kDebugMode) debugPrint('Supabase-Fehler: $e');

  RepositoryException ex(RepositoryErrorKind kind, String message) =>
      RepositoryException(kind, message);

  // Netz weg oder Server nicht erreichbar.
  if (e is AuthRetryableFetchException ||
      e is SocketException ||
      e is TimeoutException ||
      e is http.ClientException) {
    return ex(RepositoryErrorKind.keineVerbindung,
        'Keine Verbindung. Bitte prüfe dein Internet und versuche es nochmals.');
  }

  if (e is AuthException) {
    if (_isRateLimit(e)) {
      return ex(RepositoryErrorKind.nichtBerechtigt,
          'Zu viele Versuche. Bitte warte ein paar Minuten.');
    }
    if (e is AuthWeakPasswordException || e.code == 'weak_password') {
      return ex(RepositoryErrorKind.ungueltigeEingabe,
          'Das Passwort muss $minPasswordLength bis $maxPasswordLength '
          'Zeichen lang sein.');
    }
    if (e is AuthSessionMissingException) {
      return ex(RepositoryErrorKind.nichtBerechtigt, 'Bitte melde dich erneut an.');
    }
    switch (e.code) {
      case 'invalid_credentials':
        return ex(RepositoryErrorKind.nichtBerechtigt,
            'Mailadresse oder Passwort ist falsch.');
      case 'email_not_confirmed':
        return ex(RepositoryErrorKind.mailNichtBestaetigt,
            'Bitte bestätige zuerst deine Mailadresse über den Link in der Mail.');
      case 'user_already_exists':
      case 'email_exists':
        // UC1: nichts über das bestehende Konto verraten.
        return ex(RepositoryErrorKind.konflikt,
            'Die Registrierung ist mit diesen Angaben nicht möglich.');
      case 'email_address_invalid':
      case 'validation_failed':
        return ex(RepositoryErrorKind.ungueltigeEingabe,
            'Bitte gib eine gültige Mailadresse ein.');
      case 'session_not_found':
      case 'session_expired':
      case 'refresh_token_not_found':
      case 'bad_jwt':
        return ex(RepositoryErrorKind.nichtBerechtigt, 'Bitte melde dich erneut an.');
    }
    return ex(RepositoryErrorKind.konflikt,
        'Das hat nicht geklappt. Bitte versuche es später nochmals.');
  }

  // Dateiablage (Fotos der Angebote)
  if (e is StorageException) {
    switch (e.statusCode) {
      case '413':
        return ex(RepositoryErrorKind.ungueltigeEingabe,
            'Ein Foto ist zu gross. Bitte wähle ein kleineres.');
      case '401':
      case '403':
        return ex(RepositoryErrorKind.nichtBerechtigt,
            'Dafür fehlt dir die Berechtigung.');
    }
    return ex(RepositoryErrorKind.konflikt,
        'Die Fotos konnten nicht hochgeladen werden. Bitte versuche es später nochmals.');
  }

  if (e is PostgrestException) {
    switch (e.code) {
      // Eigene Fehler aus accept_offer (supabase/08_angebot_annehmen.sql):
      // P0001 = Gesuch nicht mehr aktiv, schon angenommen oder Angebot
      // abgesagt. P0002 = Angebot gibt es nicht.
      case 'P0001':
        return ex(RepositoryErrorKind.konflikt, acceptConflictMessage);
      case 'P0002':
        return ex(RepositoryErrorKind.ungueltigeEingabe,
            'Das Angebot wurde nicht gefunden.');
      // CHECK-Regel, Fremdschlüssel, Pflichtfeld, falscher Wert, zu lang
      case '23514':
      case '23503':
      case '23502':
      case '22P02':
      case '22001':
        return ex(RepositoryErrorKind.ungueltigeEingabe,
            'Die Angaben sind ungültig. Bitte prüfe deine Eingaben.');
      // RLS-Regel oder fehlendes Recht
      case '42501':
        return ex(RepositoryErrorKind.nichtBerechtigt,
            'Dafür fehlt dir die Berechtigung.');
      // Sitzung abgelaufen
      case 'PGRST301':
      case 'PGRST303':
        return ex(RepositoryErrorKind.nichtBerechtigt, 'Bitte melde dich erneut an.');
      // .single() ohne Treffer, z.B. kein Profil
      case 'PGRST116':
        return ex(RepositoryErrorKind.ungueltigeEingabe, 'Nicht gefunden.');
      case '23505':
        return ex(RepositoryErrorKind.konflikt, 'Diese Angabe gibt es schon.');
    }
    return ex(RepositoryErrorKind.konflikt,
        'Das hat nicht geklappt. Bitte versuche es später nochmals.');
  }

  return e;
}
