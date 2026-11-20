import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/model/model.dart';

// Testdaten wie supabase/05_testdaten.sql: Anna (Käuferin, alle aktiven
// Gesuche), Ben (Verkäufer, keine eigenen Gesuche), Cara.

void main() {
  late MockRefindRepository repo;

  setUp(() => repo = MockRefindRepository(delay: Duration.zero));

  test('Anmelden mit Testkonto liefert das Profil', () async {
    final user = await repo.signIn('anna@refind.test', 'refind123');
    expect(user.displayName, 'Anna');
    expect(user.cityId, 1); // Bern
  });

  test('Falsches Passwort wirft nichtBerechtigt', () async {
    expect(
      () => repo.signIn('anna@refind.test', 'falsch'),
      throwsA(isA<RepositoryException>()
          .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
    );
  });

  test('TC01: vor der Bestätigung verweigert, danach angemeldet', () async {
    await repo.signUp('Test Person', 'neu@refind.test', 'geheim123');
    await expectLater(
      repo.signIn('neu@refind.test', 'geheim123'),
      throwsA(isA<RepositoryException>().having(
          (e) => e.kind, 'kind', RepositoryErrorKind.mailNichtBestaetigt)),
    );
    await repo.resendConfirmation('neu@refind.test'); // Mock: bestätigt sofort
    final user = await repo.signIn('neu@refind.test', 'geheim123');
    expect(user.displayName, 'Test Person');
  });

  test('Doppelte Mailadresse wirft konflikt, ohne das Konto zu verraten',
      () async {
    await expectLater(
      repo.signUp('Anna 2', 'anna@refind.test', 'geheim123'),
      throwsA(isA<RepositoryException>()
          .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)
          .having((e) => e.message, 'message', isNot(contains('Konto')))),
    );
  });

  test('TC02: nach mehreren Fehlversuchen vorübergehend gesperrt', () async {
    for (var i = 0; i < MockRefindRepository.maxFailedAttempts; i++) {
      await expectLater(
          repo.signIn('anna@refind.test', 'falsch'), throwsA(isA<RepositoryException>()));
    }
    // Jetzt hilft auch das richtige Passwort nicht.
    await expectLater(
      repo.signIn('anna@refind.test', 'refind123'),
      throwsA(isA<RepositoryException>()
          .having((e) => e.message, 'message', contains('Fehlversuche'))),
    );
  });

  test('Feed zeigt keine eigenen Gesuche', () async {
    // Alle aktiven Gesuche der Testdaten gehören Anna.
    await repo.signIn('anna@refind.test', 'refind123');
    expect(await repo.getFeed(const FeedFilter()), isEmpty);
  });

  test('Angebot annehmen sagt die übrigen ab', () async {
    await repo.signIn('anna@refind.test', 'refind123');
    await repo.acceptOffer('offer-eames-ben-1');
    final offers = await repo.getOffers('want-eames', OfferSort.neueste);
    final statusById = {for (final o in offers) o.id: o.status};
    expect(statusById['offer-eames-ben-1'], OfferStatus.angenommen);
    expect(statusById['offer-eames-cara'], OfferStatus.abgesagt);
    expect(statusById['offer-eames-ben-2'], OfferStatus.abgesagt);
  });

  group('UC6: Angebot senden', () {
    setUp(() => repo.signIn('ben@refind.test', 'refind123'));

    test('gültiges Angebot ist neu und erscheint beim Besitzer', () async {
      final offer = await repo.createOffer('want-leica-m6', 210000,
          '  M6 mit Summicron  ', [File('a.jpg'), File('b.jpg')]);
      expect(offer.status, OfferStatus.neu);
      expect(offer.message, 'M6 mit Summicron');
      expect(offer.photos, hasLength(2));
      expect(offer.sellerName, 'Ben');

      await repo.signOut();
      await repo.signIn('anna@refind.test', 'refind123');
      final offers = await repo.getOffers('want-leica-m6', OfferSort.neueste);
      // neuestes zuerst, danach das Angebot von Cara aus den Testdaten
      expect(offers.map((o) => o.id), [offer.id, 'offer-m6-cara']);
    });

    for (final (name, price, message, photos) in [
      ('Preis 0', 0, '', 0),
      ('Preis negativ', -100, '', 0),
      ('Preis über Maximum', OfferLimits.maxPriceRappen + 1, '', 0),
      ('Nachricht zu lang', 1000, 'a' * (OfferLimits.maxMessageLength + 1), 0),
      ('vier Fotos', 1000, '', 4),
    ]) {
      test('$name wird abgelehnt', () async {
        await expectLater(
          repo.createOffer('want-leica-m6', price, message,
              [for (var i = 0; i < photos; i++) File('$i.jpg')]),
          throwsA(isA<RepositoryException>().having(
              (e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)),
        );
      });
    }

    test('auf eigenes Gesuch: nichtBerechtigt', () async {
      // Ben hat keine eigenen Gesuche, darum als Anna.
      await repo.signOut();
      await repo.signIn('anna@refind.test', 'refind123');
      await expectLater(
        repo.createOffer('want-rolex', 700000, '', const []),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });

    test('auf pausiertes Gesuch: konflikt', () async {
      await expectLater(
        repo.createOffer('want-fujifilm', 120000, '', const []),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)),
      );
    });

    test('auf Gesuch mit angenommenem Angebot: konflikt', () async {
      await expectLater(
        repo.createOffer('want-omega', 600000, '', const []),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)),
      );
    });
  });

  group('UC7: Angebote ansehen und annehmen', () {
    setUp(() => repo.signIn('anna@refind.test', 'refind123'));

    test('F-10: nach Preis sortiert, mit Namen der Verkäufer', () async {
      final offers = await repo.getOffers('want-eames', OfferSort.guenstigste);
      expect(offers.map((o) => o.priceRappen), [172000, 195000, 210000]);
      expect(offers.map((o) => o.sellerName), ['Ben', 'Cara', 'Ben']);
    });

    test('nach Datum: neuestes zuerst', () async {
      final offers = await repo.getOffers('want-eames', OfferSort.neueste);
      expect(offers.map((o) => o.id),
          ['offer-eames-ben-2', 'offer-eames-cara', 'offer-eames-ben-1']);
    });

    test('TC18: Teuerste: Preis absteigend', () async {
      final offers = await repo.getOffers('want-eames', OfferSort.teuerste);
      expect(offers.map((o) => o.priceRappen), [210000, 195000, 172000]);
    });

    test('gleicher Preis: das neuere Angebot zuerst, bei beiden Preis-Sortierungen',
        () async {
      // Ben bietet wie Cara CHF 1'950, aber später
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      final same = await repo.createOffer('want-eames', 195000, '', const []);
      await repo.signOut();
      await repo.signIn('anna@refind.test', 'refind123');

      List<String> ids(List<Offer> offers) => [for (final o in offers) o.id];
      expect(ids(await repo.getOffers('want-eames', OfferSort.guenstigste)),
          ['offer-eames-ben-1', same.id, 'offer-eames-cara', 'offer-eames-ben-2']);
      expect(ids(await repo.getOffers('want-eames', OfferSort.teuerste)),
          ['offer-eames-ben-2', same.id, 'offer-eames-cara', 'offer-eames-ben-1']);
    });

    test('fremdes Gesuch: nichtBerechtigt', () async {
      await expectLater(
        repo.getOffers('want-makita', OfferSort.neueste), // gehört Cara
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });

    test('markOffersSeen: neu wird gesehen', () async {
      await repo.markOffersSeen('want-eames');
      final offers = await repo.getOffers('want-eames', OfferSort.neueste);
      expect(offers.every((o) => o.status == OfferStatus.gesehen), isTrue);
    });

    test('F-12: Chat zwischen Käuferin und Verkäufer', () async {
      final thread = await repo.acceptOffer('offer-eames-ben-2');
      expect(thread.buyerId, 'user-anna');
      expect(thread.sellerId, 'user-ben');
      expect(thread.offerId, 'offer-eames-ben-2');
      final chats = await repo.getChats();
      expect(chats.map((c) => c.thread.id), contains(thread.id));
    });

    test('zweites Annehmen: konflikt mit verständlicher Meldung', () async {
      await repo.acceptOffer('offer-eames-ben-1');
      await expectLater(
        repo.acceptOffer('offer-eames-cara'),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)
            .having((e) => e.message, 'message', acceptConflictMessage)),
      );
    });

    test('Angebot anderer Leute annehmen: nichtBerechtigt', () async {
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      await expectLater(
        repo.acceptOffer('offer-eames-cara'),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });
  });

  group('UC3: Gesuch erfassen', () {
    WantDraft draft({
      String title = 'Omega Seamaster 166.062',
      String category = 'Uhren',
      int budget = 200000,
      String condition = 'Original',
    }) =>
        WantDraft(
          title: title,
          category: category,
          description: 'Gerne mit Box.',
          budgetMaxRappen: budget,
          condition: condition,
          regionId: 1,
          radiusKm: 25,
          durationDays: 14,
        );

    setUp(() => repo.signIn('anna@refind.test', 'refind123'));

    test('TC07: gültiges Gesuch ist aktiv und erscheint in Meine Gesuche',
        () async {
      final want = await repo.createWant(draft());
      expect(want.status, WantStatus.aktiv);
      expect(want.expiresAt.difference(want.createdAt).inDays, 14);
      final mine = await repo.getMyWants();
      expect(mine.first.want.id, want.id); // neuestes zuerst
      expect(mine.first.region.name, 'Bern');
    });

    test('TC07: Gesuch erscheint im Feed eines zweiten Kontos', () async {
      final want = await repo.createWant(draft());
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      final feed = await repo.getFeed(const FeedFilter());
      expect(feed.map((i) => i.want.id), contains(want.id));
    });

    // Prüfung «auf dem Server»: auch wenn jemand die Maske umgeht.
    for (final (name, bad) in [
      ('ohne Titel', draft(title: '  ')),
      ('Titel mit 81 Zeichen', draft(title: 'a' * 81)),
      ('Budget 0', draft(budget: 0)),
      ('Budget negativ', draft(budget: -500)),
      ('Budget über Maximum', draft(budget: WantLimits.maxBudgetRappen + 1)),
      ('unbekannte Kategorie', draft(category: 'Autos')),
      ('Zustand passt nicht zur Kategorie', draft(condition: 'Fahrbereit')),
    ]) {
      test('TC08: $name wird abgelehnt, nichts gespeichert', () async {
        final before = (await repo.getMyWants()).length;
        await expectLater(
          repo.createWant(bad),
          throwsA(isA<RepositoryException>().having(
              (e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)),
        );
        expect((await repo.getMyWants()).length, before);
      });
    }
  });

  group('UC5: Feed', () {
    Future<List<String>> titles([FeedFilter filter = const FeedFilter()]) async {
      final feed = await repo.getFeed(filter);
      return [for (final i in feed) i.want.title];
    }

    // Wie der Handytest mit ben@refind.test und supabase/05_testdaten.sql
    setUp(() => repo.signIn('ben@refind.test', 'refind123'));

    test('TC12: nur aktive Gesuche anderer Konten, neueste zuerst', () async {
      expect(await titles(), [
        'Leica Q2', // vor 1 Tag
        'Leica M6', // vor 3 Tagen
        'Eames Lounge Chair', // vor 4 Tagen
        'Rolex Datejust 36', // vor 5 Tagen
      ]);
      // nicht dabei: Omega (Angebot angenommen), Fujifilm (pausiert),
      // Technics (abgelaufen), Brompton, Makita, Miles Davis (erledigt)
    });

    test('TC12: Kategorie Uhren', () async {
      expect(await titles(const FeedFilter(category: 'Uhren')),
          ['Rolex Datejust 36']);
    });

    test('TC13: Suchbegriff nur im Titel, nicht in der Beschreibung', () async {
      expect(await titles(const FeedFilter(query: 'leica')),
          ['Leica Q2', 'Leica M6']);
      // «Summicron» steht nur in der Beschreibung der Leica M6
      expect(await titles(const FeedFilter(query: 'Summicron')), isEmpty);
    });

    test('TC14: Winterthur mit 20 km: Leica M6 ja, Gesuche aus Bern nein',
        () async {
      // Das Repository liefert die Distanz, den Umkreis wendet FeedService an.
      final feed = await repo.getFeed(const FeedFilter(placeId: 3, radiusKm: 20));
      final m6 = feed.firstWhere((i) => i.want.id == 'want-leica-m6');
      expect(m6.region.name, 'Winterthur');
      expect(feed.where((i) => i.region.name == 'Bern'), isEmpty);
    });

    test('Suchbegriff zu lang oder unbekannte Kategorie wird abgewiesen', () async {
      for (final bad in [
        FeedFilter(query: 'a' * 81),
        const FeedFilter(category: 'Autos'),
        const FeedFilter(placeId: 1, radiusKm: 0),
      ]) {
        await expectLater(
          repo.getFeed(bad),
          throwsA(isA<RepositoryException>().having(
              (e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)),
        );
      }
    });

    test('ohne Anmeldung kein Feed', () async {
      await repo.signOut();
      await expectLater(
        repo.getFeed(const FeedFilter()),
        throwsA(isA<RepositoryException>().having(
            (e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });
  });

  test('Profil-Statistik: Ben hat drei Geschäfte mit 5, 4 und 3 Sternen',
      () async {
    await repo.signIn('anna@refind.test', 'refind123');
    final stats = await repo.getProfileStats('user-ben');
    expect(stats.dealCount, 3);
    expect(stats.averageStars, 4.0);
    expect(stats.activeWantCount, 0);
  });

  group('UC4: Pausieren, Aktivieren, Nochmal aufhängen (F-05)', () {
    Future<List<String>> feedOfBen() async {
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      final feed = await repo.getFeed(const FeedFilter());
      await repo.signOut();
      await repo.signIn('anna@refind.test', 'refind123');
      return [for (final i in feed) i.want.id];
    }

    Matcher conflict = throwsA(isA<RepositoryException>()
        .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)
        .having((e) => e.message, 'message', wantStatusConflictMessage));

    setUp(() => repo.signIn('anna@refind.test', 'refind123'));

    test('TC10: pausiert fehlt im Feed, nach Aktivieren wieder da', () async {
      await repo.setWantStatus('want-rolex', WantStatus.pausiert);
      expect(await feedOfBen(), isNot(contains('want-rolex')));

      await repo.setWantStatus('want-rolex', WantStatus.aktiv);
      expect(await feedOfBen(), contains('want-rolex'));
    });

    test('TC11: abgelaufenes Gesuch nochmal aufhängen: 14 Tage, wieder im Feed',
        () async {
      expect(await feedOfBen(), isNot(contains('want-technics')));
      final before = DateTime.now();
      final want = await repo.republishWant('want-technics');
      expect(want.status, WantStatus.aktiv);
      expect(want.createdAt.isBefore(before), isFalse); // neu aufgehängt
      expect(want.expiresAt.difference(want.createdAt), const Duration(days: 14));
      expect(await feedOfBen(), contains('want-technics'));
    });

    test('pausiertes Gesuch aktivieren (Fujifilm)', () async {
      await repo.setWantStatus('want-fujifilm', WantStatus.aktiv);
      final mine = await repo.getMyWants();
      expect(mine.firstWhere((s) => s.want.id == 'want-fujifilm').want.status,
          WantStatus.aktiv);
    });

    test('UC4 Ausnahme: mit angenommenem Angebot nicht pausieren (Omega)',
        () async {
      await expectLater(repo.setWantStatus('want-omega', WantStatus.pausiert), conflict);
    });

    test('erledigt: weder pausieren noch nochmal aufhängen', () async {
      await expectLater(repo.setWantStatus('want-brompton', WantStatus.pausiert), conflict);
      await expectLater(repo.republishWant('want-brompton'), conflict);
    });

    test('aktives Gesuch lässt sich nicht nochmal aufhängen', () async {
      await expectLater(repo.republishWant('want-rolex'), conflict);
    });

    test('abgelaufenes Gesuch lässt sich nicht pausieren oder aktivieren',
        () async {
      await expectLater(repo.setWantStatus('want-technics', WantStatus.pausiert), conflict);
      await expectLater(repo.setWantStatus('want-technics', WantStatus.aktiv), conflict);
    });

    test('nicht erlaubte Wechsel: aktiv → aktiv, aktiv → erledigt', () async {
      await expectLater(repo.setWantStatus('want-rolex', WantStatus.aktiv), conflict);
      await expectLater(repo.setWantStatus('want-rolex', WantStatus.erledigt), conflict);
    });

    test('TC28: fremdes Gesuch: nichtBerechtigt', () async {
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      await expectLater(
        repo.setWantStatus('want-rolex', WantStatus.pausiert),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
      await expectLater(
        repo.republishWant('want-technics'),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });
  });
}
