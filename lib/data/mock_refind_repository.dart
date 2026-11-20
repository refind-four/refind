import 'dart:async';
import 'dart:io';

import '../model/model.dart';
import 'input_checks.dart';
import 'refind_repository.dart';
import 'repository_exception.dart';

/// Attrappe für Vorschau und Tests (Konzept 4.2.3).
/// Hält Beispieldaten im Speicher und braucht kein Netz. Nach einem
/// Neustart der App sind alle Änderungen wieder weg.
///
/// Testkonten (Passwort jeweils `refind123`), wie in supabase/05_testdaten.sql:
/// * anna@refind.test – Anna, Bern, Käuferin mit 9 Gesuchen
/// * ben@refind.test  – Ben, Zürich, Verkäufer, keine eigenen Gesuche
/// * cara@refind.test – Cara, ohne Wohnort, Verkäuferin und Käuferin (Makita)
class MockRefindRepository implements RefindRepository {
  MockRefindRepository({this.delay = const Duration(milliseconds: 400)}) {
    _seed();
  }

  /// Künstliche Wartezeit, damit sich die App wie mit Netz anfühlt.
  final Duration delay;

  final Map<String, User> _users = {};
  final Map<String, _Credentials> _credentials = {};
  final Map<String, String> _pushTokens = {};
  final List<Place> _places = [];
  final List<Want> _wants = [];
  final List<Offer> _offers = [];
  final List<ChatThread> _threads = [];
  final List<Message> _messages = [];
  final List<Rating> _ratings = [];
  final _messageChanges = StreamController<String>.broadcast();

  String? _currentUserId;
  int _idCounter = 100;

  // ---------------------------------------------------------------------
  // Hilfsmethoden
  // ---------------------------------------------------------------------

  Future<void> _wait() => Future.delayed(delay);

  String _newId(String prefix) => '$prefix-${_idCounter++}';

  String get _me {
    final id = _currentUserId;
    if (id == null) {
      throw const RepositoryException(
        RepositoryErrorKind.nichtBerechtigt,
        'Bitte zuerst anmelden.',
      );
    }
    return id;
  }

  Never _invalid(String message) =>
      throw RepositoryException(RepositoryErrorKind.ungueltigeEingabe, message);

  Never _forbidden(String message) =>
      throw RepositoryException(RepositoryErrorKind.nichtBerechtigt, message);

  Never _conflict(String message) =>
      throw RepositoryException(RepositoryErrorKind.konflikt, message);

  Place _place(int id) => _places.firstWhere(
        (p) => p.id == id,
        orElse: () => _invalid('Ortschaft nicht gefunden.'),
      );

  Want _want(String id) => _wants.firstWhere(
        (w) => w.id == id,
        orElse: () => _invalid('Gesuch nicht gefunden.'),
      );

  Want _myWant(String id) {
    final want = _want(id);
    if (want.ownerId != _me) _forbidden('Das ist nicht dein Gesuch.');
    return want;
  }

  ChatThread _myThread(String id) {
    final thread = _threads.firstWhere(
      (t) => t.id == id,
      orElse: () => _invalid('Chat nicht gefunden.'),
    );
    if (thread.buyerId != _me && thread.sellerId != _me) {
      _forbidden('Das ist nicht dein Chat.');
    }
    return thread;
  }

  void _replaceWant(Want want) =>
      _wants[_wants.indexWhere((w) => w.id == want.id)] = want;

  void _replaceThread(ChatThread thread) =>
      _threads[_threads.indexWhere((t) => t.id == thread.id)] = thread;

  bool _hasAcceptedOffer(String wantId) => _offers
      .any((o) => o.wantId == wantId && o.status == OfferStatus.angenommen);

  List<Message> _messagesOf(String threadId) =>
      _messages.where((m) => m.threadId == threadId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Prüfung «auf dem Server» (Factsheet Inputvalidierung), gemeinsam mit
  /// SupabaseRefindRepository in input_checks.dart.
  void _validateDraft(WantDraft d) {
    checkWantDraft(d);
    _place(d.regionId);
  }

  // ---------------------------------------------------------------------
  // Konto (UC1, UC2)
  // ---------------------------------------------------------------------

  @override
  Future<void> signUp(String displayName, String email, String password) async {
    await _wait();
    final name = displayName.trim();
    final mail = email.trim().toLowerCase();
    // Dieselben Regeln wie in der Maske. Das Repository prüft noch einmal,
    // weil man Prüfungen in der App umgehen kann.
    checkSignUp(name, mail, password);
    if (_credentials.containsKey(mail)) {
      // UC1: nichts über das bestehende Konto verraten.
      _conflict('Die Registrierung ist mit diesen Angaben nicht möglich.');
    }
    final id = _newId('user');
    _users[id] = User(
      id: id,
      displayName: name,
      cityId: null,
      radiusKm: 20,
      memberSince: DateTime.now(),
    );
    // Neues Konto ist noch nicht bestätigt, wie bei Supabase nach signUp.
    _credentials[mail] = _Credentials(password, id, confirmed: false);
  }

  /// Nach so vielen Fehlversuchen wird die Mailadresse kurz gesperrt (TC02).
  static const maxFailedAttempts = 5;
  static const lockDuration = Duration(minutes: 1);
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockedUntil = {};

  @override
  Future<User> signIn(String email, String password) async {
    await _wait();
    final mail = email.trim().toLowerCase();

    final locked = _lockedUntil[mail];
    if (locked != null && DateTime.now().isBefore(locked)) {
      _forbidden('Zu viele Fehlversuche. Bitte versuche es in einer Minute wieder.');
    }

    final cred = _credentials[mail];
    if (cred == null || cred.password != password) {
      final count = (_failedAttempts[mail] ?? 0) + 1;
      _failedAttempts[mail] = count;
      if (count >= maxFailedAttempts) {
        _failedAttempts.remove(mail);
        _lockedUntil[mail] = DateTime.now().add(lockDuration);
      }
      _forbidden('Mailadresse oder Passwort ist falsch.');
    }
    _failedAttempts.remove(mail);

    if (!cred.confirmed) {
      throw const RepositoryException(
        RepositoryErrorKind.mailNichtBestaetigt,
        'Bitte bestätige zuerst deine Mailadresse über den Link in der Mail.',
      );
    }
    _currentUserId = cred.userId;
    return _users[cred.userId]!;
  }

  /// Die Attrappe verschickt keine Mail. Sie tut so, als hätte die Person
  /// den Link in der Mail sofort geöffnet, und bestätigt das Konto.
  @override
  Future<void> resendConfirmation(String email) async {
    await _wait();
    _credentials[email.trim().toLowerCase()]?.confirmed = true;
  }

  @override
  Future<void> registerPushToken(String token) async {
    await _wait();
    _pushTokens[_me] = token;
  }

  @override
  Future<void> signOut() async {
    await _wait();
    final id = _currentUserId;
    if (id != null) _pushTokens.remove(id);
    _currentUserId = null;
  }

  @override
  Future<User> getMyProfile() async {
    await _wait();
    return _users[_me]!;
  }

  @override
  Future<User> updateProfile(
    String displayName,
    int cityId,
    int radiusKm,
    File? avatar,
  ) async {
    await _wait();
    if (displayName.trim().isEmpty) _invalid('Bitte einen Anzeigenamen eingeben.');
    if (radiusKm <= 0) _invalid('Der Umkreis muss grösser als 0 sein.');
    _place(cityId);
    final updated = _users[_me]!.copyWith(
      displayName: displayName.trim(),
      cityId: cityId,
      radiusKm: radiusKm,
      avatarUrl: avatar?.path,
    );
    _users[_me] = updated;
    return updated;
  }

  @override
  Future<void> deleteAccount() async {
    await _wait();
    final id = _me;
    final myWantIds = _wants.where((w) => w.ownerId == id).map((w) => w.id).toSet();
    _wants.removeWhere((w) => w.ownerId == id);
    _offers.removeWhere((o) => o.sellerId == id || myWantIds.contains(o.wantId));
    _users.remove(id);
    _credentials.removeWhere((_, c) => c.userId == id);
    _pushTokens.remove(id);
    _currentUserId = null;
  }

  @override
  Future<List<Place>> searchPlaces(String query) async {
    await _wait();
    final q = query.trim().toLowerCase();
    return _places
        .where((p) => p.name.toLowerCase().contains(q) || '${p.plz}'.startsWith(q))
        .toList();
  }

  @override
  Future<Place> getPlace(int placeId) async {
    await _wait();
    _me;
    return _place(placeId);
  }

  // ---------------------------------------------------------------------
  // Gesuche (UC3, UC4)
  // ---------------------------------------------------------------------

  @override
  Future<Want> createWant(WantDraft draft) async {
    await _wait();
    _validateDraft(draft);
    final now = DateTime.now();
    final want = Want(
      id: _newId('want'),
      ownerId: _me,
      title: draft.title.trim(),
      category: draft.category,
      description: draft.description.trim(),
      budgetMaxRappen: draft.budgetMaxRappen,
      condition: draft.condition,
      regionId: draft.regionId,
      radiusKm: draft.radiusKm,
      createdAt: now,
      expiresAt: now.add(Duration(days: draft.durationDays)),
      status: WantStatus.aktiv,
    );
    _wants.add(want);
    return want;
  }

  @override
  Future<List<WantSummary>> getMyWants() async {
    await _wait();
    final mine = _wants.where((w) => w.ownerId == _me).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final w in mine)
        WantSummary(
          want: w,
          offerCount: _offers.where((o) => o.wantId == w.id).length,
          newOfferCount: _offers
              .where((o) => o.wantId == w.id && o.status == OfferStatus.neu)
              .length,
          region: _place(w.regionId),
          hasAcceptedOffer: _hasAcceptedOffer(w.id),
        ),
    ];
  }

  @override
  Future<Want> updateWant(String wantId, WantDraft draft) async {
    await _wait();
    final want = _myWant(wantId);
    if (want.status == WantStatus.erledigt) {
      _conflict('Ein erledigtes Gesuch lässt sich nicht mehr ändern.');
    }
    _validateDraft(draft);
    final updated = want.copyWith(
      title: draft.title.trim(),
      category: draft.category,
      description: draft.description.trim(),
      budgetMaxRappen: draft.budgetMaxRappen,
      condition: draft.condition,
      regionId: draft.regionId,
      radiusKm: draft.radiusKm,
    );
    _replaceWant(updated);
    return updated;
  }

  @override
  /// Wie set_want_status in supabase/11_gesuch_status.sql: nur aktiv ⇄
  /// pausiert, nicht abgelaufen, ohne angenommenes Angebot.
  @override
  Future<void> setWantStatus(String wantId, WantStatus status) async {
    await _wait();
    final want = _myWant(wantId);
    final allowed = (want.status == WantStatus.aktiv && status == WantStatus.pausiert) ||
        (want.status == WantStatus.pausiert && status == WantStatus.aktiv);
    if (!allowed ||
        !want.expiresAt.isAfter(DateTime.now()) ||
        _hasAcceptedOffer(want.id)) {
      _conflict(wantStatusConflictMessage);
    }
    _replaceWant(want.copyWith(status: status));
  }

  /// Wie republish_want in supabase/11_gesuch_status.sql: nur abgelaufene
  /// Gesuche (Status oder Datum), ohne angenommenes Angebot. Gilt als neu
  /// aufgehängt: erfasst jetzt, sichtbar 14 Tage (UC4 Schritt 6).
  @override
  Future<Want> republishWant(String wantId) async {
    await _wait();
    final want = _myWant(wantId);
    final now = DateTime.now();
    final expired = want.status == WantStatus.abgelaufen ||
        ((want.status == WantStatus.aktiv || want.status == WantStatus.pausiert) &&
            !want.expiresAt.isAfter(now));
    if (!expired || _hasAcceptedOffer(want.id)) {
      _conflict(wantStatusConflictMessage);
    }
    final updated = Want(
      id: want.id,
      ownerId: want.ownerId,
      title: want.title,
      category: want.category,
      description: want.description,
      budgetMaxRappen: want.budgetMaxRappen,
      condition: want.condition,
      regionId: want.regionId,
      radiusKm: want.radiusKm,
      createdAt: now,
      expiresAt: now.add(const Duration(days: WantLimits.defaultDurationDays)),
      status: WantStatus.aktiv,
    );
    _replaceWant(updated);
    return updated;
  }

  // ---------------------------------------------------------------------
  // Entdecken und Angebote (UC5 bis UC7)
  // ---------------------------------------------------------------------

  @override
  Future<List<FeedItem>> getFeed(FeedFilter filter) async {
    await _wait();
    checkFeedFilter(filter);
    final me = _me;
    final now = DateTime.now();
    final origin = filter.placeId == null ? null : _place(filter.placeId!);
    final query = filter.query?.trim().toLowerCase() ?? '';

    final items = <FeedItem>[];
    for (final w in _wants) {
      // Wie die Funktion get_feed in supabase/10_feed.sql: nur aktive,
      // nicht abgelaufene Gesuche anderer Konten ohne angenommenes Angebot.
      if (w.ownerId == me || w.status != WantStatus.aktiv) continue;
      if (!w.expiresAt.isAfter(now) || _hasAcceptedOffer(w.id)) continue;
      if (filter.category != null && w.category != filter.category) continue;
      // F-07: nur im Titel suchen (Konzept UC5 Schritt 5, TC13).
      if (query.isNotEmpty && !w.title.toLowerCase().contains(query)) continue;
      final region = _place(w.regionId);
      final distance = origin?.distanceKmTo(region);
      if (distance != null && filter.radiusKm != null && distance > filter.radiusKm!) {
        continue;
      }
      items.add(FeedItem(
        want: w,
        buyerName: _users[w.ownerId]?.displayName ?? 'Unbekannt',
        region: region,
        distanceKm: distance,
      ));
    }
    items.sort((a, b) => b.want.createdAt.compareTo(a.want.createdAt));
    return items.take(maxFeedItems).toList();
  }

  @override
  Future<Offer> createOffer(
    String wantId,
    int priceRappen,
    String message,
    List<File> photos,
  ) async {
    await _wait();
    // Gemeinsame Prüfung mit SupabaseRefindRepository (input_checks.dart).
    checkOffer(priceRappen, message, photos.length);
    checkOfferPhotoSizes(fileSizes(photos));
    final want = _want(wantId);
    if (want.ownerId == _me) _forbidden('Auf eigene Gesuche kannst du nicht anbieten.');
    if (want.status != WantStatus.aktiv ||
        want.expiresAt.isBefore(DateTime.now()) ||
        _hasAcceptedOffer(wantId)) {
      _conflict('Dieses Gesuch nimmt keine Angebote mehr an.');
    }
    final offerId = _newId('offer');
    final offer = Offer(
      id: offerId,
      wantId: wantId,
      sellerId: _me,
      priceRappen: priceRappen,
      message: message.trim(),
      createdAt: DateTime.now(),
      status: OfferStatus.neu,
      sellerName: _users[_me]?.displayName,
      photos: [
        for (final f in photos)
          Photo(id: _newId('photo'), offerId: offerId, url: f.path),
      ],
    );
    _offers.add(offer);
    return offer;
  }

  @override
  Future<List<Offer>> getOffers(String wantId, OfferSort sort) async {
    await _wait();
    _myWant(wantId);
    final list = [
      for (final o in _offers.where((o) => o.wantId == wantId))
        Offer(
          id: o.id,
          wantId: o.wantId,
          sellerId: o.sellerId,
          priceRappen: o.priceRappen,
          message: o.message,
          createdAt: o.createdAt,
          status: o.status,
          photos: o.photos,
          sellerName: _users[o.sellerId]?.displayName,
        ),
    ];
    switch (sort) {
      case OfferSort.neueste:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case OfferSort.guenstigste:
        // Bei gleichem Preis das neuere zuerst, wie bei Supabase.
        list.sort((a, b) {
          final byPrice = a.priceRappen.compareTo(b.priceRappen);
          return byPrice != 0 ? byPrice : b.createdAt.compareTo(a.createdAt);
        });
      case OfferSort.teuerste:
        list.sort((a, b) {
          final byPrice = b.priceRappen.compareTo(a.priceRappen);
          return byPrice != 0 ? byPrice : b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  @override
  Future<void> markOffersSeen(String wantId) async {
    await _wait();
    _myWant(wantId);
    for (var i = 0; i < _offers.length; i++) {
      final o = _offers[i];
      if (o.wantId == wantId && o.status == OfferStatus.neu) {
        _offers[i] = o.copyWith(status: OfferStatus.gesehen);
      }
    }
  }

  @override
  Future<ChatThread> acceptOffer(String offerId) async {
    await _wait();
    final offer = _offers.firstWhere(
      (o) => o.id == offerId,
      orElse: () => _invalid('Angebot nicht gefunden.'),
    );
    final want = _myWant(offer.wantId);
    // Gleiche Bedingungen wie accept_offer (supabase/08_angebot_annehmen.sql)
    if (want.status != WantStatus.aktiv ||
        want.expiresAt.isBefore(DateTime.now()) ||
        _hasAcceptedOffer(want.id) ||
        (offer.status != OfferStatus.neu && offer.status != OfferStatus.gesehen)) {
      _conflict(acceptConflictMessage);
    }
    // Wie die Funktion accept_offer: annehmen, übrige absagen, Chat anlegen.
    for (var i = 0; i < _offers.length; i++) {
      final o = _offers[i];
      if (o.wantId != want.id) continue;
      if (o.id == offerId) {
        _offers[i] = o.copyWith(status: OfferStatus.angenommen);
      } else if (o.status == OfferStatus.neu || o.status == OfferStatus.gesehen) {
        _offers[i] = o.copyWith(status: OfferStatus.abgesagt);
      }
    }
    final thread = ChatThread(
      id: _newId('thread'),
      offerId: offerId,
      wantId: want.id,
      buyerId: want.ownerId,
      sellerId: offer.sellerId,
      lastActivity: DateTime.now(),
    );
    _threads.add(thread);
    return thread;
  }

  // ---------------------------------------------------------------------
  // Chat, Abschluss, Bewertung (UC8, UC9)
  // ---------------------------------------------------------------------

  @override
  Future<List<ChatSummary>> getChats() async {
    await _wait();
    final me = _me;
    final mine = _threads.where((t) => t.buyerId == me || t.sellerId == me).toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return [
      for (final t in mine)
        ChatSummary(
          thread: t,
          otherUserName: _users[t.otherUserId(me)]?.displayName ?? 'Unbekannt',
          wantTitle: _want(t.wantId).title,
          unreadCount: _messagesOf(t.id)
              .where((m) => m.senderId != me && m.readAt == null)
              .length,
          lastMessage: _messagesOf(t.id).lastOrNull,
          offerPriceRappen:
              _offers.where((o) => o.id == t.offerId).firstOrNull?.priceRappen,
        ),
    ];
  }

  @override
  Stream<List<Message>> watchMessages(String threadId) async* {
    _myThread(threadId);
    yield _messagesOf(threadId);
    yield* _messageChanges.stream
        .where((id) => id == threadId)
        .map((_) => _messagesOf(threadId));
  }

  Message _addMessage(String threadId, MessageKind kind, String body) {
    final thread = _myThread(threadId);
    final now = DateTime.now();
    final message = Message(
      id: _newId('msg'),
      threadId: threadId,
      senderId: _me,
      kind: kind,
      body: body,
      createdAt: now,
    );
    _messages.add(message);
    _replaceThread(thread.copyWith(lastActivity: now));
    _messageChanges.add(threadId);
    return message;
  }

  @override
  Future<Message> sendText(String threadId, String text) async {
    await _wait();
    checkMessageText(text); // gemeinsam mit Supabase (input_checks.dart)
    return _addMessage(threadId, MessageKind.text, text.trim());
  }

  @override
  Future<Message> sendPhoto(String threadId, File photo) async {
    await _wait();
    // Wie Supabase: höchstens 5 MB (input_checks.dart, Bucket chat-photos)
    checkOfferPhotoSizes(fileSizes([photo]));
    return _addMessage(threadId, MessageKind.foto, photo.path);
  }

  @override
  Future<void> markRead(String threadId) async {
    await _wait();
    _myThread(threadId);
    final now = DateTime.now();
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.threadId == threadId && m.senderId != _me && m.readAt == null) {
        _messages[i] = m.copyWith(readAt: now);
      }
    }
    _messageChanges.add(threadId);
  }

  @override
  Future<void> setHandover(String threadId, DateTime at, String place) async {
    await _wait();
    final thread = _myThread(threadId);
    if (thread.isClosed) _conflict('Das Geschäft ist bereits abgeschlossen.');
    if (place.trim().isEmpty) _invalid('Bitte einen Übergabeort eingeben.');
    _replaceThread(thread.copyWith(
      handoverAt: at,
      handoverPlace: place.trim(),
      lastActivity: DateTime.now(),
    ));
  }

  @override
  Future<void> closeDeal(String threadId, int agreedPriceRappen) async {
    await _wait();
    // Wie close_deal in supabase/14_chat.sql
    checkDealPrice(agreedPriceRappen);
    final thread = _myThread(threadId);
    if (thread.buyerId != _me) _forbidden('Nur der Käufer kann abschliessen.');
    if (thread.isClosed || _want(thread.wantId).status != WantStatus.aktiv) {
      _conflict(dealConflictMessage);
    }
    final now = DateTime.now();
    _replaceThread(thread.copyWith(
      agreedPriceRappen: agreedPriceRappen,
      closedAt: now,
      lastActivity: now,
    ));
    _replaceWant(_want(thread.wantId).copyWith(status: WantStatus.erledigt));
  }

  @override
  Future<void> rateUser(String threadId, int stars) async {
    await _wait();
    final thread = _myThread(threadId);
    if (!thread.isClosed) _conflict('Bewerten geht erst nach dem Abschluss.');
    if (stars < 1 || stars > 5) _invalid('Bitte 1 bis 5 Sterne wählen.');
    if (_ratings.any((r) => r.threadId == threadId && r.fromUserId == _me)) {
      _conflict('Du hast diesen Chat schon bewertet.');
    }
    _ratings.add(Rating(
      id: _newId('rating'),
      fromUserId: _me,
      toUserId: thread.otherUserId(_me),
      threadId: threadId,
      stars: stars,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<ProfileStats> getProfileStats(String userId) async {
    await _wait();
    _me;
    final received = _ratings.where((r) => r.toUserId == userId).toList();
    return ProfileStats(
      averageStars: received.isEmpty
          ? null
          : received.map((r) => r.stars).reduce((a, b) => a + b) / received.length,
      dealCount: _threads
          .where((t) => t.isClosed && (t.buyerId == userId || t.sellerId == userId))
          .length,
      activeWantCount: _wants
          .where((w) => w.ownerId == userId && w.status == WantStatus.aktiv)
          .length,
    );
  }

  // ---------------------------------------------------------------------
  // Testdaten
  // ---------------------------------------------------------------------

  /// Dieselben Testdaten wie `supabase/05_testdaten.sql`, damit Mock und
  /// Supabase dasselbe zeigen und die Testfälle (TC09 bis TC14) mit beiden
  /// gleich ablaufen. Bei Änderungen beide Stellen nachführen.
  void _seed() {
    final now = DateTime.now();

    // 1. Ortschaften (LV95, Stadtzentrum, auf etwa 100 m gerundet)
    _places.addAll(const [
      Place(id: 1, plz: 3000, name: 'Bern', e: 2600670, n: 1199655),
      Place(id: 2, plz: 8001, name: 'Zürich', e: 2683100, n: 1247500),
      Place(id: 3, plz: 8400, name: 'Winterthur', e: 2697000, n: 1261800),
      Place(id: 4, plz: 4001, name: 'Basel', e: 2611300, n: 1267500),
      Place(id: 5, plz: 6003, name: 'Luzern', e: 2666200, n: 1211500),
      Place(id: 6, plz: 9000, name: 'St. Gallen', e: 2746000, n: 1254500),
      Place(id: 7, plz: 1003, name: 'Lausanne', e: 2538000, n: 1152500),
      Place(id: 8, plz: 1201, name: 'Genève', e: 2500200, n: 1118000),
    ]);
    const bern = 1, zuerich = 2, winterthur = 3;

    // 2b. Konten und Profile
    void user(String id, String name, String mail, int? cityId, int radiusKm,
        DateTime memberSince) {
      _users[id] = User(
        id: id,
        displayName: name,
        cityId: cityId,
        radiusKm: radiusKm,
        memberSince: memberSince,
      );
      _credentials[mail] = _Credentials('refind123', id);
    }

    user('user-anna', 'Anna', 'anna@refind.test', bern, 20, DateTime(2026, 9, 1));
    user('user-ben', 'Ben', 'ben@refind.test', zuerich, 30, DateTime(2026, 8, 15));
    user('user-cara', 'Cara', 'cara@refind.test', null, 20, DateTime(2026, 10, 20));

    DateTime ago(Duration d) => now.subtract(d);
    Duration days(int n) => Duration(days: n);
    Duration hours(int n) => Duration(hours: n);

    void want(String id, String owner, String title, String category,
        String description, int budget, String condition, int region,
        int radiusKm, Duration age, int durationDays, WantStatus status) {
      final created = ago(age);
      _wants.add(Want(
        id: id,
        ownerId: owner,
        title: title,
        category: category,
        description: description,
        budgetMaxRappen: budget,
        condition: condition,
        regionId: region,
        radiusKm: radiusKm,
        createdAt: created,
        expiresAt: created.add(days(durationDays)),
        status: status,
      ));
    }

    void offer(String id, String wantId, String seller, int price,
        String message, Duration age, OfferStatus status) {
      _offers.add(Offer(
        id: id,
        wantId: wantId,
        sellerId: seller,
        priceRappen: price,
        message: message,
        createdAt: ago(age),
        status: status,
        sellerName: _users[seller]!.displayName,
      ));
    }

    void message(String id, String threadId, String sender, String body,
        Duration age, {Duration? readAgo}) {
      _messages.add(Message(
        id: id,
        threadId: threadId,
        senderId: sender,
        kind: MessageKind.text,
        body: body,
        createdAt: ago(age),
        readAt: readAgo == null ? null : ago(readAgo),
      ));
    }

    // Abgeschlossenes Geschäft mit Chat und Bewertung (3f)
    void deal(String threadId, String offerId, String wantId, String buyer,
        String seller, Duration closedAgo, int agreedPrice, String place,
        Duration? handoverAgo, int stars) {
      _threads.add(ChatThread(
        id: threadId,
        offerId: offerId,
        wantId: wantId,
        buyerId: buyer,
        sellerId: seller,
        lastActivity: ago(closedAgo),
        handoverAt: handoverAgo == null ? null : ago(handoverAgo),
        handoverPlace: place,
        agreedPriceRappen: agreedPrice,
        closedAt: ago(closedAgo),
      ));
      _ratings.add(Rating(
        id: 'rating-$threadId',
        fromUserId: buyer,
        toUserId: seller,
        threadId: threadId,
        stars: stars,
        createdAt: ago(closedAgo),
      ));
    }

    // 2c/2d. «Omega Speedmaster» von Anna: Bens Angebot angenommen,
    //        Caras zwei Angebote dadurch abgesagt
    want('want-omega', 'user-anna', 'Omega Speedmaster', 'Uhren',
        'Moonwatch, gerne mit Box und Papieren.', 650000, 'Original',
        bern, 50, days(2), 14, WantStatus.aktiv);
    offer('offer-omega-ben', 'want-omega', 'user-ben', 590000,
        'Speedmaster Professional 2019, serviciert, mit Box und Papieren.',
        days(1) + hours(20), OfferStatus.angenommen);
    offer('offer-omega-cara-1', 'want-omega', 'user-cara', 620000,
        'Speedmaster Reduced, guter Zustand, ohne Papiere.',
        days(1) + hours(6), OfferStatus.abgesagt);
    offer('offer-omega-cara-2', 'want-omega', 'user-cara', 640000,
        'Speedmaster Moonwatch Hesalite, Erstbesitz.',
        hours(3), OfferStatus.abgesagt);

    // 2e. Chat zwischen Anna (Käuferin) und Ben (Verkäufer)
    _threads.add(ChatThread(
      id: 'thread-omega',
      offerId: 'offer-omega-ben',
      wantId: 'want-omega',
      buyerId: 'user-anna',
      sellerId: 'user-ben',
      lastActivity: ago(days(1)),
    ));
    message('msg-omega-1', 'thread-omega', 'user-anna',
        'Hallo Ben, wann war der letzte Service?', days(1) + hours(2),
        readAgo: days(1) + hours(1));
    message('msg-omega-2', 'thread-omega', 'user-ben',
        'Hallo Anna, im März 2025 bei Omega. Die Quittung ist dabei.',
        days(1) + hours(1), readAgo: days(1));
    message('msg-omega-3', 'thread-omega', 'user-anna',
        'Super. Könnte ich die Uhr am Samstag in Zürich anschauen?', days(1));

    // 3a. «Leica M6» von Anna, Region Winterthur, ein Angebot von Cara
    want('want-leica-m6', 'user-anna', 'Leica M6', 'Kameras',
        'Gehäuse, gerne mit 50 mm Summicron.', 280000, 'Voll funktionsfähig',
        winterthur, 20, days(3), 30, WantStatus.aktiv);
    offer('offer-m6-cara', 'want-leica-m6', 'user-cara', 265000,
        'M6 TTL von 1998, Belichtungsmesser funktioniert.', days(1),
        OfferStatus.neu);

    // 3b. «Leica Q2» von Anna, 3 Angebote (TC09)
    want('want-leica-q2', 'user-anna', 'Leica Q2', 'Kameras', '', 380000,
        'Egal', bern, 30, days(1), 7, WantStatus.aktiv);
    offer('offer-q2-ben', 'want-leica-q2', 'user-ben', 360000,
        'Q2 von 2021, mit zweitem Akku.', hours(20), OfferStatus.gesehen);
    offer('offer-q2-cara-1', 'want-leica-q2', 'user-cara', 345000,
        'Q2 mit Gebrauchsspuren am Gehäuse.', hours(8), OfferStatus.neu);
    offer('offer-q2-cara-2', 'want-leica-q2', 'user-cara', 375000,
        'Q2 wie neu, Garantie bis 2027.', hours(2), OfferStatus.neu);

    // 3c. «Rolex Datejust 36» von Anna, aktiv
    want('want-rolex', 'user-anna', 'Rolex Datejust 36', 'Uhren',
        'Stahl, Zifferblatt silber oder blau.', 700000, 'Serviciert',
        bern, 50, days(5), 30, WantStatus.aktiv);

    // 3c2. «Fujifilm X100V» von Anna, pausiert
    want('want-fujifilm', 'user-anna', 'Fujifilm X100V', 'Kameras',
        'Silber, gerne mit Originalverpackung.', 130000, 'Voll funktionsfähig',
        bern, 30, days(6), 14, WantStatus.pausiert);

    // 3d. «Eames Lounge Chair» von Anna, Budget CHF 2'000, Bens zweites
    //     Angebot (CHF 2'100) liegt über dem Budget (F-11)
    want('want-eames', 'user-anna', 'Eames Lounge Chair', 'Möbel',
        'Mit Ottomane, Leder schwarz.', 200000, 'Gebraucht',
        bern, 50, days(4), 14, WantStatus.aktiv);
    offer('offer-eames-ben-1', 'want-eames', 'user-ben', 172000,
        'Lizenzversion, Leder mit Gebrauchsspuren.', days(3), OfferStatus.neu);
    offer('offer-eames-cara', 'want-eames', 'user-cara', 195000,
        'Original Vitra, 2015 gekauft.', days(2), OfferStatus.neu);
    offer('offer-eames-ben-2', 'want-eames', 'user-ben', 210000,
        'Original Vitra, wie neu, mit Rechnung.', hours(5), OfferStatus.neu);

    // 3e. Abgelaufenes Gesuch von Anna (vor 6 Tagen abgelaufen)
    want('want-technics', 'user-anna', 'Technics SL-1200', 'Vinyl', '', 60000,
        'Egal', bern, 20, days(20), 14, WantStatus.abgelaufen);

    // 3f. Drei erledigte Gesuche, Ben hat verkauft (5, 4 und 3 Sterne)
    want('want-brompton', 'user-anna', 'Brompton M6L', 'Velo', '', 150000,
        'Fahrbereit', bern, 100, days(60), 30, WantStatus.erledigt);
    offer('offer-brompton-ben', 'want-brompton', 'user-ben', 120000,
        'Brompton 2020, frisch serviciert.', days(58), OfferStatus.angenommen);
    deal('thread-brompton', 'offer-brompton-ben', 'want-brompton', 'user-anna',
        'user-ben', days(50), 120000, 'Bahnhof Bern, Treffpunkt', days(52), 5);
    message('msg-brompton-1', 'thread-brompton', 'user-anna',
        'Danke, das Velo fährt super!', days(51), readAgo: days(50));

    want('want-makita', 'user-cara', 'Makita Akku-Bohrschrauber', 'Werkzeug',
        '', 15000, 'Gebraucht', zuerich, 30, days(45), 14, WantStatus.erledigt);
    offer('offer-makita-ben', 'want-makita', 'user-ben', 9000,
        'Mit zwei Akkus und Koffer.', days(44), OfferStatus.angenommen);
    deal('thread-makita', 'offer-makita-ben', 'want-makita', 'user-cara',
        'user-ben', days(40), 8500, 'Zürich HB', days(41), 4);

    want('want-miles', 'user-anna', 'Miles Davis – Kind of Blue', 'Vinyl',
        'Originalpressung bevorzugt.', 8000, 'Gebraucht (leichtes Knistern ok)',
        bern, 200, days(35), 7, WantStatus.erledigt);
    offer('offer-miles-ben', 'want-miles', 'user-ben', 6000,
        'Nachpressung 1997, Hülle mit Knick.', days(34), OfferStatus.angenommen);
    deal('thread-miles', 'offer-miles-ben', 'want-miles', 'user-anna',
        'user-ben', days(30), 6000, 'Versand per Post', null, 3);
  }
}

class _Credentials {
  _Credentials(this.password, this.userId, {this.confirmed = true});

  final String password;
  final String userId;

  /// Mailadresse über den Link bestätigt (UC1, Schritt 5).
  bool confirmed;
}
