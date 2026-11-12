import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/presentation/app.dart';

Future<void> startApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RefindApp(repository: MockRefindRepository(delay: Duration.zero)),
  );
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('UC1: Anmelden, Bereiche wechseln, Abmelden', (tester) async {
    await startApp(tester);

    // Start ohne Sitzung: Anmelden
    expect(find.text('Melde dich an.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await signIn(tester, 'anna@refind.test', 'refind123');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Meine Gesuche'), findsOneWidget);

    await tester.tap(find.text('ENTDECKEN'));
    await tester.pumpAndSettle();
    expect(find.text('Entdecken'), findsOneWidget);

    await tester.tap(find.text('CHAT'));
    await tester.pumpAndSettle();
    expect(find.text('Chats'), findsOneWidget);

    // Profil → Profil bearbeiten → Abmelden → zurück bei Anmelden
    await tester.tap(find.text('PROFIL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil bearbeiten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Melde dich an.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('UC1: falsches Passwort zeigt eine Fehlermeldung', (tester) async {
    await startApp(tester);
    await signIn(tester, 'anna@refind.test', 'falsch123');
    expect(find.text('Mailadresse oder Passwort ist falsch.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('UC1: leere Felder werden markiert', (tester) async {
    await startApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib deine Mailadresse ein.'), findsOneWidget);
    expect(find.text('Bitte gib dein Passwort ein.'), findsOneWidget);
  });

  testWidgets('UC1: registrieren, bestätigen, anmelden', (tester) async {
    await startApp(tester);
    await tester.tap(find.text('Registrieren'));
    await tester.pumpAndSettle();
    expect(find.text('Konto anlegen.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('register-name')), 'Jan Roth');
    await tester.enterText(find.byKey(const Key('register-email')), 'jan.roth@beispiel.ch');
    await tester.enterText(find.byKey(const Key('register-password')), 'geheim123');
    await tester.enterText(find.byKey(const Key('register-repeat')), 'geheim124');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();
    // Passwörter verschieden: zweites Feld markiert, Maske bleibt offen
    expect(find.text('Die Passwörter stimmen nicht überein.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('register-repeat')), 'geheim123');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();

    // Zurück bei Anmelden, Mailadresse übernommen, Hinweis zur Bestätigung
    expect(find.text('Melde dich an.'), findsOneWidget);
    expect(find.text('jan.roth@beispiel.ch'), findsOneWidget);
    expect(find.textContaining('Bitte bestätige deine Mailadresse'), findsOneWidget);

    // Vor der Bestätigung: verweigert, «Mail erneut senden» wird angeboten
    await signIn(tester, 'jan.roth@beispiel.ch', 'geheim123');
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Mail erneut senden'));
    await tester.pumpAndSettle();

    // Mock bestätigt beim erneuten Senden sofort → Anmeldung klappt
    await signIn(tester, 'jan.roth@beispiel.ch', 'geheim123');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('UC1: bestehende Mailadresse verrät kein Konto', (tester) async {
    await startApp(tester);
    await tester.tap(find.text('Registrieren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register-name')), 'Anna');
    await tester.enterText(find.byKey(const Key('register-email')), 'anna@refind.test');
    await tester.enterText(find.byKey(const Key('register-password')), 'geheim123');
    await tester.enterText(find.byKey(const Key('register-repeat')), 'geheim123');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Die Registrierung ist mit diesen Angaben nicht möglich.'),
        findsOneWidget);
  });

  testWidgets('Gesuch aufhängen hat vier Schritte', (tester) async {
    await startApp(tester);
    await signIn(tester, 'anna@refind.test', 'refind123');

    await tester.tap(find.text('Gesuch aufhängen'));
    await tester.pumpAndSettle();
    for (final title in ['Titel', 'Kategorie und Beschreibung', 'Details']) {
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Gesuch ist live'), findsOneWidget);
    await tester.tap(find.text('Zu meinen Gesuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Meine Gesuche'), findsOneWidget);
  });
}
