import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/state/session_provider.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/presentation/app.dart';

// UC1 Schritt 5, TC01: Der Bestätigungslink in der Mail öffnet die App
// (Deep Link ch.refind.app://login-callback) und meldet an. Im Mock
// simuliert openConfirmationLink den Tipp auf den Link.

Future<MockRefindRepository> registerJan(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = MockRefindRepository(delay: Duration.zero);
  await tester.pumpWidget(RefindApp(repository: repo));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Registrieren'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('register-name')), 'Jan Roth');
  await tester.enterText(find.byKey(const Key('register-email')), 'jan.roth@beispiel.ch');
  await tester.enterText(find.byKey(const Key('register-password')), 'geheim123');
  await tester.enterText(find.byKey(const Key('register-repeat')), 'geheim123');
  await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
  await tester.pumpAndSettle();
  expect(find.text('Melde dich an.'), findsOneWidget);
  return repo;
}

void main() {
  testWidgets('TC01: Link aus der Mail meldet an, «Meine Gesuche» erscheint',
      (tester) async {
    final repo = await registerJan(tester);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.runAsync(() => repo.openConfirmationLink('jan.roth@beispiel.ch'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Meine Gesuche'), findsOneWidget);
  });

  testWidgets('abgelaufener Link: Hinweis bei «Anmelden», keine Anmeldung',
      (tester) async {
    final repo = await registerJan(tester);

    await tester.runAsync(
        () => repo.openConfirmationLink('jan.roth@beispiel.ch', valid: false));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(confirmationLinkFailedMessage), findsOneWidget);
  });

  testWidgets('angemeldet bleibt angemeldet, auch wenn ein Link kommt',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = MockRefindRepository(delay: Duration.zero);
    await tester.pumpWidget(RefindApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login-email')), 'anna@refind.test');
    await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pumpAndSettle();

    await tester.runAsync(() => repo.openConfirmationLink('anna@refind.test'));
    await tester.pumpAndSettle();
    expect(find.text('Meine Gesuche'), findsOneWidget);
  });
}
