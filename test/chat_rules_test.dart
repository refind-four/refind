import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/chat_rules.dart';
import 'package:refind/data/mock_refind_repository.dart';
import 'package:refind/data/repository_exception.dart';
import 'package:refind/model/model.dart';

void main() {
  group('Textnachricht (Maske)', () {
    test('leer oder nur Leerzeichen: nicht senden, aber kein Fehler', () {
      expect(canSendText(''), isFalse);
      expect(canSendText('   \n '), isFalse);
      expect(messageTextError('   '), isNull);
    });

    test('1000 Zeichen gehen, 1001 nicht', () {
      expect(MessageLimits.maxTextLength, 1000);
      expect(canSendText('a' * 1000), isTrue);
      expect(messageTextError('a' * 1000), isNull);
      expect(canSendText('a' * 1001), isFalse);
      expect(messageTextError('a' * 1001), 'Höchstens 1000 Zeichen (jetzt 1001).');
    });

    test('Leerzeichen am Rand zählen nicht', () {
      expect(canSendText('  ${'a' * 1000}  '), isTrue);
    });
  });

  group('Deal: nur der Käufer, nur offen (UC8 Schritt 7)', () {
    final open = ChatThread(
      id: 't',
      offerId: 'o',
      wantId: 'w',
      buyerId: 'anna',
      sellerId: 'ben',
      lastActivity: DateTime(2026, 11, 20),
    );
    final closed = open.copyWith(closedAt: DateTime(2026, 11, 20), agreedPriceRappen: 1);

    test('Käufer im offenen Chat: ja', () => expect(canCloseDeal(open, 'anna'), isTrue));
    test('Verkäufer: nein', () => expect(canCloseDeal(open, 'ben'), isFalse));
    test('abgeschlossen: nein', () => expect(canCloseDeal(closed, 'anna'), isFalse));
  });

  group('Repository (Mock wie Supabase)', () {
    late MockRefindRepository repo;

    setUp(() async {
      repo = MockRefindRepository(delay: Duration.zero);
      await repo.signIn('anna@refind.test', 'refind123');
    });

    Matcher invalid = throwsA(isA<RepositoryException>()
        .having((e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe));

    test('leer und zu lang werden abgewiesen', () async {
      await expectLater(repo.sendText('thread-omega', '   '), invalid);
      await expectLater(repo.sendText('thread-omega', 'a' * 1001), invalid);
    });

    test('1000 Zeichen werden gespeichert, Text ohne Leerzeichen am Rand',
        () async {
      final m = await repo.sendText('thread-omega', ' ${'a' * 1000} ');
      expect(m.body, 'a' * 1000);
      expect(m.kind, MessageKind.text);
      expect(m.senderId, 'user-anna');
    });

    test('TC27: fremder Chat: nichts lesen, nichts senden', () async {
      await repo.signOut();
      await repo.signIn('cara@refind.test', 'refind123');
      Matcher forbidden = throwsA(isA<RepositoryException>()
          .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt));
      await expectLater(repo.sendText('thread-omega', 'Hallo'), forbidden);
      expect(() => repo.watchMessages('thread-omega').first, throwsA(isA<RepositoryException>()));
    });
  });

  group('Deal im Repository (wie close_deal)', () {
    late MockRefindRepository repo;

    setUp(() async {
      repo = MockRefindRepository(delay: Duration.zero);
      await repo.signIn('anna@refind.test', 'refind123');
    });

    test('Käuferin: Chat abgeschlossen, Gesuch erledigt', () async {
      await repo.closeDeal('thread-omega', 580000);
      final chat = (await repo.getChats()).firstWhere((c) => c.thread.id == 'thread-omega');
      expect(chat.thread.isClosed, isTrue);
      expect(chat.thread.agreedPriceRappen, 580000);
      final omega = (await repo.getMyWants()).firstWhere((s) => s.want.id == 'want-omega');
      expect(omega.want.status, WantStatus.erledigt);
    });

    test('zweimal: konflikt mit verständlicher Meldung', () async {
      await repo.closeDeal('thread-omega', 580000);
      await expectLater(
        repo.closeDeal('thread-omega', 580000),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.konflikt)
            .having((e) => e.message, 'message', dealConflictMessage)),
      );
    });

    test('Verkäufer darf nicht', () async {
      await repo.signOut();
      await repo.signIn('ben@refind.test', 'refind123');
      await expectLater(
        repo.closeDeal('thread-omega', 580000),
        throwsA(isA<RepositoryException>()
            .having((e) => e.kind, 'kind', RepositoryErrorKind.nichtBerechtigt)),
      );
    });

    test('Preis 0 oder über CHF 10\'000: ungültig', () async {
      for (final price in [0, -100, 1000001]) {
        await expectLater(
          repo.closeDeal('thread-omega', price),
          throwsA(isA<RepositoryException>()
              .having((e) => e.kind, 'kind', RepositoryErrorKind.ungueltigeEingabe)),
        );
      }
    });
  });
}
