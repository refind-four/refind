import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/model/model.dart';

void main() {
  late MockRefindRepository repo;

  setUp(() => repo = MockRefindRepository(delay: Duration.zero));

  test('Anmelden mit Testkonto liefert das Profil', () async {
    final user = await repo.signIn('anna@refind.test', 'refind123');
    expect(user.displayName, 'Anna Keller');
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
    await repo.signIn('anna@refind.test', 'refind123');
    final feed = await repo.getFeed(const FeedFilter());
    expect(feed, isNotEmpty);
    expect(feed.every((item) => item.want.ownerId != 'user-anna'), isTrue);
  });

  test('Angebot annehmen sagt die übrigen ab', () async {
    await repo.signIn('anna@refind.test', 'refind123');
    await repo.acceptOffer('offer-1');
    final offers = await repo.getOffers('want-1', OfferSort.neueste);
    final statusById = {for (final o in offers) o.id: o.status};
    expect(statusById['offer-1'], OfferStatus.angenommen);
    expect(statusById['offer-2'], OfferStatus.abgesagt);
  });

  group('UC6: Angebot senden', () {
    setUp(() => repo.signIn('luca@refind.test', 'refind123'));

    test('gültiges Angebot ist neu und erscheint beim Besitzer', () async {
      final offer = await repo.createOffer(
          'want-5', 210000, '  M6 mit Summicron  ', [File('a.jpg'), File('b.jpg')]);
      expect(offer.status, OfferStatus.neu);
      expect(offer.message, 'M6 mit Summicron');
      expect(offer.photos, hasLength(2));
      expect(offer.sellerName, 'Luca Brunner');

      await repo.signOut();
      await repo.signIn('mia@refind.test', 'refind123');
      final offers = await repo.getOffers('want-5', OfferSort.neueste);
      expect(offers.single.id, offer.id);
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
          repo.createOffer(
              'want-5', price, message, [for (var i = 0; i < photos; i++) File('$i.jpg')]),
          throwsA(isA<RepositoryException>().having(
              (e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)),
        );
      });
    }

    test('auf eigenes Gesuch: nichtBerechtigt', () async {
      await expectLater(
        repo.createOffer('want-3', 70000, '', const []),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });

    test('auf pausiertes Gesuch: konflikt', () async {
      await expectLater(
        repo.createOffer('want-2', 400000, '', const []),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)),
      );
    });
  });

  group('UC7: Angebote ansehen und annehmen', () {
    setUp(() => repo.signIn('anna@refind.test', 'refind123'));

    test('F-10: nach Preis sortiert, mit Namen der Verkäufer', () async {
      final offers = await repo.getOffers('want-1', OfferSort.guenstigste);
      expect(offers.map((o) => o.priceRappen), [230000, 245000, 265000]);
      expect(offers.first.sellerName, 'Luca Brunner');
    });

    test('nach Datum: neuestes zuerst', () async {
      final offers = await repo.getOffers('want-1', OfferSort.neueste);
      expect(offers.map((o) => o.id), ['offer-4', 'offer-1', 'offer-2']);
    });

    test('fremdes Gesuch: nichtBerechtigt', () async {
      await expectLater(
        repo.getOffers('want-3', OfferSort.neueste),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });

    test('markOffersSeen: neu wird gesehen', () async {
      await repo.markOffersSeen('want-1');
      final offers = await repo.getOffers('want-1', OfferSort.neueste);
      expect(offers.every((o) => o.status == OfferStatus.gesehen), isTrue);
    });

    test('F-12: Chat zwischen Käuferin und Verkäufer', () async {
      final thread = await repo.acceptOffer('offer-4');
      expect(thread.buyerId, 'user-anna');
      expect(thread.sellerId, 'user-mia');
      expect(thread.offerId, 'offer-4');
      final chats = await repo.getChats();
      expect(chats.map((c) => c.thread.id), contains(thread.id));
    });

    test('zweites Annehmen: konflikt mit verständlicher Meldung', () async {
      await repo.acceptOffer('offer-1');
      await expectLater(
        repo.acceptOffer('offer-2'),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)
            .having((e) => e.message, 'message', acceptConflictMessage)),
      );
    });

    test('Angebot anderer Leute annehmen: nichtBerechtigt', () async {
      await repo.signOut();
      await repo.signIn('luca@refind.test', 'refind123');
      await expectLater(
        repo.acceptOffer('offer-2'),
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
      await repo.signIn('luca@refind.test', 'refind123');
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
}
