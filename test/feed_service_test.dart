import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/services/feed_service.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/model/model.dart';

void main() {
  late MockRefindRepository repo;
  late FeedService service;

  setUp(() async {
    repo = MockRefindRepository(delay: Duration.zero);
    service = FeedService(repo);
    await repo.signIn('luca@refind.test', 'refind123');
  });

  Future<List<String>> titles(FeedFilter filter, {DateTime? now}) async {
    final feed = await service.getFeed(filter, viewerId: 'user-luca', now: now);
    return [for (final i in feed) i.want.title];
  }

  test('liefert dieselbe Liste wie das Repository, neueste zuerst', () async {
    expect(await titles(const FeedFilter()), ['Leica M6', 'Omega Seamaster 300']);
  });

  test('Suchbegriff mit Grossbuchstaben und Leerzeichen', () async {
    expect(await titles(const FeedFilter(query: '  LEICA ')), ['Leica M6']);
  });

  test('Umkreis: Biel (Mia) liegt nicht 10 km um Bern', () async {
    // Leica M6 liegt in Biel (Ort 3), Omega in Bern (Ort 1)
    expect(await titles(const FeedFilter(placeId: 1, radiusKm: 10)),
        ['Omega Seamaster 300']);
  });

  test('Gesuch, das inzwischen abgelaufen ist, fällt weg', () async {
    final inZweiMonaten = DateTime.now().add(const Duration(days: 60));
    expect(await titles(const FeedFilter(), now: inZweiMonaten), isEmpty);
  });
}
