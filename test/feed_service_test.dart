import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/services/feed_service.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/model/model.dart';

// Testdaten wie supabase/05_testdaten.sql, angemeldet als Ben.

void main() {
  late MockRefindRepository repo;
  late FeedService service;

  setUp(() async {
    repo = MockRefindRepository(delay: Duration.zero);
    service = FeedService(repo);
    await repo.signIn('ben@refind.test', 'refind123');
  });

  Future<List<String>> titles(FeedFilter filter, {DateTime? now}) async {
    final feed = await service.getFeed(filter, viewerId: 'user-ben', now: now);
    return [for (final i in feed) i.want.title];
  }

  test('liefert dieselbe Liste wie das Repository, neueste zuerst', () async {
    expect(await titles(const FeedFilter()), [
      'Leica Q2',
      'Leica M6',
      'Eames Lounge Chair',
      'Rolex Datejust 36',
    ]);
  });

  test('Suchbegriff mit Grossbuchstaben und Leerzeichen', () async {
    expect(await titles(const FeedFilter(query: '  LEICA ')),
        ['Leica Q2', 'Leica M6']);
  });

  test('TC14: Winterthur mit 20 km zeigt die Leica M6, nicht die aus Bern',
      () async {
    // Ort 3 = Winterthur. Leica M6 liegt in Winterthur, die übrigen in Bern.
    expect(await titles(const FeedFilter(placeId: 3, radiusKm: 20)),
        ['Leica M6']);
  });

  test('Umkreis um Bern: die drei Gesuche aus Bern', () async {
    expect(await titles(const FeedFilter(placeId: 1, radiusKm: 10)),
        ['Leica Q2', 'Eames Lounge Chair', 'Rolex Datejust 36']);
  });

  test('Gesuch, das inzwischen abgelaufen ist, fällt weg', () async {
    final inZweiMonaten = DateTime.now().add(const Duration(days: 60));
    expect(await titles(const FeedFilter(), now: inZweiMonaten), isEmpty);
  });
}
