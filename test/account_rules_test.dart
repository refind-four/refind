import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/account_rules.dart';

void main() {
  test('Mailadresse', () {
    expect(validateEmail('jan.roth@beispiel.ch'), isNull);
    expect(validateEmail(' jan.roth@beispiel.ch '), isNull);
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('jan.roth'), isNotNull);
    expect(validateEmail('jan@beispiel'), isNotNull);
  });

  test('Anzeigename', () {
    expect(validateDisplayName('Jan Roth'), isNull);
    expect(validateDisplayName('   '), isNotNull);
  });

  test('Neues Passwort braucht die Mindestlänge', () {
    expect(validateNewPassword('a' * minPasswordLength), isNull);
    expect(validateNewPassword('a' * (minPasswordLength - 1)), isNotNull);
  });

  test('Passwort wiederholen muss übereinstimmen', () {
    expect(validatePasswordRepeat('geheim123', 'geheim123'), isNull);
    expect(validatePasswordRepeat('geheim124', 'geheim123'),
        'Die Passwörter stimmen nicht überein.');
  });
}
