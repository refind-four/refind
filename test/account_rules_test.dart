import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/account_rules.dart';

void main() {
  test('Mailadresse', () {
    expect(validateEmail('jan.roth@beispiel.ch'), isNull);
    expect(validateEmail(' jan.roth@beispiel.ch '), isNull);
    expect(validateEmail(''), 'Bitte gib deine Mailadresse ein.');
    expect(validateEmail('jan.roth'), contains('gültige Mailadresse'));
    expect(validateEmail('jan@beispiel'), isNotNull);
  });

  test('Anzeigename', () {
    expect(validateDisplayName('Jan Roth'), isNull);
    expect(validateDisplayName('   '), 'Bitte gib einen Anzeigenamen ein.');
    expect(validateDisplayName('a' * maxDisplayNameLength), isNull);
    expect(validateDisplayName('a' * (maxDisplayNameLength + 1)),
        contains('höchstens $maxDisplayNameLength Zeichen'));
  });

  test('Neues Passwort: mindestens 8 Zeichen', () {
    expect(minPasswordLength, 8);
    expect(validateNewPassword('a' * 8), isNull);
    expect(validateNewPassword('a' * 7),
        'Das Passwort muss mindestens 8 Zeichen lang sein (jetzt 7).');
    expect(validateNewPassword(''), 'Bitte wähle ein Passwort.');
  });

  test('Neues Passwort: höchstens 72 Zeichen (bcrypt)', () {
    expect(validateNewPassword('a' * maxPasswordLength), isNull);
    expect(validateNewPassword('a' * (maxPasswordLength + 1)),
        contains('höchstens $maxPasswordLength Zeichen'));
  });

  test('Passwort wiederholen', () {
    expect(validatePasswordRepeat('geheim123', 'geheim123'), isNull);
    expect(validatePasswordRepeat('', 'geheim123'), 'Bitte wiederhole dein Passwort.');
    expect(validatePasswordRepeat('geheim124', 'geheim123'),
        'Die Passwörter stimmen nicht überein.');
  });

  test('Anmelden prüft nur, ob ein Passwort eingegeben ist', () {
    expect(validatePasswordFilled('kurz'), isNull);
    expect(validatePasswordFilled(''), 'Bitte gib dein Passwort ein.');
  });
}
