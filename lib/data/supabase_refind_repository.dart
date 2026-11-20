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
  SupabaseRefindRepository(
    this._client, {
    this.photoBucket,
    this.chatPhotoBucket,
    this.authRedirectUrl,
  });

  final SupabaseClient _client;

  /// Name des Buckets in Supabase Storage für die Fotos der Angebote.
  /// Solange er leer ist (Dateiablage noch nicht eingerichtet), speichert
  /// [createOffer] das Angebot ohne Fotos. Siehe ABWEICHUNGEN.md.
  final String? photoBucket;

  /// Name des Buckets für Fotos im Chat (13_speicher.sql). Ohne Bucket
  /// lehnt [sendPhoto] ab.
  final String? chatPhotoBucket;

  /// Signierte Links der Chatfotos (Pfad → Link), damit die Echtzeit nicht
  /// bei jeder neuen Nachricht alle Fotos neu signieren muss. Die Links
  /// gelten eine Stunde.
  final Map<String, String> _chatPhotoUrls = {};

  /// Adresse, auf die der Bestätigungslink in der Mail führt (Deep Link,
  /// z.B. ch.refind.app://login-callback). Muss in Supabase unter
  /// Authentication → URL Configuration als Redirect URL stehen. Ohne
  /// Wert nimmt Supabase die Site URL.
  final String? authRedirectUrl;

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
        // Der Link in der Mail öffnet die App (Deep Link) statt localhost
        emailRedirectTo: authRedirectUrl,
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
          emailRedirectTo: authRedirectUrl,
        );
      } on AuthRetryableFetchException {
        rethrow;
      } on AuthException catch (e) {
        if (_isRateLimit(e)) rethrow;
      }
    });
  }

  /// UC1 Schritt 5: supabase_flutter verarbeitet den Deep Link selbst
  /// (getSessionFromUrl) und meldet das Ergebnis über onAuthStateChange:
  /// signedIn bei Erfolg, ein Fehler bei ungültigem oder abgelaufenem Link.
  /// signedIn kommt auch nach signIn in der App, der SessionProvider ist
  /// dann schon angemeldet und ignoriert es.
  @override
  Stream<bool> get confirmationLinkResults => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.signedIn)
      .map((_) => true)
      .transform(StreamTransformer<bool, bool>.fromHandlers(
        handleError: (error, stack, sink) {
          if (kDebugMode) debugPrint('Bestätigungslink: $error');
          sink.add(false);
        },
      ));

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

  /// UC2, TC06, N-05: Konto mit allen Daten löschen (15_konto_loeschen.sql).
  ///
  /// 1. Pfade der eigenen Fotos holen (account_photo_paths).
  /// 2. Diese Dateien über die Storage-API löschen. Die Regeln erlauben nur
  ///    den eigenen Ordner, fremde Fotos bleiben (ABWEICHUNGEN 13.4).
  /// 3. delete_own_account löscht alle Zeilen und das Anmeldekonto.
  /// 4. Lokal abmelden: Das Konto gibt es nicht mehr, ein Abmelden beim
  ///    Server würde scheitern.
  /// Scheitert Schritt 2 oder 3, bleibt das Konto bestehen und die Person
  /// kann es nochmals versuchen.
  @override
  Future<void> deleteAccount() {
    return _guard(() async {
      _me;
      final rows = await _client.rpc('account_photo_paths') as List;
      final paths = <String, List<String>>{};
      for (final r in rows.cast<Map<String, dynamic>>()) {
        paths.putIfAbsent(r['bucket'] as String, () => []).add(r['path'] as String);
      }
      for (final MapEntry(key: bucket, value: list) in paths.entries) {
        // In Portionen, damit eine Anfrage nicht zu gross wird
        for (var i = 0; i < list.length; i += 100) {
          await _client.storage
              .from(bucket)
              .remove(list.sublist(i, i + 100 > list.length ? list.length : i + 100));
        }
      }
      await _client.rpc('delete_own_account');
      _chatPhotoUrls.clear();
      await _client.auth.signOut(scope: SignOutScope.local);
    });
  }

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
          hasAcceptedOffer: offers.any((o) => o['status'] == 'angenommen'),
        );
      }).toList();
    });
  }

  @override
  Future<Want> updateWant(String wantId, WantDraft draft) =>
      throw UnimplementedError('updateWant folgt mit UC4.');

  /// UC4 Schritt 3: Pausieren oder Aktivieren über die Datenbank-Funktion
  /// set_want_status (supabase/11_gesuch_status.sql). Direkt darf die App
  /// den Status nicht mehr ändern.
  @override
  Future<void> setWantStatus(String wantId, WantStatus status) async {
    if (status != WantStatus.aktiv && status != WantStatus.pausiert) {
      throw const RepositoryException(
          RepositoryErrorKind.ungueltigeEingabe, wantStatusConflictMessage);
    }
    await _guard(() => _wantStatusCall(() => _client.rpc('set_want_status',
        params: {'p_want_id': wantId, 'p_status': status.name})));
  }

  /// UC4 Schritt 6: «Nochmal aufhängen» über republish_want. Setzt
  /// created_at und expires_at neu (14 Tage) und den Status aktiv.
  @override
  Future<Want> republishWant(String wantId) {
    return _guard(() async {
      final row = await _wantStatusCall(() =>
          _client.rpc('republish_want', params: {'p_want_id': wantId}));
      return wantFromRow(row as Map<String, dynamic>);
    });
  }

  /// Fehler der Status-Funktionen mit eigener Meldung. Ohne diese Hilfe
  /// würde mapSupabaseError P0001 als «Angebot annehmen» melden.
  Future<dynamic> _wantStatusCall(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (e.code == 'P0001') {
        throw const RepositoryException(
            RepositoryErrorKind.konflikt, wantStatusConflictMessage);
      }
      if (e.code == 'P0002') {
        throw const RepositoryException(
            RepositoryErrorKind.ungueltigeEingabe, 'Gesuch nicht gefunden.');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Entdecken (UC5)
  // ---------------------------------------------------------------------

  /// Welche Gesuche sichtbar sind, entscheidet die Funktion get_feed in der
  /// Datenbank (supabase/10_feed.sql). Nur sie darf prüfen, ob es zu einem
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
  // Angebote (UC6, UC7)
  // ---------------------------------------------------------------------

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
    checkOfferPhotoSizes(fileSizes(photos));
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

  /// Lädt die Fotos in den privaten Bucket und trägt sie in `photo` ein.
  /// Ohne [photoBucket] passiert nichts (Angebot ohne Fotos).
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
        // Pfad <uid>/<offer_id>/<n>.<typ>: Die Storage-Regel
        // offer_photos_insert (13_speicher.sql) erlaubt nur den eigenen Ordner.
        final (ext, mime) = photoFileType(photos[i].path);
        final path = '$_me/$offerId/${i + 1}.$ext';
        await _client.storage.from(bucket).upload(
              path,
              photos[i],
              fileOptions: FileOptions(contentType: mime),
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
        // Bei gleichem Preis das neuere zuerst, wie im Mock
        OfferSort.guenstigste => await base
            .order('price', ascending: true)
            .order('created_at', ascending: false),
        OfferSort.teuerste => await base
            .order('price', ascending: false)
            .order('created_at', ascending: false),
      };
      final offers = rows.map(offerFromRow).toList();
      return _withPhotoUrls(offers);
    });
  }

  /// Ersetzt die Pfade der Fotos durch Links, die eine Stunde gültig sind.
  /// Der Bucket ist privat: Einen Link gibt es nur für Fotos, die die Regel
  /// offer_photos_select (13_speicher.sql) zum Lesen freigibt. Fehlt ein
  /// Foto oder klappt es nicht, bleibt der Pfad (die App zeigt ein Symbol).
  Future<List<Offer>> _withPhotoUrls(List<Offer> offers) async {
    final bucket = photoBucket;
    final paths = [for (final o in offers) ...o.photos.map((p) => p.url)];
    if (bucket == null || paths.isEmpty) return offers;
    try {
      final results =
          await _client.storage.from(bucket).createSignedUrlsResult(paths, 3600);
      final urlByPath = signedUrlsByPath(results);
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

  // ---------------------------------------------------------------------
  // Chat (UC8)
  // ---------------------------------------------------------------------

  /// UC8 Schritt 1: eigene Chats, zuletzt aktive zuerst. Ein Aufruf mit
  /// Gesuchstitel, Angebotspreis, beiden Namen und nur der letzten
  /// Nachricht. Die RLS-Regel chat_thread_select liefert nur Chats, in
  /// denen man Käufer oder Verkäufer ist.
  @override
  Future<List<ChatSummary>> getChats() {
    return _guard(() async {
      final me = _me;
      final rows = await _client
          .from('chat_thread')
          .select('*, want(title), offer(price), '
              'buyer:profile!chat_thread_buyer_id_fkey(display_name), '
              'seller:profile!chat_thread_seller_id_fkey(display_name), '
              'message(*)')
          .order('last_activity', ascending: false)
          .order('created_at', referencedTable: 'message', ascending: false)
          .limit(1, referencedTable: 'message');
      return rows.map((row) => chatSummaryFromRow(row, me)).toList();
    });
  }

  /// UC8 Schritt 3: Nachrichten in Echtzeit (Konzept S4). Der Stream lädt
  /// zuerst alle Nachrichten und liefert danach bei jeder neuen Nachricht
  /// die ganze Liste neu, älteste zuerst. Supabase Realtime wendet dabei die
  /// RLS-Regel message_select an: ein fremder Chat liefert nichts (TC27).
  /// Voraussetzung: message ist in der Publication (14_chat.sql).
  @override
  Stream<List<Message>> watchMessages(String threadId) {
    if (_client.auth.currentUser == null) {
      return Stream.error(const RepositoryException(
          RepositoryErrorKind.nichtBerechtigt, 'Bitte zuerst anmelden.'));
    }
    return _client
        .from('message')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at', ascending: true)
        .asyncMap((rows) => _withChatPhotoUrls(rows.map(messageFromRow).toList()))
        .handleError((Object e, StackTrace stack) =>
            Error.throwWithStackTrace(mapSupabaseError(e), stack));
  }

  /// Ersetzt bei Fotonachrichten den Pfad durch einen Link (eine Stunde
  /// gültig). Nur Mitglieder des Chats bekommen einen Link (Storage-Regel
  /// chat_photos_select). Klappt es nicht, bleibt der Pfad (Symbol).
  Future<List<Message>> _withChatPhotoUrls(List<Message> messages) async {
    final bucket = chatPhotoBucket;
    if (bucket == null) return messages;
    final missing = {
      for (final m in messages)
        if (m.kind == MessageKind.foto && !_chatPhotoUrls.containsKey(m.body)) m.body,
    }.toList();
    if (missing.isNotEmpty) {
      try {
        final results =
            await _client.storage.from(bucket).createSignedUrlsResult(missing, 3600);
        _chatPhotoUrls.addAll(signedUrlsByPath(results));
      } on StorageException catch (e) {
        if (kDebugMode) debugPrint('Chatfotos ohne Link: $e');
      }
    }
    return [
      for (final m in messages)
        m.kind == MessageKind.foto && _chatPhotoUrls.containsKey(m.body)
            ? Message(
                id: m.id,
                threadId: m.threadId,
                senderId: m.senderId,
                kind: m.kind,
                body: _chatPhotoUrls[m.body]!,
                createdAt: m.createdAt,
                readAt: m.readAt,
              )
            : m,
    ];
  }

  /// UC8 Schritt 3: Textnachricht speichern. RLS message_insert prüft
  /// Absender und Mitgliedschaft, die CHECK-Regel die Länge (14_chat.sql).
  @override
  Future<Message> sendText(String threadId, String text) async {
    checkMessageText(text);
    return _guard(() async {
      final row = await _client
          .from('message')
          .insert({
            'thread_id': threadId,
            'sender_id': _me,
            'kind': 'text',
            'body': text.trim(),
          })
          .select()
          .single();
      return messageFromRow(row);
    });
  }

  /// UC8 Schritt 3: Foto senden. Zuerst in den privaten Bucket chat-photos
  /// unter `<thread_id>/<uid>/<zeit>.<typ>` (Storage-Regel chat_photos_insert:
  /// nur Mitglieder, nur der eigene Ordner), dann eine Nachricht vom Typ
  /// «foto» mit diesem Pfad (CHECK message_body_check prüft den Ordner).
  @override
  Future<Message> sendPhoto(String threadId, File photo) async {
    checkOfferPhotoSizes(fileSizes([photo]));
    final bucket = chatPhotoBucket;
    if (bucket == null) {
      throw const RepositoryException(
          RepositoryErrorKind.konflikt, 'Fotos im Chat sind noch nicht eingerichtet.');
    }
    return _guard(() async {
      final me = _me;
      final (ext, mime) = photoFileType(photo.path);
      final path = '$threadId/$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage
          .from(bucket)
          .upload(path, photo, fileOptions: FileOptions(contentType: mime));
      final row = await _client
          .from('message')
          .insert({'thread_id': threadId, 'sender_id': me, 'kind': 'foto', 'body': path})
          .select()
          .single();
      return (await _withChatPhotoUrls([messageFromRow(row)])).single;
    });
  }

  @override
  Future<void> markRead(String threadId) =>
      throw UnimplementedError('markRead folgt mit UC8.');

  @override
  Future<void> setHandover(String threadId, DateTime at, String place) =>
      throw UnimplementedError('setHandover folgt mit UC8.');

  /// UC8 Schritt 7: Deal abschliessen über die Datenbank-Funktion
  /// close_deal (supabase/14_chat.sql). Sie prüft Käufer, offenen Chat,
  /// Preis und aktives Gesuch und setzt das Gesuch auf «erledigt».
  @override
  Future<void> closeDeal(String threadId, int agreedPriceRappen) async {
    checkDealPrice(agreedPriceRappen);
    await _guard(() async {
      try {
        await _client.rpc('close_deal',
            params: {'p_thread_id': threadId, 'p_agreed_price': agreedPriceRappen});
      } on PostgrestException catch (e) {
        // Eigene Meldungen statt der zu «Angebot annehmen» (gleiche Codes)
        if (e.code == 'P0001') {
          throw const RepositoryException(
              RepositoryErrorKind.konflikt, dealConflictMessage);
        }
        if (e.code == 'P0002') {
          throw const RepositoryException(
              RepositoryErrorKind.ungueltigeEingabe, 'Chat nicht gefunden.');
        }
        if (e.code == '42501') {
          throw const RepositoryException(
              RepositoryErrorKind.nichtBerechtigt, 'Nur der Käufer kann abschliessen.');
        }
        rethrow;
      }
    });
  }

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

/// Status wie in der Datenbank. Ob ein Gesuch schon abgelaufen ist, bevor
/// der stündliche Auftrag (supabase/12_ablauf.sql) lief, entscheidet die
/// StatusLogic in der Anwendungsschicht, weil sie auch angenommene Angebote
/// berücksichtigt.
Want wantFromRow(Map<String, dynamic> row) {
  final expiresAt = DateTime.parse(row['expires_at'] as String).toLocal();
  final status = WantStatus.values.byName(row['status'] as String);
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

/// Muster für ilike «enthält». % und _ sind in ilike Platzhalter, aus der
/// Eingabe gelten sie als normale Zeichen: «100%» → «%100\%%».
String containsPattern(String text) =>
    '%${text.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';

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
      // Grösse und Dateityp prüft der Bucket (13_speicher.sql)
      case '413':
        return ex(RepositoryErrorKind.ungueltigeEingabe, photoTooLargeMessage);
      case '415':
        return ex(RepositoryErrorKind.ungueltigeEingabe,
            'Nur Fotos im Format JPEG, PNG oder WebP.');
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

/// Dateiendung und Medientyp für ein Foto, nach der Endung der Datei.
/// Der Bucket erlaubt nur JPEG, PNG und WebP (13_speicher.sql). Alles
/// andere geht als JPEG, das image_picker beim Verkleinern liefert.
(String, String) photoFileType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return ('png', 'image/png');
  if (lower.endsWith('.webp')) return ('webp', 'image/webp');
  return ('jpg', 'image/jpeg');
}

/// Pfad → Link für alle Fotos, für die Supabase einen Link erzeugt hat.
/// Fehlgeschlagene (z.B. Datei fehlt oder keine Leseberechtigung) fehlen
/// in der Map, die App zeigt dort ein Symbol statt des Fotos.
Map<String, String> signedUrlsByPath(List<SignedUrlResult> results) => {
      for (final r in results)
        if (r is SignedUrlSuccess) r.path: r.signedUrl,
    };

/// Zeile aus message.
Message messageFromRow(Map<String, dynamic> row) => Message(
      id: row['id'] as String,
      threadId: row['thread_id'] as String,
      senderId: row['sender_id'] as String,
      kind: MessageKind.values.byName(row['kind'] as String),
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      readAt: row['read_at'] == null
          ? null
          : DateTime.parse(row['read_at'] as String).toLocal(),
    );

/// Zeile aus chat_thread mit Gesuch, Angebot, beiden Namen und der letzten
/// Nachricht (getChats). [me] bestimmt, wer das Gegenüber ist.
ChatSummary chatSummaryFromRow(Map<String, dynamic> row, String me) {
  final thread = chatThreadFromRow(row);
  final buyer = row['buyer'] as Map<String, dynamic>?;
  final seller = row['seller'] as Map<String, dynamic>?;
  final other = thread.buyerId == me ? seller : buyer;
  final messages = (row['message'] as List? ?? const []).cast<Map<String, dynamic>>();
  return ChatSummary(
    thread: thread,
    otherUserName: (other?['display_name'] as String?) ?? 'Unbekannt',
    wantTitle: ((row['want'] as Map<String, dynamic>?)?['title'] as String?) ?? '',
    unreadCount: 0, // braucht «gelesen» (F-14), noch offen
    lastMessage: messages.isEmpty ? null : messageFromRow(messages.first),
    offerPriceRappen: (row['offer'] as Map<String, dynamic>?)?['price'] as int?,
  );
}
