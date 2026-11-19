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
}
