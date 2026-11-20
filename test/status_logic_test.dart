import 'package:flutter_test/flutter_test.dart';
import 'package:refind/application/logic/status_logic.dart';
import 'package:refind/model/model.dart';

final now = DateTime(2026, 11, 20, 12);

Want want(WantStatus status, {Duration expiresIn = const Duration(days: 5)}) =>
    Want(
      id: 'w1',
      ownerId: 'anna',
      title: 'Rolex Datejust 36',
      category: 'Uhren',
      description: '',
      budgetMaxRappen: 700000,
      condition: 'Serviciert',
      regionId: 1,
      radiusKm: 50,
      createdAt: now.subtract(const Duration(days: 9)),
      expiresAt: now.add(expiresIn),
      status: status,
    );

void main() {
  group('Abbildung 2, Gesuch: erlaubte Übergänge', () {
    const a = WantStatus.aktiv,
        p = WantStatus.pausiert,
        ab = WantStatus.abgelaufen,
        e = WantStatus.erledigt;

    test('erlaubt', () {
      expect(StatusLogic.canChangeWant(a, p), isTrue, reason: 'Pausieren');
      expect(StatusLogic.canChangeWant(p, a), isTrue, reason: 'Aktivieren');
      expect(StatusLogic.canChangeWant(a, ab), isTrue);
      expect(StatusLogic.canChangeWant(p, ab), isTrue);
      expect(StatusLogic.canChangeWant(ab, a), isTrue, reason: 'Nochmal aufhängen');
      expect(StatusLogic.canChangeWant(a, e), isTrue, reason: 'Abschluss');
    });

    test('nicht erlaubt', () {
      expect(StatusLogic.canChangeWant(ab, p), isFalse);
      expect(StatusLogic.canChangeWant(p, e), isFalse);
      expect(StatusLogic.canChangeWant(ab, e), isFalse);
      for (final to in WantStatus.values) {
        expect(StatusLogic.canChangeWant(e, to), isFalse, reason: 'erledigt → $to');
      }
      for (final s in WantStatus.values) {
        expect(StatusLogic.canChangeWant(s, s), isFalse, reason: '$s → $s');
      }
    });

    test('genau sechs Übergänge', () {
      expect(StatusLogic.wantTransitions, hasLength(6));
    });
  });

  group('Abbildung 2, Angebot: erlaubte Übergänge', () {
    const n = OfferStatus.neu,
        g = OfferStatus.gesehen,
        an = OfferStatus.angenommen,
        ab = OfferStatus.abgesagt;

    test('erlaubt', () {
      expect(StatusLogic.canChangeOffer(n, g), isTrue);
      expect(StatusLogic.canChangeOffer(g, an), isTrue);
      expect(StatusLogic.canChangeOffer(n, ab), isTrue);
      expect(StatusLogic.canChangeOffer(g, ab), isTrue);
    });

    test('angenommen und abgesagt sind Endzustände', () {
      for (final to in OfferStatus.values) {
        expect(StatusLogic.canChangeOffer(an, to), isFalse);
        expect(StatusLogic.canChangeOffer(ab, to), isFalse);
      }
      expect(StatusLogic.canChangeOffer(g, n), isFalse);
    });
  });

  group('abgelaufen', () {
    test('aktiv und Ablaufdatum in der Zukunft: nicht abgelaufen', () {
      expect(StatusLogic.isExpired(want(WantStatus.aktiv), now), isFalse);
    });

    test('genau jetzt abgelaufen zählt schon (wie expires_at > now())', () {
      final w = want(WantStatus.aktiv, expiresIn: Duration.zero);
      expect(StatusLogic.isExpired(w, now), isTrue);
      expect(StatusLogic.effectiveStatus(w, now), WantStatus.abgelaufen);
      final eineSekundeVorher =
          want(WantStatus.aktiv, expiresIn: const Duration(seconds: 1));
      expect(StatusLogic.isExpired(eineSekundeVorher, now), isFalse);
    });

    test('auch pausierte Gesuche laufen ab', () {
      final w = want(WantStatus.pausiert, expiresIn: const Duration(days: -1));
      expect(StatusLogic.effectiveStatus(w, now), WantStatus.abgelaufen);
    });

    test('mit angenommenem Angebot läuft es nicht ab', () {
      final w = want(WantStatus.aktiv, expiresIn: const Duration(days: -1));
      expect(StatusLogic.isExpired(w, now, hasAcceptedOffer: true), isFalse);
    });

    test('Status abgelaufen aus der Datenbank bleibt abgelaufen', () {
      expect(StatusLogic.isExpired(want(WantStatus.abgelaufen), now), isTrue);
    });

    test('erledigt läuft nie ab', () {
      final w = want(WantStatus.erledigt, expiresIn: const Duration(days: -30));
      expect(StatusLogic.effectiveStatus(w, now), WantStatus.erledigt);
    });
  });

  group('Knöpfe in der Detailmaske (UC4)', () {
    Set<WantAction> actions(Want w, {bool accepted = false}) =>
        StatusLogic.allowedActions(w, now: now, hasAcceptedOffer: accepted);

    test('aktiv: Pausieren und Bearbeiten', () {
      expect(actions(want(WantStatus.aktiv)),
          {WantAction.pausieren, WantAction.bearbeiten});
    });

    test('pausiert: Aktivieren und Bearbeiten', () {
      expect(actions(want(WantStatus.pausiert)),
          {WantAction.aktivieren, WantAction.bearbeiten});
    });

    test('abgelaufen (Status oder Datum): nur Nochmal aufhängen', () {
      expect(actions(want(WantStatus.abgelaufen)), {WantAction.nochmalAufhaengen});
      expect(
          actions(want(WantStatus.aktiv, expiresIn: const Duration(hours: -1))),
          {WantAction.nochmalAufhaengen});
      expect(
          actions(want(WantStatus.pausiert, expiresIn: const Duration(hours: -1))),
          {WantAction.nochmalAufhaengen});
    });

    test('UC4 Ausnahme: angenommenes Angebot oder erledigt: nichts', () {
      expect(actions(want(WantStatus.aktiv), accepted: true), isEmpty);
      expect(actions(want(WantStatus.erledigt)), isEmpty);
    });
  });

  group('Laufzeit', () {
    test('Nochmal aufhängen: 14 Tage ab heute', () {
      expect(StatusLogic.republishExpiry(now), DateTime(2026, 12, 4, 12));
    });

    test('verbleibende Laufzeit nur für offene Gesuche', () {
      expect(StatusLogic.remaining(want(WantStatus.aktiv), now),
          const Duration(days: 5));
      expect(StatusLogic.remaining(want(WantStatus.pausiert), now),
          const Duration(days: 5));
      expect(StatusLogic.remaining(want(WantStatus.abgelaufen), now), isNull);
      expect(StatusLogic.remaining(want(WantStatus.erledigt), now), isNull);
      expect(
          StatusLogic.remaining(want(WantStatus.aktiv), now, hasAcceptedOffer: true),
          isNull);
      expect(
          StatusLogic.remaining(
              want(WantStatus.aktiv, expiresIn: const Duration(minutes: -1)), now),
          isNull);
    });
  });
}
