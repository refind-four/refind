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

    // Sobald das Feld stimmt, verschwindet die Meldung ohne neuen Klick.
    await tester.enterText(find.byKey(const Key('login-email')), 'anna@refind.test');
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib deine Mailadresse ein.'), findsNothing);
    expect(find.text('Bitte gib dein Passwort ein.'), findsOneWidget);
  });

  testWidgets('UC1: zu kurzes Passwort beim Registrieren', (tester) async {
    await startApp(tester);
    await tester.tap(find.text('Registrieren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register-name')), 'Jan Roth');
    await tester.enterText(find.byKey(const Key('register-email')), 'jan.roth@beispiel.ch');
    await tester.enterText(find.byKey(const Key('register-password')), 'kurz12');
    await tester.enterText(find.byKey(const Key('register-repeat')), 'kurz12');
    await tester.tap(find.widgetWithText(FilledButton, 'Konto anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Das Passwort muss mindestens 8 Zeichen lang sein (jetzt 6).'),
        findsOneWidget);
    expect(find.text('Konto anlegen.'), findsOneWidget); // Maske bleibt offen
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

  group('UC3: Gesuch erfassen', () {
    // Bildschirm in Handygrösse (360 x 780), wie ein Android-Gerät.
    void phoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> tapWeiter(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Weiter'));
      await tester.pumpAndSettle();
    }

    testWidgets('TC07/TC08: Pflichtfelder markiert, dann gespeichert',
        (tester) async {
      phoneSize(tester);
      await startApp(tester);
      await signIn(tester, 'anna@refind.test', 'refind123');
      await tester.tap(find.text('+ Gesuch aufhängen'));
      await tester.pumpAndSettle();

      // Schritt 1: Titel
      expect(find.text('Was suchst du?'), findsOneWidget);
      expect(find.text('SCHRITT 1 / 4'), findsOneWidget);
      await tapWeiter(tester);
      expect(find.text('Bitte gib einen Titel ein.'), findsOneWidget);
      expect(find.text('Was suchst du?'), findsOneWidget); // bleibt im Schritt

      await tester.enterText(find.byKey(const Key('want-title')), 'a' * 81);
      await tapWeiter(tester);
      expect(find.text('Der Titel darf höchstens 80 Zeichen lang sein (jetzt 81).'),
          findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('want-title')), 'Omega Seamaster 166.062');
      await tapWeiter(tester);

      // Schritt 2: Kategorie und Beschreibung
      expect(find.text('Worum geht es genau?'), findsOneWidget);
      await tapWeiter(tester);
      expect(find.text('Bitte wähle eine Kategorie.'), findsOneWidget);
      await tester.tap(find.text('Uhren'));
      await tester.enterText(
          find.byKey(const Key('want-description')), 'Gerne mit Box und Papieren.');
      await tapWeiter(tester);

      // Schritt 3: Details, Region aus dem Wohnort vorbelegt
      expect(find.text('Wie viel, welcher Zustand?'), findsOneWidget);
      expect(find.text('Bern + 20 km'), findsOneWidget);
      expect(find.text('14 Tage sichtbar'), findsOneWidget);
      expect(find.text('CHF 0'), findsWidgets);
      await tapWeiter(tester);
      expect(find.text('Bitte lege eine Preisobergrenze über CHF 0 fest.'),
          findsOneWidget);

      // Region und Umkreis über das Sheet ändern, dann wieder zurück
      await tester.tap(find.byKey(const Key('want-region')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('region-search')), 'Winter');
      await tester.pumpAndSettle();
      await tester.tap(find.text('8400 Winterthur'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50 km'));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Winterthur + 50 km'), findsOneWidget);

      await tester.tap(find.byKey(const Key('want-region')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('region-search')), '3000');
      await tester.pumpAndSettle();
      await tester.tap(find.text('3000 Bern'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20 km'));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Bern + 20 km'), findsOneWidget);

      // Laufzeit ändern
      await tester.tap(find.byKey(const Key('want-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 Tage'));
      await tester.pumpAndSettle();
      expect(find.text('30 Tage sichtbar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('want-budget'))); // Mitte = CHF 5'000
      await tester.pumpAndSettle();
      expect(find.text("CHF 5'000"), findsOneWidget);
      await tester.tap(find.text('Original'));
      await tapWeiter(tester);

      // Schritt 4: Gesuch ist live
      expect(find.text('Dein Gesuch hängt.'), findsOneWidget);
      await tester.tap(find.text('Zu meinen Gesuchen'));
      await tester.pumpAndSettle();

      // Meine Gesuche zeigt das neue Gesuch zuoberst
      expect(find.text('Omega Seamaster 166.062'), findsOneWidget);
      expect(find.text("bis CHF 5'000 · Bern"), findsOneWidget);
    });

    testWidgets('Vinyl: Zustände vom Team, langer Chip passt auf den Bildschirm',
        (tester) async {
      phoneSize(tester);
      await startApp(tester);
      await signIn(tester, 'anna@refind.test', 'refind123');
      await tester.tap(find.text('+ Gesuch aufhängen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('want-title')), 'Pink Floyd');
      await tapWeiter(tester);
      await tester.tap(find.text('Vinyl'));
      await tapWeiter(tester);

      // Ein Überlauf würde den Test hier mit einer Exception abbrechen.
      expect(find.text('Neuwertig'), findsOneWidget);
      expect(find.text('Gebraucht (leichtes Knistern ok)'), findsOneWidget);
      expect(find.text('Sehr gut'), findsNothing);
      await tester.tap(find.text('Gebraucht (leichtes Knistern ok)'));
      await tester.pumpAndSettle();
    });

    testWidgets('Abbrechen in Schritt 1 speichert nichts', (tester) async {
      phoneSize(tester);
      await startApp(tester);
      await signIn(tester, 'anna@refind.test', 'refind123');
      final cardsBefore = find.textContaining('bis CHF').evaluate().length;

      await tester.tap(find.text('+ Gesuch aufhängen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('want-title')), 'Wird verworfen');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('Meine Gesuche'), findsOneWidget);
      expect(find.text('Wird verworfen'), findsNothing);
      expect(find.textContaining('bis CHF').evaluate().length, cardsBefore);
    });
  });
}
