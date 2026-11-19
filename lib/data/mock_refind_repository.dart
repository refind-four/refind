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
/// Testkonten (Passwort jeweils `refind123`):
/// * anna@refind.test – Anna Keller, Bern
/// * luca@refind.test – Luca Brunner, Thun
/// * mia@refind.test  – Mia Schmid, Biel
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
  Future<void> setWantStatus(String wantId, WantStatus status) async {
    await _wait();
    final want = _myWant(wantId);
    final allowed = (want.status == WantStatus.aktiv && status == WantStatus.pausiert) ||
        (want.status == WantStatus.pausiert && status == WantStatus.aktiv);
    if (!allowed) {
      _conflict('Wechsel von «${want.status.name}» zu «${status.name}» ist nicht erlaubt.');
    }
    _replaceWant(want.copyWith(status: status));
  }

  @override
  Future<Want> republishWant(String wantId) async {
    await _wait();
    final want = _myWant(wantId);
    if (want.status != WantStatus.abgelaufen) {
      _conflict('Nur abgelaufene Gesuche lassen sich erneut aufhängen.');
    }
    final duration = want.expiresAt.difference(want.createdAt);
    final updated = want.copyWith(
      status: WantStatus.aktiv,
      expiresAt: DateTime.now().add(duration),
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
    if (text.trim().isEmpty) _invalid('Die Nachricht ist leer.');
    return _addMessage(threadId, MessageKind.text, text.trim());
  }

  @override
  Future<Message> sendPhoto(String threadId, File photo) async {
    await _wait();
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
    final thread = _myThread(threadId);
    if (thread.buyerId != _me) _forbidden('Nur der Käufer kann abschliessen.');
    if (thread.isClosed) _conflict('Das Geschäft ist bereits abgeschlossen.');
    if (agreedPriceRappen <= 0) _invalid('Der Preis muss grösser als 0 sein.');
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

  void _seed() {
    final now = DateTime.now();

    _places.addAll(const [
      Place(id: 1, plz: 3011, name: 'Bern', e: 2600670, n: 1199655),
      Place(id: 2, plz: 3600, name: 'Thun', e: 2614600, n: 1178700),
      Place(id: 3, plz: 2502, name: 'Biel/Bienne', e: 2585300, n: 1220900),
      Place(id: 4, plz: 3400, name: 'Burgdorf', e: 2614200, n: 1211800),
      Place(id: 5, plz: 3800, name: 'Interlaken', e: 2632800, n: 1170800),
      Place(id: 6, plz: 8001, name: 'Zürich', e: 2683200, n: 1247600),
      Place(id: 7, plz: 4051, name: 'Basel', e: 2611300, n: 1267300),
      Place(id: 8, plz: 3074, name: 'Muri bei Bern', e: 2603300, n: 1197800),
    ]);

    void user(String id, String name, String mail, int cityId, int monthsAgo) {
      _users[id] = User(
        id: id,
        displayName: name,
        cityId: cityId,
        radiusKm: 25,
        memberSince: DateTime(now.year, now.month - monthsAgo, 1),
      );
      _credentials[mail] = _Credentials('refind123', id);
    }

    user('user-anna', 'Anna Keller', 'anna@refind.test', 1, 8);
    user('user-luca', 'Luca Brunner', 'luca@refind.test', 2, 5);
    user('user-mia', 'Mia Schmid', 'mia@refind.test', 3, 2);

    Want want(String id, String owner, String title, String category,
        String description, int budget, String condition, int region,
        {int daysAgo = 1, WantStatus status = WantStatus.aktiv}) {
      final created = now.subtract(Duration(days: daysAgo));
      return Want(
        id: id,
        ownerId: owner,
        title: title,
        category: category,
        description: description,
        budgetMaxRappen: budget,
        condition: condition,
        regionId: region,
        radiusKm: 30,
        createdAt: created,
        expiresAt: created.add(const Duration(days: 30)),
        status: status,
      );
    }

    _wants.addAll([
      want('want-1', 'user-anna', 'Omega Seamaster 300', 'Uhren',
          'Suche eine Seamaster 300 aus den 60er-Jahren, gerne mit Box.',
          250000, 'Original', 1, daysAgo: 2),
      want('want-2', 'user-anna', 'Eames Lounge Chair', 'Möbel',
          'Original Vitra, Leder schwarz, Nussbaum.', 450000, 'Egal', 1,
          daysAgo: 10, status: WantStatus.pausiert),
      want('want-3', 'user-luca', 'Rennvelo Rahmengrösse 56', 'Velo',
          'Stahlrahmen, gerne Columbus-Rohre, fahrbereit.', 80000,
          'Fahrbereit', 2, daysAgo: 1),
      want('want-4', 'user-mia', 'Pink Floyd – The Wall (Erstpressung)', 'Vinyl',
          'UK-Erstpressung 1979, Cover ohne Risse.', 15000,
          'Gebraucht (leichtes Knistern ok)', 3,
          daysAgo: 4),
      want('want-5', 'user-mia', 'Leica M6', 'Kameras',
          'Body reicht, Objektiv wäre ein Bonus.', 220000, 'Voll funktionsfähig', 3,
          daysAgo: 0),
      want('want-6', 'user-luca', 'Makita Akkuschrauber 18 V', 'Werkzeug',
          'Mit zwei Akkus und Ladegerät.', 12000, 'Gebraucht', 4,
          daysAgo: 3),
    ]);

    _offers.addAll([
      Offer(id: 'offer-1', wantId: 'want-1', sellerId: 'user-luca',
          priceRappen: 230000, message: 'Habe eine von 1967, frisch serviciert.',
          createdAt: now.subtract(const Duration(hours: 20)),
          status: OfferStatus.neu),
      Offer(id: 'offer-2', wantId: 'want-1', sellerId: 'user-mia',
          priceRappen: 245000, message: 'Originalzustand mit Box und Papieren.',
          createdAt: now.subtract(const Duration(hours: 30)),
          status: OfferStatus.gesehen),
      // Liegt über der Preisobergrenze von CHF 2'500 (F-11).
      Offer(id: 'offer-4', wantId: 'want-1', sellerId: 'user-mia',
          priceRappen: 265000, message: 'Seamaster 300 von 1964, mit Revision.',
          createdAt: now.subtract(const Duration(hours: 5)),
          status: OfferStatus.neu),
      Offer(id: 'offer-3', wantId: 'want-4', sellerId: 'user-anna',
          priceRappen: 14000, message: 'Erstpressung, Vinyl in sehr gutem Zustand.',
          createdAt: now.subtract(const Duration(days: 3)),
          status: OfferStatus.angenommen),
    ]);

    _threads.add(ChatThread(
      id: 'thread-1',
      offerId: 'offer-3',
      wantId: 'want-4',
      buyerId: 'user-mia',
      sellerId: 'user-anna',
      lastActivity: now.subtract(const Duration(hours: 2)),
    ));

    _messages.addAll([
      Message(id: 'msg-1', threadId: 'thread-1', senderId: 'user-mia',
          kind: MessageKind.text, body: 'Hallo Anna, wann könnten wir uns treffen?',
          createdAt: now.subtract(const Duration(hours: 3)),
          readAt: now.subtract(const Duration(hours: 2, minutes: 30))),
      Message(id: 'msg-2', threadId: 'thread-1', senderId: 'user-anna',
          kind: MessageKind.text, body: 'Samstag am Bahnhof Bern ginge gut.',
          createdAt: now.subtract(const Duration(hours: 2))),
    ]);
  }
}

class _Credentials {
  _Credentials(this.password, this.userId, {this.confirmed = true});

  final String password;
  final String userId;

  /// Mailadresse über den Link bestätigt (UC1, Schritt 5).
  bool confirmed;
}
