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
}
