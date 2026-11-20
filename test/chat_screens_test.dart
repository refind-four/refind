import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:refind/application/services/auth_service.dart';
import 'package:refind/application/services/chat_service.dart';
import 'package:refind/application/state/session_provider.dart';
import 'package:refind/data/input_checks.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/app.dart';
import 'package:refind/presentation/chat/chat_screen.dart';
import 'package:refind/presentation/theme.dart';

// Chat (UC8, F-13) mit den Testdaten aus supabase/05_testdaten.sql:
// Anna (Käuferin) und Ben (Verkäufer) chatten zur Omega Speedmaster.
// Drei Chats sind abgeschlossen (Brompton, Makita, Miles Davis).

/// App starten, anmelden und den Bereich CHAT öffnen. 360 dp breit.
Future<MockRefindRepository> openChats(WidgetTester tester, String email,
    {double heightDp = 780}) async {
  tester.view.physicalSize = Size(1080, heightDp * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final repo = MockRefindRepository(delay: Duration.zero);
  await tester.pumpWidget(RefindApp(repository: repo));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
  await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('CHAT'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('Chatliste (UC8 Schritt 1)', () {
    testWidgets('Anna: Gegenüber, letzte Nachricht, Gesuch, Preis, Zeit',
        (tester) async {
      await openChats(tester, 'anna@refind.test');

      expect(find.text('Chats'), findsOneWidget);
      expect(
          find.text('Super. Könnte ich die Uhr am Samstag in Zürich anschauen?'),
          findsOneWidget);
      expect(find.text("OMEGA SPEEDMASTER · CHF 5'900"), findsOneWidget);
      expect(find.text('gestern'), findsOneWidget);
      // Gegenüber ist Ben (bei allen drei Chats von Anna)
      expect(find.text('Ben'), findsNWidgets(3));
      // Abgeschlossene Chats
      expect(find.text('Danke, das Velo fährt super!'), findsOneWidget);
      expect(find.text('Deal abgeschlossen'), findsOneWidget); // Miles Davis
      expect(find.textContaining('· ERLEDIGT'), findsNWidgets(2));
    });

    testWidgets('zuletzt aktive zuerst', (tester) async {
      await openChats(tester, 'anna@refind.test');
      final omega = tester.getTopLeft(find.text("OMEGA SPEEDMASTER · CHF 5'900")).dy;
      final miles = tester.getTopLeft(find.textContaining('MILES DAVIS')).dy;
      final brompton = tester.getTopLeft(find.textContaining('BROMPTON')).dy;
      expect(omega, lessThan(miles)); // vor 1 Tag, vor 30 Tagen
      expect(miles, lessThan(brompton)); // vor 50 Tagen
    });

    testWidgets('Cara sieht nur ihren eigenen Chat (F-19)', (tester) async {
      await openChats(tester, 'cara@refind.test');
      expect(find.textContaining('MAKITA'), findsOneWidget);
      expect(find.textContaining('OMEGA'), findsNothing);
      expect(find.text('Ben'), findsOneWidget);
    });
  });

  group('Chatmaske (UC8 Schritt 2 und 3)', () {
    Future<void> openOmega(WidgetTester tester) async {
      await tester.tap(find.text("OMEGA SPEEDMASTER · CHF 5'900"));
      await tester.pumpAndSettle();
    }

    testWidgets('Kopfzeile und Verlauf', (tester) async {
      await openChats(tester, 'anna@refind.test');
      await openOmega(tester);

      expect(tester.widget<Text>(find.byKey(const Key('chat-title'))).data, 'Ben');
      expect(find.text('OMEGA SPEEDMASTER'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('chat-price'))).data,
          "CHF 5'900");
      expect(find.text('ANGEBOT AUF «OMEGA SPEEDMASTER»'), findsOneWidget);
      expect(find.text('Hallo Ben, wann war der letzte Service?'), findsOneWidget);
      expect(find.text('Hallo Anna, im März 2025 bei Omega. Die Quittung ist dabei.'),
          findsOneWidget);

      // Eigene Nachricht rechts, die von Ben links
      final mine = tester.getTopRight(
          find.text('Hallo Ben, wann war der letzte Service?')).dx;
      final his = tester.getTopLeft(
          find.text('Hallo Anna, im März 2025 bei Omega. Die Quittung ist dabei.')).dx;
      expect(mine, greaterThan(300));
      expect(his, lessThan(60));
    });

    testWidgets('Text senden erscheint sofort, Feld wird leer', (tester) async {
      await openChats(tester, 'anna@refind.test');
      await openOmega(tester);

      // leer: Senden nicht aktiv
      expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
          isNull);
      await tester.enterText(find.byKey(const Key('chat-input')), '  Samstag 14 Uhr?  ');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();

      expect(find.text('Samstag 14 Uhr?'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('chat-input'))).controller!.text,
          isEmpty);
    });

    testWidgets('Länge: 1000 Zeichen gehen, 1001 nicht (Factsheet)', (tester) async {
      await openChats(tester, 'anna@refind.test');
      await openOmega(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), 'a' * 1001);
      await tester.pump();
      expect(find.text('Höchstens 1000 Zeichen (jetzt 1001).'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
          isNull);

      await tester.enterText(find.byKey(const Key('chat-input')), 'a' * 1000);
      await tester.pump();
      expect(find.textContaining('Höchstens 1000 Zeichen'), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed,
          isNotNull);
    });

    testWidgets('TC20: Nachricht von Ben erscheint ohne Neuladen (Echtzeit)',
        (tester) async {
      final repo = await openChats(tester, 'anna@refind.test');
      await openOmega(tester);
      expect(find.text('Ja, Samstag 14 Uhr passt.'), findsNothing);

      // Ben sendet (im Mock: kurz als Ben angemeldet, dann zurück zu Anna)
      await tester.runAsync(() async {
        await repo.signIn('ben@refind.test', 'refind123');
        await repo.sendText('thread-omega', 'Ja, Samstag 14 Uhr passt.');
        await repo.signIn('anna@refind.test', 'refind123');
      });
      await tester.pumpAndSettle();

      expect(find.text('Ja, Samstag 14 Uhr passt.'), findsOneWidget);
      // von Ben, also links
      expect(tester.getTopLeft(find.text('Ja, Samstag 14 Uhr passt.')).dx,
          lessThan(60));
    });

    testWidgets('UC8 Ausnahme: nicht gesendet, nochmal versuchen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = _FailOnceRepository();
      await tester.pumpWidget(RefindApp(repository: repo));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('login-email')), 'anna@refind.test');
      await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHAT'));
      await tester.pumpAndSettle();
      await openOmega(tester);

      await tester.enterText(find.byKey(const Key('chat-input')), 'Geht Samstag?');
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('Geht Samstag?'), findsOneWidget);
      expect(find.text('Nicht gesendet · Nochmal versuchen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Geht Samstag?'), findsOneWidget);
      expect(find.text('Nicht gesendet · Nochmal versuchen'), findsNothing);
    });
  });

  group('Fotos im Chat (UC8 Schritt 3)', () {
    late Directory dir;
    setUpAll(() => dir = Directory.systemTemp.createTempSync('refind_chat'));
    tearDownAll(() => dir.deleteSync(recursive: true));

    File fileOf(String name, int bytes) =>
        File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 0));

    /// Chat Omega als Anna, mit eigener Foto-Auswahl.
    Future<void> openWithPicker(WidgetTester tester, File photo) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = MockRefindRepository(delay: Duration.zero);
      await tester.runAsync(() => repo.signIn('anna@refind.test', 'refind123'));
      final chat = (await tester.runAsync(repo.getChats))!
          .firstWhere((c) => c.thread.id == 'thread-omega');
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider(create: (_) => ChatService(repo)),
          ChangeNotifierProvider(
              create: (_) => SessionProvider(AuthService(repo))..restore()),
        ],
        child: MaterialApp(
          theme: buildRefindTheme(),
          home: ChatScreen(summary: chat, pickPhoto: (_) async => photo),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> pickFromGallery(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('chat-add-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus der Galerie wählen'));
      await tester.pumpAndSettle();
    }

    testWidgets('Foto senden erscheint als eigene Nachricht', (tester) async {
      await openWithPicker(tester, fileOf('uhr.jpg', 100));
      expect(find.byType(Image), findsNothing);

      await pickFromGallery(tester);

      expect(find.byType(Image), findsOneWidget);
      // eigene Nachricht: rechts
      expect(tester.getTopRight(find.byType(Image)).dx, greaterThan(300));
    });

    testWidgets('zu grosses Foto: Meldung, nichts gesendet', (tester) async {
      await openWithPicker(tester, fileOf('gross.jpg', 5 * 1024 * 1024 + 1));
      await pickFromGallery(tester);

      expect(find.text(photoTooLargeMessage), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('Deal (UC8 Schritt 7, TC24)', () {
    Future<void> openChat(WidgetTester tester, String titleLine) async {
      await tester.tap(find.textContaining(titleLine));
      await tester.pumpAndSettle();
    }

    testWidgets('Verkäufer sieht keinen «Deal»', (tester) async {
      await openChats(tester, 'ben@refind.test');
      await openChat(tester, 'OMEGA SPEEDMASTER');
      expect(find.byKey(const Key('chat-deal')), findsNothing);
    });

    testWidgets('abgeschlossener Chat: kein «Deal», Hinweis mit Preis', (tester) async {
      await openChats(tester, 'anna@refind.test');
      await openChat(tester, 'BROMPTON');
      expect(find.byKey(const Key('chat-deal')), findsNothing);
      expect(find.text("DEAL ABGESCHLOSSEN · CHF 1'200"), findsOneWidget);
    });

    testWidgets('Käuferin schliesst ab: Preis prüfen, «Gefunden.», Gesuch erledigt',
        (tester) async {
      final repo = await openChats(tester, 'anna@refind.test');
      await openChat(tester, 'OMEGA SPEEDMASTER');

      await tester.tap(find.byKey(const Key('chat-deal')));
      await tester.pumpAndSettle();
      expect(find.text('Deal abschliessen'), findsOneWidget);
      // vorbelegt mit dem Angebotspreis
      expect(find.widgetWithText(TextFormField, "5'900"), findsOneWidget);

      // ungültiger Preis: Meldung, Sheet bleibt
      await tester.enterText(find.byKey(const Key('deal-price')), '0');
      await tester.tap(find.byKey(const Key('deal-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Der Preis muss grösser als CHF 0 sein.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('deal-price')), "5'800");
      await tester.tap(find.byKey(const Key('deal-confirm')));
      await tester.pumpAndSettle();

      // Deal bestätigt
      expect(find.text('Gefunden.'), findsOneWidget);
      expect(find.text("CHF 5'800"), findsOneWidget);
      expect(find.text('Omega Speedmaster'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deal-done')));
      await tester.pumpAndSettle();
      // zurück im Chat: abgeschlossen, kein «Deal» mehr
      expect(find.text("DEAL ABGESCHLOSSEN · CHF 5'800"), findsOneWidget);
      expect(find.byKey(const Key('chat-deal')), findsNothing);

      // Gesuch ist erledigt (F-05)
      final omega = (await tester.runAsync(repo.getMyWants))!
          .firstWhere((s) => s.want.id == 'want-omega');
      expect(omega.want.status.name, 'erledigt');
    });
  });
}

/// Mock, bei dem das erste Senden an der Verbindung scheitert.
class _FailOnceRepository extends MockRefindRepository {
  _FailOnceRepository() : super(delay: Duration.zero);

  bool _failed = false;

  @override
  Future<Message> sendText(String threadId, String text) async {
    if (!_failed) {
      _failed = true;
      throw const RepositoryException(
          RepositoryErrorKind.keineVerbindung, 'Keine Verbindung.');
    }
    return super.sendText(threadId, text);
  }
}
