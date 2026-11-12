// Eingaberegeln für «Gesuch erfassen» (UC3, F-03, TC08).
// Reine Funktionen ohne Netz, deshalb mit Unittests prüfbar (N-08).
// Jede Funktion liefert null, wenn die Eingabe stimmt, sonst die Meldung.
//
// Nach dem Factsheet Inputvalidierung (M183): Whitelist statt Blacklist.
// Kategorie und Zustand müssen aus den festen Listen stammen, Zahlen aus
// einem festen Bereich. Dieselben Regeln prüft das Repository noch einmal.

import '../../model/model.dart';
import 'price_logic.dart';

/// Pflichtfeld, höchstens 80 Zeichen.
String? validateWantTitle(String? value) {
  final title = value?.trim() ?? '';
  if (title.isEmpty) return 'Bitte gib einen Titel ein.';
  if (title.length > WantLimits.maxTitleLength) {
    return 'Der Titel darf höchstens ${WantLimits.maxTitleLength} Zeichen lang '
        'sein (jetzt ${title.length}).';
  }
  return null;
}

/// Pflichtfeld aus der Liste der sechs Kategorien.
String? validateWantCategory(String? value) {
  if (value == null) return 'Bitte wähle eine Kategorie.';
  if (!kategorien.contains(value)) return 'Bitte wähle eine Kategorie aus der Liste.';
  return null;
}

/// Freiwillig, aber nicht beliebig lang.
String? validateWantDescription(String? value) {
  final length = value?.trim().length ?? 0;
  if (length > WantLimits.maxDescriptionLength) {
    return 'Die Beschreibung darf höchstens ${WantLimits.maxDescriptionLength} '
        'Zeichen lang sein (jetzt $length).';
  }
  return null;
}

/// Pflichtfeld, grösser als 0 und höchstens die obere Grenze.
String? validateWantBudget(int rappen) {
  if (rappen <= 0) return 'Bitte lege eine Preisobergrenze über CHF 0 fest.';
  if (rappen > WantLimits.maxBudgetRappen) {
    return 'Die Preisobergrenze darf höchstens '
        '${formatChf(WantLimits.maxBudgetRappen)} betragen.';
  }
  return null;
}

/// Zustand muss zur gewählten Kategorie passen.
String? validateWantCondition(String? category, String? condition) {
  final allowed = zustaende[category] ?? const <String>[];
  if (condition == null || !allowed.contains(condition)) {
    return 'Bitte wähle einen Zustand.';
  }
  return null;
}

/// Region ist vorbelegt mit dem Wohnort, fehlt aber bei neuen Konten.
String? validateWantRegion(Place? region) {
  if (region == null) return 'Bitte wähle eine Region.';
  return null;
}
