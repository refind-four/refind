import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/presentation/app.dart';

// «Meine Gesuche» (UC4, F-04, Abbildung 8) mit den Testdaten von Anna
// (wie supabase/05_testdaten.sql).

/// Als Anna anmelden. Hoher Bildschirm (360 × 2600 dp), damit alle neun
/// Karten gleichzeitig sichtbar sind und die Reihenfolge prüfbar ist.
Future<void> openMyWants(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 7800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RefindApp(repository: MockRefindRepository(delay: Duration.zero)),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-email')), 'anna@refind.test');
  await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

/// Text des Status oben rechts in «Gesuch Detail».
String? detailStatus(WidgetTester tester) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(const Key('want-detail-status')), matching: find.byType(Text)))
    .data;

void main() {
  testWidgets('Status oder verbleibende Laufzeit auf jeder Karte', (tester) async {
    await openMyWants(tester);

    // Leica Q2: 7 Tage Laufzeit, vor 1 Tag erfasst. Angefangene Tage werden
    // aufgerundet, darum «6 TAGE» (5 Tage und knapp 24 Stunden).
    expect(find.text('● LIVE · 6 TAGE'), findsOneWidget);
    // Fujifilm: pausiert, 14 Tage, vor 6 Tagen erfasst
    expect(find.text('PAUSIERT · 8 TAGE'), findsOneWidget);
    // Omega: Bens Angebot ist angenommen, läuft nicht mehr ab
    expect(find.text('ANGEBOT ANGENOMMEN'), findsOneWidget);
    // Brompton und Miles Davis
    expect(find.text('ERLEDIGT'), findsNWidgets(2));
  });

  testWidgets('abgelaufen: eigene Karte unter den offenen, erledigte zuletzt',
      (tester) async {
    await openMyWants(tester);

    expect(find.text('Technics SL-1200 – abgelaufen.'), findsOneWidget);
    expect(find.byKey(const Key('republish-want-technics')), findsOneWidget);
    // Die abgelaufene Karte zeigt keinen normalen Titel
    expect(find.text('Technics SL-1200'), findsNothing);

    final expired = top(tester, 'Technics SL-1200 – abgelaufen.');
    expect(top(tester, 'Rolex Datejust 36'), lessThan(expired));
    expect(top(tester, 'Fujifilm X100V'), lessThan(expired));
    expect(top(tester, 'Brompton M6L'), greaterThan(expired));
  });

  testWidgets('TC11: «Nochmal aufhängen?» macht die Karte wieder live',
      (tester) async {
    await openMyWants(tester);

    await tester.tap(find.byKey(const Key('republish-want-technics')));
    await tester.pumpAndSettle();

    expect(find.text('Gesuch hängt wieder, 14 Tage lang.'), findsOneWidget);
    expect(find.text('Technics SL-1200 – abgelaufen.'), findsNothing);
    expect(find.text('Technics SL-1200'), findsOneWidget);
    // Neu aufgehängt: «14 TAGE», nicht «13 TAGE» (Handytest 20.11.2026)
    expect(find.text('● LIVE · 14 TAGE'), findsOneWidget);
    // Jetzt das neueste Gesuch, also zuoberst
    expect(top(tester, 'Technics SL-1200'), lessThan(top(tester, 'Leica Q2')));
  });

  testWidgets('Detail: Status oben rechts, nach Pausieren auch in der Liste',
      (tester) async {
    await openMyWants(tester);

    await tester.tap(find.text('Rolex Datejust 36'));
    await tester.pumpAndSettle();
    expect(detailStatus(tester), startsWith('● LIVE · '));

    await tester.tap(find.byKey(const Key('want-pause')));
    await tester.pumpAndSettle();
    expect(detailStatus(tester), startsWith('PAUSIERT · '));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PAUSIERT · 25 TAGE'), findsOneWidget);
  });
}
