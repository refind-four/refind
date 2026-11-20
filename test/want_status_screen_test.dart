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

  /// Detailmaske zum Gesuch [wantId] öffnen.
  Future<void> openDetail(WidgetTester tester, String wantId) async {
    tester.view.physicalSize = const Size(1080, 2340);
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
}
