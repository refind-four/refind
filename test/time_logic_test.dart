import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/time_logic.dart';

void main() {
  final now = DateTime(2026, 11, 19, 12);
  String since(Duration d) => formatSince(now.subtract(d), now);

  test('unter einer Minute: gerade eben', () {
    expect(since(Duration.zero), 'gerade eben');
    expect(since(const Duration(seconds: 59)), 'gerade eben');
  });

  test('Uhr des Handys geht nach: Zeitpunkt in der Zukunft', () {
    expect(formatSince(now.add(const Duration(minutes: 5)), now), 'gerade eben');
  });

  test('Minuten', () {
    expect(since(const Duration(minutes: 1)), 'vor 1 Min');
    expect(since(const Duration(minutes: 20)), 'vor 20 Min');
    expect(since(const Duration(minutes: 59, seconds: 59)), 'vor 59 Min');
  });

  test('Stunden', () {
    expect(since(const Duration(hours: 1)), 'vor 1 Std');
    expect(since(const Duration(hours: 2, minutes: 40)), 'vor 2 Std');
    expect(since(const Duration(hours: 23, minutes: 59)), 'vor 23 Std');
  });

  test('Tage', () {
    expect(since(const Duration(days: 1)), 'vor 1 Tag');
    expect(since(const Duration(days: 1, hours: 23)), 'vor 1 Tag');
    expect(since(const Duration(days: 5)), 'vor 5 Tagen');
    expect(since(const Duration(days: 30)), 'vor 30 Tagen');
  });

  group('verbleibende Laufzeit', () {
    test('Tage', () {
      expect(formatRemaining(const Duration(days: 14)), '14 Tage');
      expect(formatRemaining(const Duration(days: 1)), '1 Tag');
    });

    test('angefangene Tage werden aufgerundet', () {
      // frisch aufgehängt: 14 Tage minus ein paar Sekunden
      expect(formatRemaining(const Duration(days: 13, hours: 23, minutes: 59, seconds: 59)),
          '14 Tage');
      expect(formatRemaining(const Duration(days: 13, hours: 23)), '14 Tage');
      expect(formatRemaining(const Duration(days: 2, hours: 23)), '3 Tage');
      expect(formatRemaining(const Duration(days: 1, hours: 23)), '2 Tage');
      expect(formatRemaining(const Duration(days: 1, seconds: 1)), '2 Tage');
    });

    test('Stunden und Minuten', () {
      expect(formatRemaining(const Duration(hours: 23, minutes: 59)), '23 Std');
      expect(formatRemaining(const Duration(hours: 1)), '1 Std');
      expect(formatRemaining(const Duration(minutes: 59)), '59 Min');
      expect(formatRemaining(const Duration(minutes: 1)), '1 Min');
    });

    test('unter einer Minute oder vorbei', () {
      expect(formatRemaining(const Duration(seconds: 59)), '< 1 Min');
      expect(formatRemaining(Duration.zero), '< 1 Min');
      expect(formatRemaining(const Duration(minutes: -5)), '< 1 Min');
    });
  });

  group('Zeit in der Chatliste', () {
    final now = DateTime(2026, 11, 20, 15, 30); // Freitag

    test('heute: Uhrzeit', () {
      expect(formatChatTime(DateTime(2026, 11, 20, 12, 4), now), '12:04');
      expect(formatChatTime(DateTime(2026, 11, 20, 0, 0), now), '00:00');
    });

    test('gestern, auch kurz vor Mitternacht', () {
      expect(formatChatTime(DateTime(2026, 11, 19, 23, 59), now), 'gestern');
      expect(formatChatTime(DateTime(2026, 11, 19, 0, 1), now), 'gestern');
    });

    test('letzte 6 Tage: Wochentag', () {
      expect(formatChatTime(DateTime(2026, 11, 18, 9), now), 'Mi');
      expect(formatChatTime(DateTime(2026, 11, 16, 9), now), 'Mo');
      expect(formatChatTime(DateTime(2026, 11, 14, 9), now), 'Sa');
    });

    test('älter: Datum', () {
      expect(formatChatTime(DateTime(2026, 11, 13, 9), now), '13.11.');
      expect(formatChatTime(DateTime(2026, 1, 2, 9), now), '02.01.');
    });

    test('Uhr des Handys geht nach: Zeit in der Zukunft gilt als heute', () {
      expect(formatChatTime(DateTime(2026, 11, 21, 8, 0), now), '08:00');
    });
  });

  test('Zeitumstellung (29.03.2026): Sonntag 23 Stunden lang', () {
    // Ohne UTC-Kalendertage wäre Samstag 23:00 hier «heute» oder falsch.
    final montag = DateTime(2026, 3, 30, 0, 30);
    expect(formatChatTime(DateTime(2026, 3, 29, 1, 0), montag), 'gestern');
    expect(formatChatTime(DateTime(2026, 3, 28, 23, 0), montag), 'Sa');
  });
}
