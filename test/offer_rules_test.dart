import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/offer_rules.dart';
import 'package:refind/model/model.dart';

Want want({WantStatus status = WantStatus.aktiv, int budget = 200000}) => Want(
      id: 'w1',
      ownerId: 'anna',
      title: 'Eames Lounge Chair',
      category: 'Möbel',
      description: '',
      budgetMaxRappen: budget,
      condition: 'Gebraucht',
      regionId: 1,
      radiusKm: 50,
      createdAt: DateTime(2026, 11, 15),
      expiresAt: DateTime(2026, 11, 29),
      status: status,
    );

Offer offer(String id, int price, {OfferStatus status = OfferStatus.neu}) => Offer(
      id: id,
      wantId: 'w1',
      sellerId: 'ben',
      priceRappen: price,
      message: '',
      createdAt: DateTime(2026, 11, 16),
      status: status,
    );

void main() {
  group('UC6: Preis eingeben', () {
    test('Franken, Apostroph, Rappen mit Punkt oder Komma', () {
      expect(parseChfToRappen('1650'), 165000);
      expect(parseChfToRappen("1'650"), 165000);
      expect(parseChfToRappen('1650.50'), 165050);
      expect(parseChfToRappen('1650,5'), 165050);
      expect(parseChfToRappen(' 20 '), 2000);
    });

    test('kein Betrag → null', () {
      for (final bad in ['', 'abc', '-5', '1.234', '12.', '1e3', '12345678']) {
        expect(parseChfToRappen(bad), isNull, reason: bad);
      }
    });

    test('Prüfung: leer, kein Betrag, 0, zu hoch, gültig', () {
      expect(validateOfferPrice(''), 'Bitte gib einen Preis ein.');
      expect(validateOfferPrice('viel'), contains('Betrag'));
      expect(validateOfferPrice('0'), contains('grösser als CHF 0'));
      expect(validateOfferPrice('10000.05'), contains("CHF 10'000"));
      expect(validateOfferPrice('10000'), isNull);
      expect(validateOfferPrice('1720'), isNull);
    });
  });

  group('UC6: Nachricht und Fotos', () {
    test('Nachricht freiwillig, höchstens 500 Zeichen', () {
      expect(validateOfferMessage(''), isNull);
      expect(validateOfferMessage('a' * OfferLimits.maxMessageLength), isNull);
      expect(validateOfferMessage('a' * (OfferLimits.maxMessageLength + 1)),
          contains('höchstens 500'));
    });

    test('F-09: höchstens drei Fotos', () {
      expect(canAddPhoto(0), isTrue);
      expect(canAddPhoto(2), isTrue);
      expect(canAddPhoto(3), isFalse);
    });
  });

  group('UC7 / F-11: über Budget', () {
    test('genau das Budget ist nicht darüber', () {
      expect(isOverBudget(200000, 200000), isFalse);
      expect(overBudgetLabel(200000, 200000), isNull);
    });

    test('Eames: Ben CHF 2\'100 bei Budget CHF 2\'000', () {
      expect(isOverBudget(210000, 200000), isTrue);
      expect(overBudgetLabel(210000, 200000), 'ÜBER BUDGET +CHF 100');
    });
  });

  group('UC7 / F-12: annehmen erlaubt?', () {
    test('neu und gesehen ja, abgesagt nein', () {
      final all = [offer('a', 1), offer('b', 2, status: OfferStatus.gesehen)];
      expect(canAcceptOffer(want(), all[0], all), isTrue);
      expect(canAcceptOffer(want(), all[1], all), isTrue);
      expect(
          canAcceptOffer(want(), offer('c', 3, status: OfferStatus.abgesagt), all),
          isFalse);
    });

    test('nicht mehr, sobald eines angenommen ist', () {
      final all = [offer('a', 1), offer('b', 2, status: OfferStatus.angenommen)];
      expect(canAcceptOffer(want(), all[0], all), isFalse);
    });

    test('nicht bei pausiertem oder abgelaufenem Gesuch', () {
      final all = [offer('a', 1)];
      expect(canAcceptOffer(want(status: WantStatus.pausiert), all[0], all), isFalse);
      expect(canAcceptOffer(want(status: WantStatus.abgelaufen), all[0], all), isFalse);
    });
  });
}
