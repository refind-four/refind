import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/presentation/app.dart';

// Startmaske «Profil» (UC2) mit den Testdaten aus 05_testdaten.sql.
// 360 dp breit, damit Überläufe auffallen.

Future<void> signInAndOpen(WidgetTester tester, String email, String tab) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RefindApp(repository: MockRefindRepository(delay: Duration.zero)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab));
  await tester.pumpAndSettle();
}

String? valueOf(WidgetTester tester, String key) => tester
    .widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
    .data;

void main() {
  testWidgets('Ben: Name, Wohnort mit Suchradius, Mailadresse', (tester) async {
    await signInAndOpen(tester, 'ben@refind.test', 'PROFIL');

    expect(find.text('Profil'), findsOneWidget);
    expect(valueOf(tester, 'profile-tab-name'), 'Ben');
    expect(valueOf(tester, 'profile-tab-home'), '8001 Zürich · Suchradius 30 km');
    expect(valueOf(tester, 'profile-tab-email'), 'ben@refind.test');
    expect(find.text('Profil bearbeiten'), findsOneWidget);
  });

  testWidgets('Cara ohne Wohnort', (tester) async {
    await signInAndOpen(tester, 'cara@refind.test', 'PROFIL');
    expect(valueOf(tester, 'profile-tab-home'), 'Noch kein Wohnort · Suchradius 20 km');
  });

  testWidgets('«Profil bearbeiten» öffnet die Maske mit Abmelden', (tester) async {
    await signInAndOpen(tester, 'ben@refind.test', 'PROFIL');
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Abmelden'), findsOneWidget);
    expect(find.text('Konto löschen'), findsOneWidget);
  });

  testWidgets('kein «PLATZHALTER» in den vier Bereichen und im Profil', (tester) async {
    await signInAndOpen(tester, 'anna@refind.test', 'GESUCHE');
    for (final tab in ['GESUCHE', 'ENTDECKEN', 'CHAT', 'PROFIL']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.textContaining('PLATZHALTER'), findsNothing, reason: tab);
    }
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PLATZHALTER'), findsNothing);
  });
}
