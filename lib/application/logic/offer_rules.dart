// Regeln für «Angebot senden» (UC6, F-09) und «Angebote ansehen und
// annehmen» (UC7, F-10 bis F-12). Reine Funktionen ohne Netz, deshalb mit
// Unittests prüfbar (N-08). Die Prüfungen liefern null, wenn die Eingabe
// stimmt, sonst die Meldung. Dieselben Regeln prüft das Repository noch
// einmal (data/input_checks.dart, checkOffer).

import '../../model/model.dart';
import 'price_logic.dart';

/// Liest einen Betrag in Franken, wie man ihn eintippt:
/// «1650», «1'650», «1650.50» oder «1650,5». Liefert Rappen oder null,
/// wenn die Eingabe kein Betrag ist. Whitelist: nur Ziffern, höchstens
/// ein Dezimalpunkt mit 1–2 Stellen.
int? parseChfToRappen(String? input) {
  final text = (input ?? '').replaceAll(RegExp(r"[\s']"), '').replaceAll(',', '.');
  final match = RegExp(r'^(\d{1,7})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;
  final francs = int.parse(match.group(1)!);
  final cents = int.parse((match.group(2) ?? '0').padRight(2, '0'));
  return francs * 100 + cents;
}

/// Pflichtfeld, grösser als 0 und höchstens [OfferLimits.maxPriceRappen].
String? validateOfferPrice(String? input) {
  if ((input ?? '').trim().isEmpty) return 'Bitte gib einen Preis ein.';
  final rappen = parseChfToRappen(input);
  if (rappen == null) return 'Bitte gib einen Betrag wie 1650 oder 1650.50 ein.';
  if (rappen <= 0) return 'Der Preis muss grösser als CHF 0 sein.';
  if (rappen > OfferLimits.maxPriceRappen) {
    return 'Der Preis darf höchstens ${formatChf(OfferLimits.maxPriceRappen)} betragen.';
  }
  return null;
}

/// Freiwillig, höchstens [OfferLimits.maxMessageLength] Zeichen.
String? validateOfferMessage(String? value) {
  final length = value?.trim().length ?? 0;
  if (length > OfferLimits.maxMessageLength) {
    return 'Die Nachricht darf höchstens ${OfferLimits.maxMessageLength} '
        'Zeichen lang sein (jetzt $length).';
  }
  return null;
}

/// F-09: Ob noch ein Foto dazukommen darf.
bool canAddPhoto(int photoCount) => photoCount < OfferLimits.maxPhotos;

/// F-11: Angebot liegt über der Preisobergrenze des Gesuchs.
bool isOverBudget(int priceRappen, int budgetRappen) => priceRappen > budgetRappen;

/// F-11: Text für die Kennzeichnung, z.B. «ÜBER BUDGET +CHF 100».
/// Leer, wenn das Angebot im Budget liegt.
String? overBudgetLabel(int priceRappen, int budgetRappen) {
  if (!isOverBudget(priceRappen, budgetRappen)) return null;
  return 'ÜBER BUDGET +${formatChf(priceRappen - budgetRappen)}';
}

/// F-12: Ob [offer] angenommen werden darf. Dieselben Bedingungen prüft
/// die Datenbank-Funktion accept_offer noch einmal.
bool canAcceptOffer(Want want, Offer offer, List<Offer> allOffers) {
  if (want.status != WantStatus.aktiv) return false;
  if (offer.status != OfferStatus.neu && offer.status != OfferStatus.gesehen) {
    return false;
  }
  return !allOffers.any((o) => o.status == OfferStatus.angenommen);
}

/// Text für den Status eines Angebots, wie auf der Gesuch-Karte.
String offerStatusLabel(OfferStatus status) => switch (status) {
      OfferStatus.neu => 'NEU',
      OfferStatus.gesehen => 'GESEHEN',
      OfferStatus.angenommen => 'ANGENOMMEN',
      OfferStatus.abgesagt => 'ABGESAGT',
    };
