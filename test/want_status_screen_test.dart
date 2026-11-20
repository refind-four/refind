import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:refind/application/services/offer_service.dart';
import 'package:refind/application/services/want_service.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/theme.dart';
import 'package:refind/presentation/wants/want_detail_screen.dart';

// UC4, F-05: Knöpfe in «Gesuch Detail» nach der StatusLogic.
// Testdaten wie supabase/05_testdaten.sql, angemeldet als Anna.

void main() {
  late MockRefindRepository repo;

  setUp(() => repo = MockRefindRepository(delay: Duration.zero));

  /// Detailmaske zum Gesuch [wantId] öffnen, auf einem Handy mit 360 dp
  /// Breite. Mit [tall] ist der Bildschirm hoch genug (1300 dp), damit alle
  /// Angebote gleichzeitig sichtbar sind und die Reihenfolge prüfbar ist.
  Future<void> openDetail(WidgetTester tester, String wantId,
      {bool tall = false}) async {
    tester.view.physicalSize = Size(1080, tall ? 3900 : 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => repo.signIn('anna@refind.test', 'refind123'));
    final summary = (await tester.runAsync(repo.getMyWants))!
        .firstWhere((s) => s.want.id == wantId);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider(create: (_) => OfferService(repo)),
        Provider(create: (_) => WantService(repo)),
      ],
      child: MaterialApp(
        theme: buildRefindTheme(),
        home: WantDetailScreen(summary: summary),
      ),
    ));
    await tester.pumpAndSettle();
  }

  const pause = Key('want-pause'),
      activate = Key('want-activate'),
      republish = Key('want-republish');

  testWidgets('TC10: aktiv → Pausieren → Aktivieren', (tester) async {
    await openDetail(tester, 'want-rolex');
    expect(find.byKey(pause), findsOneWidget);
    expect(find.byKey(activate), findsNothing);
    expect(find.byKey(republish), findsNothing);

    await tester.tap(find.byKey(pause));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gesuch pausiert.'), findsOneWidget);
    expect(find.byKey(activate), findsOneWidget);
    expect(find.byKey(pause), findsNothing);
    final rolex = (await tester.runAsync(repo.getMyWants))!
        .firstWhere((s) => s.want.id == 'want-rolex');
    expect(rolex.want.status, WantStatus.pausiert);

    await tester.tap(find.byKey(activate));
    await tester.pumpAndSettle();
    expect(find.text('Gesuch ist wieder aktiv.'), findsOneWidget);
    expect(find.byKey(pause), findsOneWidget);
  });

  testWidgets('pausiert (Fujifilm): nur Aktivieren', (tester) async {
    await openDetail(tester, 'want-fujifilm');
    expect(find.byKey(activate), findsOneWidget);
    expect(find.byKey(pause), findsNothing);
  });

  testWidgets('TC11: abgelaufen (Technics) → Nochmal aufhängen → aktiv',
      (tester) async {
    await openDetail(tester, 'want-technics');
    expect(find.byKey(republish), findsOneWidget);
    expect(find.byKey(pause), findsNothing);

    await tester.tap(find.byKey(republish));
    await tester.pumpAndSettle();
    expect(find.text('Gesuch hängt wieder, 14 Tage lang.'), findsOneWidget);
    expect(find.byKey(pause), findsOneWidget);
    expect(find.byKey(republish), findsNothing);
  });

  testWidgets('UC4 Ausnahme: angenommenes Angebot (Omega): keine Knöpfe',
      (tester) async {
    await openDetail(tester, 'want-omega');
    expect(find.byKey(pause), findsNothing);
    expect(find.byKey(activate), findsNothing);
    expect(find.byKey(republish), findsNothing);
  });

  testWidgets('erledigt (Brompton): keine Knöpfe', (tester) async {
    await openDetail(tester, 'want-brompton');
    expect(find.byKey(pause), findsNothing);
    expect(find.byKey(republish), findsNothing);
  });

  group('Angebotsliste (F-10, TC18)', () {
    /// Preise der Angebotskarten von oben nach unten.
    List<String?> prices(WidgetTester tester) => tester
        .widgetList<Text>(find.textContaining(RegExp(r"^CHF \d")))
        .map((t) => t.data)
        .toList();

    testWidgets('TC18: drei Sortierungen bei der Eames', (tester) async {
      await openDetail(tester, 'want-eames', tall: true);

      // Vorgewählt: Günstigste (UC7 Schritt 3)
      expect(prices(tester), ["CHF 1'720", "CHF 1'950", "CHF 2'100"]);
      // F-11: das Angebot über CHF 2'000 ist markiert
      expect(find.text('ÜBER BUDGET +CHF 100'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Teuerste'));
      await tester.pumpAndSettle();
      expect(prices(tester), ["CHF 2'100", "CHF 1'950", "CHF 1'720"]);
      expect(find.text('ÜBER BUDGET +CHF 100'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Neueste'));
      await tester.pumpAndSettle();
      // nach Eingang: Ben vor 5 Std, Cara vor 2 Tagen, Ben vor 3 Tagen
      expect(prices(tester), ["CHF 2'100", "CHF 1'950", "CHF 1'720"]);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Günstigste'));
      await tester.pumpAndSettle();
      expect(prices(tester), ["CHF 1'720", "CHF 1'950", "CHF 2'100"]);
    });

    testWidgets('Sortier-Chips erst ab zwei Angeboten', (tester) async {
      await openDetail(tester, 'want-leica-m6'); // ein Angebot von Cara
      expect(find.text('ANGEBOTE (1)'), findsOneWidget);
      expect(find.byKey(const Key('offer-sort')), findsNothing);
    });

    testWidgets('keine Angebote: Hinweis je nach Status', (tester) async {
      await openDetail(tester, 'want-rolex');
      expect(find.text('ANGEBOTE (0)'), findsOneWidget);
      expect(find.byKey(const Key('offer-sort')), findsNothing);
      expect(find.text('Noch keine Angebote. Wir sagen dir Bescheid, sobald eines kommt.'),
          findsOneWidget);

      // nach Pausieren passt der Hinweis sich an
      await tester.tap(find.byKey(pause));
      await tester.pumpAndSettle();
      expect(find.text('Dieses Gesuch ist pausiert. Aktiviere es, um Angebote zu bekommen.'),
          findsOneWidget);
    });

    testWidgets('abgelaufen (Technics): Hinweis statt «Wir sagen dir Bescheid»',
        (tester) async {
      await openDetail(tester, 'want-technics');
      expect(
          find.text('Dieses Gesuch ist abgelaufen. '
              'Häng es nochmal auf, um Angebote zu bekommen.'),
          findsOneWidget);
      expect(find.textContaining('Wir sagen dir Bescheid'), findsNothing);

      await tester.tap(find.byKey(republish));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wir sagen dir Bescheid'), findsOneWidget);
    });
  });
}
