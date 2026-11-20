import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/model/model.dart';
import 'package:refind/presentation/app.dart';

// UC2, TC06, N-05: Konto löschen. Mock wie delete_own_account
// (supabase/15_konto_loeschen.sql), Testdaten wie 05_testdaten.sql.

void main() {
  group('Daten (Repository)', () {
    late MockRefindRepository repo;

    setUp(() => repo = MockRefindRepository(delay: Duration.zero));

    test('TC06: Cara ist weg, mit Gesuch, Angeboten, Chat und Bewertung', () async {
      await repo.signIn('cara@refind.test', 'refind123');
      await repo.deleteAccount();

      // Anmelden geht nicht mehr
      await expectLater(
        repo.signIn('cara@refind.test', 'refind123'),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );

      await repo.signIn('anna@refind.test', 'refind123');
      // Caras Angebote zu Annas Gesuchen sind weg
      final q2 = await repo.getOffers('want-leica-q2', OfferSort.neueste);
      expect(q2.map((o) => o.sellerId), ['user-ben']);
      final m6 = await repo.getOffers('want-leica-m6', OfferSort.neueste);
      expect(m6, isEmpty);

      // Caras Makita-Chat mit Ben und ihre Bewertung (4 Sterne) sind weg
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      final chats = await repo.getChats();
      expect(chats.map((c) => c.wantTitle), isNot(contains('Makita Akku-Bohrschrauber')));
      final stats = await repo.getProfileStats('user-ben');
      expect(stats.dealCount, 2); // Brompton und Miles Davis mit Anna
      expect(stats.averageStars, 4.0); // (5 + 3) / 2
    });

    test('Ben löscht: Omega hat kein angenommenes Angebot mehr, Anna verliert die Chats',
        () async {
      await repo.signIn('ben@refind.test', 'refind123');
      await repo.deleteAccount();

      await repo.signIn('anna@refind.test', 'refind123');
      expect(await repo.getChats(), isEmpty);
      final omega = await repo.getOffers('want-omega', OfferSort.neueste);
      expect(omega.map((o) => o.sellerId), everyElement('user-cara'));

      // Das Gesuch ist noch aktiv und erscheint für Cara wieder im Feed
      await repo.signOut();
      await repo.signIn('cara@refind.test', 'refind123');
      final feed = await repo.getFeed(const FeedFilter());
      expect(feed.map((i) => i.want.id), contains('want-omega'));
    });

    test('Anna löscht: ihre Gesuche fehlen im Feed, Bens Bewertungen von ihr sind weg',
        () async {
      await repo.signIn('anna@refind.test', 'refind123');
      await repo.deleteAccount();

      await repo.signIn('ben@refind.test', 'refind123');
      expect(await repo.getFeed(const FeedFilter()), isEmpty);
      final stats = await repo.getProfileStats('user-ben');
      expect(stats.dealCount, 1); // nur noch Makita mit Cara
      expect(stats.averageStars, 4.0);
    });

    test('ohne Anmeldung: nichtBerechtigt', () async {
      await expectLater(
        repo.deleteAccount(),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });
  });

  group('Maske «Profil bearbeiten»', () {
    Future<void> openDeleteDialog(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          RefindApp(repository: MockRefindRepository(delay: Duration.zero)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('login-email')), 'cara@refind.test');
      await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PROFIL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil bearbeiten'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Konto löschen'));
      await tester.tap(find.text('Konto löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Konto löschen?'), findsOneWidget);
    }

    FilledButton confirmButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byKey(const Key('delete-confirm')));

    testWidgets('erst mit «LÖSCHEN» aktiv, Abbrechen ändert nichts', (tester) async {
      await openDeleteDialog(tester);
      expect(confirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('delete-confirm-input')), 'löschen');
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNull); // genau gross geschrieben

      await tester.enterText(find.byKey(const Key('delete-confirm-input')), 'LÖSCHEN');
      await tester.pump();
      expect(confirmButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.text('Konto löschen?'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing); // noch in «Profil bearbeiten»
      expect(find.text('Profil bearbeiten'), findsOneWidget);
    });

    testWidgets('TC06: löschen → «Anmelden», Anmeldung geht nicht mehr', (tester) async {
      await openDeleteDialog(tester);
      await tester.enterText(find.byKey(const Key('delete-confirm-input')), 'LÖSCHEN');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Melde dich an.'), findsOneWidget);
      expect(find.text('Dein Konto und deine Daten sind gelöscht.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login-email')), 'cara@refind.test');
      await tester.enterText(find.byKey(const Key('login-password')), 'refind123');
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Mailadresse oder Passwort ist falsch.'), findsOneWidget);
    });

    testWidgets('zeigt Anzeigename und Mailadresse, kein Platzhalter', (tester) async {
      await openDeleteDialog(tester);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.text('Cara'), findsOneWidget);
      expect(find.text('cara@refind.test'), findsOneWidget);
      expect(find.textContaining('PLATZHALTER'), findsNothing);
      expect(find.text('Abmelden'), findsOneWidget);
      expect(find.text('Konto löschen'), findsOneWidget);
    });
  });
}
