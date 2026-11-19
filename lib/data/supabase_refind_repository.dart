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
/// Umgesetzt sind UC1 (Konto) und UC3 (Gesuch erfassen, Meine Gesuche).
/// Die übrigen Methoden folgen mit ihren Use Cases.
class SupabaseRefindRepository implements RefindRepository {
  SupabaseRefindRepository(this._client);

  final SupabaseClient _client;

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
        rows = await base.ilike('name', containsPattern(q)).order('name').limit(20);
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
  // Entdecken (UC5)
  // ---------------------------------------------------------------------

  /// Welche Gesuche sichtbar sind, entscheidet die Funktion get_feed in der
  /// Datenbank (supabase/09_feed.sql). Nur sie darf prüfen, ob es zu einem
  /// fremden Gesuch ein angenommenes Angebot gibt. Kategorie und Suchbegriff
  /// filtert ebenfalls die Datenbank, damit nur passende Zeilen über das
  /// Netz kommen. Den Umkreis rechnet die App (FilterLogic im FeedService).
  @override
  Future<List<FeedItem>> getFeed(FeedFilter filter) async {
    checkFeedFilter(filter);
    return _guard(() async {
      _me;
      // Filter zuerst, dann select: so verlangt es das Paket postgrest.
      var query = _client.rpc('get_feed');
      final category = filter.category;
      if (category != null) query = query.eq('category', category);
      final q = (filter.query ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
      if (q.isNotEmpty) query = query.ilike('title', containsPattern(q));
      final rows = await query
          .select('*, region:place(*), owner:profile(display_name)')
          .order('created_at', ascending: false)
          .limit(maxFeedItems);
      return rows.map(feedItemFromRow).toList();
    });
  }

  // ---------------------------------------------------------------------
  // Angebote, Chat, Bewertung (UC6 bis UC9): folgen später
  // ---------------------------------------------------------------------

  @override
  Future<Offer> createOffer(
    String wantId,
    int priceRappen,
    String message,
    List<File> photos,
  ) =>
      throw UnimplementedError('createOffer folgt mit UC6.');

  @override
  Future<List<Offer>> getOffers(String wantId, OfferSort sort) =>
      throw UnimplementedError('getOffers folgt mit UC7.');

  @override
  Future<void> markOffersSeen(String wantId) =>
      throw UnimplementedError('markOffersSeen folgt mit UC7.');

  @override
  Future<ChatThread> acceptOffer(String offerId) =>
      throw UnimplementedError('acceptOffer folgt mit UC7.');

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

// -----------------------------------------------------------------------
// Fehler übersetzen
// -----------------------------------------------------------------------

/// Zeile aus get_feed mit eingebetteter Region und Name des Käufers.
FeedItem feedItemFromRow(Map<String, dynamic> row) {
  final owner = row['owner'] as Map<String, dynamic>?;
  return FeedItem(
    want: wantFromRow(row),
    buyerName: (owner?['display_name'] as String?) ?? 'Unbekannt',
    region: placeFromRow(row['region'] as Map<String, dynamic>),
  );
}

/// Muster für ilike «enthält». % und _ sind in ilike Platzhalter, aus der
/// Eingabe gelten sie als normale Zeichen: «100%» → «%100\%%».
String containsPattern(String text) =>
    '%${text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';

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

  if (e is PostgrestException) {
    switch (e.code) {
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
