import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/filter_logic.dart';
import 'package:refind/model/model.dart';

// Orte wie in supabase/05_testdaten.sql (LV95 in Metern).
const bern = Place(id: 1, plz: 3000, name: 'Bern', e: 2600670, n: 1199655);
const winterthur =
    Place(id: 3, plz: 8400, name: 'Winterthur', e: 2697000, n: 1261800);

final now = DateTime(2026, 11, 19, 12);

Want want({
  String id = 'w1',
  String owner = 'anna',
  String title = 'Leica M6',
  String category = 'Kameras',
  WantStatus status = WantStatus.aktiv,
  DateTime? createdAt,
  DateTime? expiresAt,
}) =>
    Want(
      id: id,
      ownerId: owner,
      title: title,
      category: category,
      description: '',
      budgetMaxRappen: 280000,
      condition: 'Egal',
      regionId: 1,
      radiusKm: 20,
      createdAt: createdAt ?? now.subtract(const Duration(days: 1)),
      expiresAt: expiresAt ?? now.add(const Duration(days: 6)),
      status: status,
    );

FeedItem item(Want w, {Place region = bern}) =>
    FeedItem(want: w, buyerName: 'Anna', region: region);

void main() {
  group('Suchbegriff im Titel (F-07, TC13)', () {
    test('Leica findet Leica, nicht Rolex', () {
      expect(FilterLogic.matchesQuery('Leica M6', 'Leica'), isTrue);
      expect(FilterLogic.matchesQuery('Rolex Datejust 36', 'Leica'), isFalse);
    });

    test('Gross- und Kleinschreibung egal', () {
      expect(FilterLogic.matchesQuery('Leica Q2', 'LEICA'), isTrue);
      expect(FilterLogic.matchesQuery('LEICA Q2', 'leica'), isTrue);
    });

    test('Umlaute', () {
      expect(FilterLogic.matchesQuery('Stuhl für Büro', 'BÜRO'), isTrue);
      expect(FilterLogic.matchesQuery('Möbel', 'mobel'), isFalse);
    });

    test('leer, null oder nur Leerzeichen → alles passt', () {
      expect(FilterLogic.matchesQuery('Leica M6', null), isTrue);
      expect(FilterLogic.matchesQuery('Leica M6', ''), isTrue);
      expect(FilterLogic.matchesQuery('Leica M6', '    '), isTrue);
    });

    test('Leerzeichen am Rand und doppelte Leerzeichen', () {
      expect(FilterLogic.matchesQuery('Leica M6', '  leica   m6 '), isTrue);
      expect(FilterLogic.matchesQuery('Leica  M6', 'leica m6'), isTrue);
    });

    test('Teil eines Wortes passt', () {
      expect(FilterLogic.matchesQuery('Omega Speedmaster', 'speed'), isTrue);
    });

    test('Sonderzeichen gelten wörtlich, nicht als Platzhalter', () {
      expect(FilterLogic.matchesQuery('Leica M6', '%'), isFalse);
      expect(FilterLogic.matchesQuery('Leica M6', '.*'), isFalse);
      expect(FilterLogic.matchesQuery('100% Wolle', '100%'), isTrue);
    });

    test('Suchbegriff länger als der Titel', () {
      expect(FilterLogic.matchesQuery('M6', 'Leica M6'), isFalse);
    });

    test('normalizeQuery', () {
      expect(FilterLogic.normalizeQuery('  LEICA   M6 '), 'leica m6');
      expect(FilterLogic.normalizeQuery(null), '');
      expect(FilterLogic.maxQueryLength, 80);
    });
  });

  group('Kategorie (F-06, TC12)', () {
    test('keine Kategorie → alle', () {
      expect(FilterLogic.matchesCategory('Uhren', null), isTrue);
    });

    test('nur die gewählte Kategorie', () {
      expect(FilterLogic.matchesCategory('Uhren', 'Uhren'), isTrue);
      expect(FilterLogic.matchesCategory('Kameras', 'Uhren'), isFalse);
    });

    test('genaue Schreibweise (Whitelist)', () {
      expect(FilterLogic.matchesCategory('Uhren', 'uhren'), isFalse);
    });
  });

  group('Umkreis (F-08, TC14)', () {
    test('Winterthur 20 km: Winterthur ja, Bern nein', () {
      expect(FilterLogic.isWithinRadius(winterthur, winterthur, 20), isTrue);
      expect(FilterLogic.isWithinRadius(bern, winterthur, 20), isFalse);
    });

    test('genau auf der Grenze zählt dazu', () {
      final distance = winterthur.distanceKmTo(bern);
      expect(FilterLogic.isWithinRadius(bern, winterthur, distance.ceil()), isTrue);
      expect(FilterLogic.isWithinRadius(bern, winterthur, distance.floor()), isFalse);
      const zehnKm = Place(id: 9, plz: 1, name: 'X', e: 2600670, n: 1209655);
      expect(FilterLogic.isWithinRadius(zehnKm, bern, 10), isTrue);
    });

    test('ohne Ortschaft oder ohne Umkreis → alle', () {
      expect(FilterLogic.isWithinRadius(bern, null, 20), isTrue);
      expect(FilterLogic.isWithinRadius(bern, winterthur, null), isTrue);
    });
  });

  group('Sichtbar im Feed (F-06, TC12)', () {
    bool visible(Want w, {bool accepted = false}) => FilterLogic.isVisibleInFeed(
        w, viewerId: 'ben', now: now, hasAcceptedOffer: accepted);

    test('aktives Gesuch eines anderen Kontos', () {
      expect(visible(want()), isTrue);
    });

    test('eigenes Gesuch nicht', () {
      expect(visible(want(owner: 'ben')), isFalse);
    });

    test('pausiert, abgelaufen, erledigt nicht', () {
      expect(visible(want(status: WantStatus.pausiert)), isFalse);
      expect(visible(want(status: WantStatus.abgelaufen)), isFalse);
      expect(visible(want(status: WantStatus.erledigt)), isFalse);
    });

    test('mit angenommenem Angebot nicht (Omega)', () {
      expect(visible(want(title: 'Omega Speedmaster'), accepted: true), isFalse);
    });

    test('Status aktiv, aber Ablaufdatum vorbei', () {
      expect(
          visible(want(expiresAt: now.subtract(const Duration(seconds: 1)))),
          isFalse);
    });

    test('läuft genau jetzt ab → nicht mehr sichtbar', () {
      expect(visible(want(expiresAt: now)), isFalse);
      expect(visible(want(expiresAt: now.add(const Duration(seconds: 1)))),
          isTrue);
    });
  });

  group('apply: alles zusammen', () {
    final m6 = item(want(id: 'm6', title: 'Leica M6',
        createdAt: now.subtract(const Duration(days: 3))), region: winterthur);
    final q2 = item(want(id: 'q2', title: 'Leica Q2',
        createdAt: now.subtract(const Duration(days: 1))));
    final rolex = item(want(id: 'rolex', title: 'Rolex Datejust 36',
        category: 'Uhren', createdAt: now.subtract(const Duration(days: 5))));
    final eames = item(want(id: 'eames', title: 'Eames Lounge Chair',
        category: 'Möbel', createdAt: now.subtract(const Duration(days: 4))));
    final all = [rolex, m6, eames, q2];

    List<String> ids(List<FeedItem> items) => [for (final i in items) i.want.id];

    test('ohne Filter: alle, das neueste zuerst', () {
      expect(ids(FilterLogic.apply(all, const FeedFilter())),
          ['q2', 'm6', 'eames', 'rolex']);
    });

    test('Suche «Leica» zeigt nur die zwei Leicas', () {
      expect(ids(FilterLogic.apply(all, const FeedFilter(query: 'Leica'))),
          ['q2', 'm6']);
    });

    test('Kategorie Uhren', () {
      expect(ids(FilterLogic.apply(all, const FeedFilter(category: 'Uhren'))),
          ['rolex']);
    });

    test('Suchbegriff und Kategorie zusammen', () {
      expect(
          FilterLogic.apply(
              all, const FeedFilter(query: 'Leica', category: 'Uhren')),
          isEmpty);
    });

    test('Umkreis Winterthur 20 km', () {
      expect(
          ids(FilterLogic.apply(
              all, const FeedFilter(placeId: 3, radiusKm: 20),
              origin: winterthur)),
          ['m6']);
    });

    test('leere Liste bleibt leer', () {
      expect(FilterLogic.apply(const [], const FeedFilter(query: 'x')), isEmpty);
    });
  });

  test('hasActiveFilter: wann «Filter zurücksetzen» angeboten wird', () {
    expect(FilterLogic.hasActiveFilter(const FeedFilter()), isFalse);
    expect(FilterLogic.hasActiveFilter(const FeedFilter(query: '   ')), isFalse);
    expect(FilterLogic.hasActiveFilter(const FeedFilter(query: 'Leica')), isTrue);
    expect(FilterLogic.hasActiveFilter(const FeedFilter(category: 'Uhren')), isTrue);
    expect(FilterLogic.hasActiveFilter(const FeedFilter(placeId: 3)), isFalse);
    expect(FilterLogic.hasActiveFilter(const FeedFilter(placeId: 3, radiusKm: 20)),
        isTrue);
  });
}
