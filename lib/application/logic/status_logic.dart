import '../../model/model.dart';

/// Was der Käufer mit seinem Gesuch tun kann (UC4).
enum WantAction { pausieren, aktivieren, nochmalAufhaengen, bearbeiten }

/// StatusLogic (Konzept 4.2.2, Abbildung 13): erlaubte Statuswechsel von
/// Gesuch und Angebot nach Abbildung 2. Reine Fachlogik ohne Netz, darum mit
/// Unittests prüfbar (N-08). Die Datenbank prüft dieselben Regeln noch
/// einmal (supabase/11_gesuch_status.sql).
class StatusLogic {
  StatusLogic._();

  /// UC4 Schritt 6: «Nochmal aufhängen» setzt das Ablaufdatum auf 14 Tage
  /// ab heute.
  static const int republishDays = 14;

  /// Abbildung 2, Gesuch: alle erlaubten Übergänge (von, nach).
  static const Set<(WantStatus, WantStatus)> wantTransitions = {
    (WantStatus.aktiv, WantStatus.pausiert), // Pausieren
    (WantStatus.pausiert, WantStatus.aktiv), // Aktivieren
    (WantStatus.aktiv, WantStatus.abgelaufen), // Ablaufdatum erreicht
    (WantStatus.pausiert, WantStatus.abgelaufen), // Ablaufdatum erreicht
    (WantStatus.abgelaufen, WantStatus.aktiv), // Nochmal aufhängen
    (WantStatus.aktiv, WantStatus.erledigt), // Käufer bestätigt Abschluss
  };

  /// Abbildung 2, Angebot: alle erlaubten Übergänge (von, nach).
  static const Set<(OfferStatus, OfferStatus)> offerTransitions = {
    (OfferStatus.neu, OfferStatus.gesehen), // Käufer öffnet Liste
    (OfferStatus.gesehen, OfferStatus.angenommen), // Annehmen
    (OfferStatus.neu, OfferStatus.abgesagt), // anderes angenommen
    (OfferStatus.gesehen, OfferStatus.abgesagt), // anderes angenommen
  };

  static bool canChangeWant(WantStatus from, WantStatus to) =>
      wantTransitions.contains((from, to));

  static bool canChangeOffer(OfferStatus from, OfferStatus to) =>
      offerTransitions.contains((from, to));

  /// Ist das Gesuch abgelaufen? Entweder steht «abgelaufen» schon in der
  /// Datenbank, oder es ist aktiv oder pausiert und das Ablaufdatum ist
  /// erreicht. Mit angenommenem Angebot läuft es nicht mehr ab (Kapitel 2.1).
  static bool isExpired(Want want, DateTime now, {bool hasAcceptedOffer = false}) {
    if (want.status == WantStatus.abgelaufen) return true;
    if (hasAcceptedOffer) return false;
    final open = want.status == WantStatus.aktiv || want.status == WantStatus.pausiert;
    return open && !want.expiresAt.isAfter(now);
  }

  /// Status, wie ihn die App anzeigen soll: wie in der Datenbank, ausser
  /// das Ablaufdatum ist schon erreicht.
  static WantStatus effectiveStatus(Want want, DateTime now,
      {bool hasAcceptedOffer = false}) {
    return isExpired(want, now, hasAcceptedOffer: hasAcceptedOffer)
        ? WantStatus.abgelaufen
        : want.status;
  }

  /// Welche Knöpfe die Detailmaske zeigt (UC4 Schritt 3, 4 und 6).
  /// Mit angenommenem Angebot oder erledigt: nichts (UC4, Ausnahme).
  static Set<WantAction> allowedActions(
    Want want, {
    required DateTime now,
    required bool hasAcceptedOffer,
  }) {
    if (hasAcceptedOffer || want.status == WantStatus.erledigt) return const {};
    return switch (effectiveStatus(want, now)) {
      WantStatus.aktiv => const {WantAction.pausieren, WantAction.bearbeiten},
      WantStatus.pausiert => const {WantAction.aktivieren, WantAction.bearbeiten},
      WantStatus.abgelaufen => const {WantAction.nochmalAufhaengen},
      WantStatus.erledigt => const {},
    };
  }

  /// Neues Ablaufdatum beim «Nochmal aufhängen».
  static DateTime republishExpiry(DateTime now) =>
      now.add(const Duration(days: republishDays));

  /// Verbleibende Laufzeit eines offenen Gesuchs, sonst null
  /// (abgelaufen, erledigt oder mit angenommenem Angebot).
  static Duration? remaining(Want want, DateTime now, {bool hasAcceptedOffer = false}) {
    if (hasAcceptedOffer) return null;
    if (effectiveStatus(want, now) case WantStatus.aktiv || WantStatus.pausiert) {
      return want.expiresAt.difference(now);
    }
    return null;
  }
}
