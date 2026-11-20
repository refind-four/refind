import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:flutter/rendering.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/app.dart';
import 'package:refind/presentation/discover/feed_card.dart';
import 'package:refind/presentation/theme.dart';

/// Kleines Handy (360 × 780 dp), damit Überläufe auffallen.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// App mit Mock starten, als Ben anmelden und «Entdecken» öffnen, wie der
/// Handytest mit supabase/05_testdaten.sql. Ben sieht: Leica Q2 (vor 1 Tag),
/// Leica M6 (vor 3 Tagen), Eames (vor 4 Tagen), Rolex (vor 5 Tagen).
/// Nicht: Omega (angenommen), Fujifilm (pausiert), Technics (abgelaufen),
/// Brompton, Makita, Miles Davis (erledigt).
Future<void> openDiscover(WidgetTester tester) async {
  phoneSize(tester);
  await tester.pumpWidget(
    RefindApp(repository: MockRefindRepository(delay: Duration.zero)),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-email')), 'ben@refind.test');
  await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ENTDECKEN'));
  await tester.pumpAndSettle();
}

/// Die Liste der Gesuche (nicht die Kategorie-Leiste) zum Scrollen.
final feedScrollable = find.descendant(
  of: find.byKey(const Key('feed-list')),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets('TC12: Feed zeigt nur aktive Gesuche anderer, neueste zuerst',
      (tester) async {
    await openDiscover(tester);

    expect(find.text('Wer sucht was?'), findsOneWidget);
    expect(find.text('Leica Q2'), findsOneWidget);
    expect(find.text('Leica M6'), findsOneWidget);
    // Die Rolex steht zuunterst: hinscrollen
    await tester.scrollUntilVisible(find.text('Rolex Datejust 36'), 300,
        scrollable: feedScrollable);
    expect(find.text('Eames Lounge Chair'), findsOneWidget);
    for (final hidden in [
      'Omega Speedmaster',
      'Fujifilm X100V',
      'Technics SL-1200',
      'Brompton M6L',
      'Makita Akku-Bohrschrauber',
      'Miles Davis – Kind of Blue',
    ]) {
      expect(find.text(hidden), findsNothing, reason: hidden);
    }

    // neueste zuerst
    final eames = tester.getTopLeft(find.text('Eames Lounge Chair')).dy;
    final rolex = tester.getTopLeft(find.text('Rolex Datejust 36')).dy;
    expect(eames, lessThan(rolex));
  });

  testWidgets('UC5 Schritt 1: Name, Zeit, Titel, Beschreibung, Preis',
      (tester) async {
    await openDiscover(tester);
    final q2 = tester.getTopLeft(find.text('Leica Q2')).dy;
    final m6 = tester.getTopLeft(find.text('Leica M6')).dy;
    expect(q2, lessThan(m6));

    expect(find.text('Anna'), findsWidgets);
    expect(find.text('VOR 1 TAG'), findsOneWidget);
    expect(find.text('VOR 3 TAGEN'), findsOneWidget);
    expect(find.text('Gehäuse, gerne mit 50 mm Summicron.'), findsOneWidget);
    expect(find.text("bis CHF 3'800"), findsOneWidget);
    expect(find.text('Winterthur'), findsOneWidget);
  });

  testWidgets('TC12: Kategorie Uhren, dann wieder Alle', (tester) async {
    await openDiscover(tester);

    await tester.tap(find.byKey(const Key('feed-chip-Uhren')));
    await tester.pumpAndSettle();
    expect(find.text('Rolex Datejust 36'), findsOneWidget);
    expect(find.text('Leica Q2'), findsNothing);
    expect(find.text('Leica M6'), findsNothing);

    await tester.tap(find.byKey(const Key('feed-chip-Alle')));
    await tester.pumpAndSettle();
    expect(find.text('Leica Q2'), findsOneWidget);
    expect(find.text('Leica M6'), findsOneWidget);
  });

  testWidgets('UC5 Ausnahme: kein Treffer, Filter zurücksetzen', (tester) async {
    await openDiscover(tester);

    // Werkzeug: nur Caras Makita-Schrauber, der ist erledigt.
    // Der Chip steht ganz rechts in der Leiste: zuerst hinwischen.
    await tester.ensureVisible(find.byKey(const Key('feed-chip-Werkzeug')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-chip-Werkzeug')));
    await tester.pumpAndSettle();
    expect(find.text('Kein Gesuch passt zu deiner Suche.'), findsOneWidget);

    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Leica Q2'), findsOneWidget);
    expect(find.text('Leica M6'), findsOneWidget);
  });

  testWidgets('«Angebot senden» öffnet das Sheet zum Gesuch', (tester) async {
    await openDiscover(tester);
    await tester.ensureVisible(find.byKey(const Key('feed-offer-want-leica-m6')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-offer-want-leica-m6')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leica M6 · Anna'), findsOneWidget);
  });

  group('Sheet «Suchen und filtern»', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('feed-search')));
      await tester.pumpAndSettle();
      expect(find.text('Suchen und filtern'), findsOneWidget);
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('filter-apply')));
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();
    }

    testWidgets('TC13: «leica» zeigt nur die Leica, löschen zeigt wieder alle',
        (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('filter-query')), 'leica');
      await apply(tester);

      expect(find.text('Leica Q2'), findsOneWidget);
      expect(find.text('Leica M6'), findsOneWidget);
      expect(find.text('Eames Lounge Chair'), findsNothing);
      expect(find.text('Rolex Datejust 36'), findsNothing);
      // Suchfeld zeigt den Begriff
      expect(find.text('leica'), findsOneWidget);

      // Sheet ist mit dem Begriff vorbelegt, «löschen» leert es
      await openSheet(tester);
      expect(find.widgetWithText(TextFormField, 'leica'), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-query-clear')));
      await tester.pump();
      await apply(tester);
      expect(find.text('Wer sucht was?'), findsOneWidget);
      expect(find.text('Leica M6'), findsOneWidget);
      // wieder alle: die Rolex zuunterst ist wieder da
      await tester.scrollUntilVisible(find.text('Rolex Datejust 36'), 300,
          scrollable: feedScrollable);
      expect(find.text('Rolex Datejust 36'), findsOneWidget);
    });

    testWidgets('Suchbegriff und Kategorie zusammen, kein Treffer',
        (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('filter-query')), 'Leica');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Uhren'));
      await tester.pump();
      await apply(tester);

      expect(find.text('Kein Gesuch passt zu deiner Suche.'), findsOneWidget);
      // Kategorie aus dem Sheet ist auch in der Leiste gewählt
      final chip = tester.widget<ChoiceChip>(find.byKey(const Key('feed-chip-Uhren')));
      expect(chip.selected, isTrue);

      await tester.tap(find.text('Filter zurücksetzen'));
      await tester.pumpAndSettle();
      expect(find.text('Wer sucht was?'), findsOneWidget);
      expect(find.text('Leica M6'), findsOneWidget);
    });

    testWidgets('Suchbegriff mit 81 Zeichen wird abgewiesen', (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('filter-query')), 'a' * 81);
      await apply(tester);

      expect(
        find.text('Der Suchbegriff darf höchstens 80 Zeichen lang sein (jetzt 81).'),
        findsOneWidget,
      );
      // Sheet bleibt offen, Feed unverändert
      expect(find.text('Suchen und filtern'), findsOneWidget);
    });
  });

  testWidgets('Region auf der Karte ist ganz lesbar, auch wenn sie lang ist',
      (tester) async {
    phoneSize(tester);
    final item = FeedItem(
      want: Want(
        id: 'w1',
        ownerId: 'anna',
        title: 'Leica Q2',
        category: 'Kameras',
        description: '',
        budgetMaxRappen: 380000,
        condition: 'Egal',
        regionId: 1,
        radiusKm: 30,
        createdAt: DateTime(2026, 11, 18),
        expiresAt: DateTime(2026, 11, 25),
        status: WantStatus.aktiv,
      ),
      buyerName: 'Anna',
      region: const Place(
          id: 1, plz: 8645, name: 'Rapperswil-Jona Kempraten-Lenggis', e: 0, n: 0),
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildRefindTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FeedCard(item: item, now: DateTime(2026, 11, 19), onOffer: () {}),
        ),
      ),
    ));

    expect(find.text("bis CHF 3'800"), findsOneWidget);
    final region = find.byKey(const Key('feed-region-w1'));
    expect(tester.widget<Text>(region).data, 'Rapperswil-Jona Kempraten-Lenggis');
    // nicht abgeschnitten: keine Auslassungspunkte, Text passt in die Karte
    expect(tester.widget<Text>(region).overflow, isNot(TextOverflow.ellipsis));
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: region, matching: find.byType(RichText)));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(find.text('Angebot senden'), findsOneWidget);
  });

  testWidgets('Navigation: ENTDECKEN hat ein Kompass-Icon wie die anderen',
      (tester) async {
    await openDiscover(tester);
    // aktiv: gefülltes Icon, wie bei den anderen Bereichen
    expect(find.byIcon(Icons.explore), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNothing);

    await tester.tap(find.text('GESUCHE'));
    await tester.pumpAndSettle();
    // inaktiv: Umriss
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.description), findsOneWidget);
  });

  group('Region und Umkreis (F-08, TC14)', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('feed-search')));
      await tester.pumpAndSettle();
    }

    Future<void> chooseRegion(WidgetTester tester, String search, String place,
        String radius) async {
      await tester.ensureVisible(find.byKey(const Key('filter-region-change')));
      await tester.tap(find.byKey(const Key('filter-region-change')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('region-search')), search);
      await tester.pumpAndSettle();
      await tester.tap(find.text(place));
      await tester.pumpAndSettle();
      await tester.tap(find.text(radius));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('filter-apply')));
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();
    }

    testWidgets('ohne Wahl: ganze Schweiz, «ändern» ist mit dem Wohnort vorbelegt',
        (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      expect(find.text('Ganze Schweiz'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('filter-region-change')));
      await tester.tap(find.byKey(const Key('filter-region-change')));
      await tester.pumpAndSettle();
      // Ben wohnt in Zürich, Suchradius 30 km (UC5 Schritt 4)
      expect(find.text('Gewählt: 8001 Zürich'), findsOneWidget);
    });

    testWidgets('TC14: Winterthur + 20 km zeigt die Leica M6, nicht die aus Bern',
        (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await chooseRegion(tester, 'Winter', '8400 Winterthur', '20 km');
      expect(find.text('Winterthur + 20 km'), findsOneWidget);
      await apply(tester);

      expect(find.text('Leica M6'), findsOneWidget);
      expect(find.text('Leica Q2'), findsNothing);
      expect(find.text('Eames Lounge Chair'), findsNothing);
      expect(find.text('Rolex Datejust 36'), findsNothing);
      // Suchfeld zeigt den Umkreis
      expect(find.text('Winterthur + 20 km'), findsOneWidget);
    });

    testWidgets('Umkreis mit Suchbegriff, dann «Ganze Schweiz» wieder', (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await tester.enterText(find.byKey(const Key('filter-query')), 'Leica');
      await chooseRegion(tester, '3000', '3000 Bern', '10 km');
      await apply(tester);
      expect(find.text('Leica · Bern + 10 km'), findsOneWidget);
      expect(find.text('Leica Q2'), findsOneWidget); // in Bern
      expect(find.text('Leica M6'), findsNothing); // in Winterthur

      await openSheet(tester);
      await tester.tap(find.byKey(const Key('filter-region-clear')));
      await tester.pump();
      expect(find.text('Ganze Schweiz'), findsOneWidget);
      await apply(tester);
      expect(find.text('Leica'), findsOneWidget);
      expect(find.text('Leica Q2'), findsOneWidget);
      expect(find.text('Leica M6'), findsOneWidget);
    });

    testWidgets('kein Treffer im Umkreis: «Filter zurücksetzen» entfernt auch den Ort',
        (tester) async {
      await openDiscover(tester);
      await openSheet(tester);
      await chooseRegion(tester, 'Gen', '1201 Genève', '10 km');
      await apply(tester);
      expect(find.text('Kein Gesuch passt zu deiner Suche.'), findsOneWidget);

      await tester.tap(find.text('Filter zurücksetzen'));
      await tester.pumpAndSettle();
      expect(find.text('Wer sucht was?'), findsOneWidget);
      expect(find.text('Leica Q2'), findsOneWidget);
    });
  });
}
