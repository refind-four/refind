import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/presentation/app.dart';

/// Kleines Handy (360 × 780 dp), damit Überläufe auffallen.
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// App mit Mock starten, als Luca anmelden und «Entdecken» öffnen.
/// Luca sieht im Mock: Leica M6 (Mia, heute) und Omega Seamaster 300
/// (Anna, vor 2 Tagen). Nicht: Eames (pausiert), Pink Floyd (angenommen),
/// Rennvelo und Makita (eigene).
Future<void> openDiscover(WidgetTester tester) async {
  phoneSize(tester);
  await tester.pumpWidget(
    RefindApp(repository: MockRefindRepository(delay: Duration.zero)),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-email')), 'luca@refind.test');
  await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ENTDECKEN'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TC12: Feed zeigt nur aktive Gesuche anderer, neueste zuerst',
      (tester) async {
    await openDiscover(tester);

    expect(find.text('Wer sucht was?'), findsOneWidget);
    expect(find.text('Leica M6'), findsOneWidget);
    expect(find.text('Omega Seamaster 300'), findsOneWidget);
    expect(find.text('Eames Lounge Chair'), findsNothing);
    expect(find.textContaining('Pink Floyd'), findsNothing);
    expect(find.text('Rennvelo Rahmengrösse 56'), findsNothing);

    // neueste zuerst
    final leica = tester.getTopLeft(find.text('Leica M6')).dy;
    final omega = tester.getTopLeft(find.text('Omega Seamaster 300')).dy;
    expect(leica, lessThan(omega));

    // Name des Käufers, Zeit seit Erfassung, Preisobergrenze
    expect(find.text('Anna Keller'), findsOneWidget);
    expect(find.text('VOR 2 TAGEN'), findsOneWidget);
    expect(find.textContaining("bis CHF 2'500"), findsOneWidget);
    expect(find.text('Angebot senden'), findsNWidgets(2));
  });

  testWidgets('TC12: Kategorie Uhren, dann wieder Alle', (tester) async {
    await openDiscover(tester);

    await tester.tap(find.byKey(const Key('feed-chip-Uhren')));
    await tester.pumpAndSettle();
    expect(find.text('Omega Seamaster 300'), findsOneWidget);
    expect(find.text('Leica M6'), findsNothing);

    await tester.tap(find.byKey(const Key('feed-chip-Alle')));
    await tester.pumpAndSettle();
    expect(find.text('Leica M6'), findsOneWidget);
    expect(find.text('Omega Seamaster 300'), findsOneWidget);
  });

  testWidgets('UC5 Ausnahme: kein Treffer, Filter zurücksetzen', (tester) async {
    await openDiscover(tester);

    // Werkzeug: nur Lucas eigener Makita-Schrauber, der fehlt im Feed.
    // Der Chip steht ganz rechts in der Leiste: zuerst hinwischen.
    await tester.ensureVisible(find.byKey(const Key('feed-chip-Werkzeug')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-chip-Werkzeug')));
    await tester.pumpAndSettle();
    expect(find.text('Kein Gesuch passt zu deiner Suche.'), findsOneWidget);

    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('Leica M6'), findsOneWidget);
    expect(find.text('Omega Seamaster 300'), findsOneWidget);
  });

  testWidgets('«Angebot senden» öffnet das Sheet zum Gesuch', (tester) async {
    await openDiscover(tester);
    await tester.tap(find.byKey(const Key('feed-offer-want-5')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leica M6 · Mia Schmid'), findsOneWidget);
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

      expect(find.text('Leica M6'), findsOneWidget);
      expect(find.text('Omega Seamaster 300'), findsNothing);
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
      expect(find.text('Omega Seamaster 300'), findsOneWidget);
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
}
