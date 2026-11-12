import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/want_rules.dart';
import 'package:refind/model/model.dart';

void main() {
  group('Titel: Pflichtfeld, höchstens 80 Zeichen', () {
    test('gültig', () {
      expect(validateWantTitle('Velo 26"'), isNull); // Beispiel Factsheet
      expect(validateWantTitle('a' * 80), isNull);
      expect(validateWantTitle("O'Brien Uhr"), isNull); // nicht zu streng
    });
    test('ungültig', () {
      expect(validateWantTitle(''), 'Bitte gib einen Titel ein.');
      expect(validateWantTitle('   '), 'Bitte gib einen Titel ein.');
      expect(validateWantTitle('a' * 81),
          'Der Titel darf höchstens 80 Zeichen lang sein (jetzt 81).');
      expect(validateWantTitle('a' * 5000), isNotNull); // Beispiel Factsheet
    });
  });

  test('Kategorie: Pflichtfeld aus der Whitelist', () {
    expect(validateWantCategory('Uhren'), isNull);
    expect(validateWantCategory(null), 'Bitte wähle eine Kategorie.');
    expect(validateWantCategory('Autos'), isNotNull);
  });

  test('Budget: grösser als 0 und höchstens CHF 10\'000', () {
    expect(validateWantBudget(200000), isNull);
    expect(validateWantBudget(WantLimits.maxBudgetRappen), isNull);
    expect(validateWantBudget(0), 'Bitte lege eine Preisobergrenze über CHF 0 fest.');
    expect(validateWantBudget(-500), isNotNull); // Beispiel Factsheet: -5
    expect(validateWantBudget(WantLimits.maxBudgetRappen + 1),
        "Die Preisobergrenze darf höchstens CHF 10'000 betragen.");
  });

  test('Beschreibung: freiwillig, höchstens 1000 Zeichen', () {
    expect(validateWantDescription(''), isNull);
    expect(validateWantDescription('a' * 1000), isNull);
    expect(validateWantDescription('a' * 1001), isNotNull);
  });

  test('Zustand muss zur Kategorie passen', () {
    expect(validateWantCondition('Uhren', 'Serviciert'), isNull);
    expect(validateWantCondition('Velo', 'Serviciert'), isNotNull);
    expect(validateWantCondition('Uhren', null), isNotNull);
  });

  test('Jede Kategorie hat Zustände mit «Egal» als Vorauswahl', () {
    for (final k in kategorien) {
      expect(zustaende[k], isNotNull, reason: k);
      expect(zustaende[k]!.last, 'Egal', reason: k);
    }
  });

  test('Region ist Pflicht', () {
    expect(validateWantRegion(null), 'Bitte wähle eine Region.');
    expect(validateWantRegion(const Place(id: 1, plz: 3011, name: 'Bern', e: 0, n: 0)),
        isNull);
  });
}
