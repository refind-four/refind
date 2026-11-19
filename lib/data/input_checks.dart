import '../model/model.dart';
import 'repository_exception.dart';

// Prüfungen in der Datenzugriffsschicht (Factsheet Inputvalidierung):
// dieselben Regeln wie in der Maske, noch einmal geprüft, weil man die App
// umgehen kann. Mock und Supabase benutzen beide diese Funktionen, damit sie
// sich gleich verhalten. Bei Supabase sollen später zusätzlich CHECK-Regeln
// in der Datenbank dieselben Grenzen durchsetzen (siehe ABWEICHUNGEN.md).

Never _invalid(String message) =>
    throw RepositoryException(RepositoryErrorKind.ungueltigeEingabe, message);

/// Prüft die Angaben beim Registrieren. Erwartet bereits getrimmte Werte.
void checkSignUp(String displayName, String email, String password) {
  if (displayName.isEmpty || displayName.length > maxDisplayNameLength) {
    _invalid('Der Anzeigename muss 1 bis $maxDisplayNameLength Zeichen lang sein.');
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    _invalid('Bitte gib eine gültige Mailadresse ein.');
  }
  if (password.length < minPasswordLength || password.length > maxPasswordLength) {
    _invalid('Das Passwort muss $minPasswordLength bis $maxPasswordLength '
        'Zeichen lang sein.');
  }
}

/// Prüft ein Gesuch vor dem Speichern. Ob die Region existiert, prüft jede
/// Umsetzung selbst (Mock: Liste, Supabase: Fremdschlüssel).
void checkWantDraft(WantDraft d) {
  final title = d.title.trim();
  if (title.isEmpty || title.length > WantLimits.maxTitleLength) {
    _invalid('Der Titel muss 1 bis ${WantLimits.maxTitleLength} Zeichen lang sein.');
  }
  if (!kategorien.contains(d.category)) _invalid('Unbekannte Kategorie.');
  if (d.description.trim().length > WantLimits.maxDescriptionLength) {
    _invalid('Die Beschreibung ist zu lang.');
  }
  if (d.budgetMaxRappen <= 0 || d.budgetMaxRappen > WantLimits.maxBudgetRappen) {
    _invalid('Die Preisobergrenze liegt ausserhalb des erlaubten Bereichs.');
  }
  if (!(zustaende[d.category] ?? const []).contains(d.condition)) {
    _invalid('Unbekannter Zustand.');
  }
  if (d.radiusKm < 1 || d.radiusKm > WantLimits.maxRadiusKm) {
    _invalid('Der Umkreis liegt ausserhalb des erlaubten Bereichs.');
  }
  if (!WantLimits.durationOptions.contains(d.durationDays)) {
    _invalid('Unbekannte Laufzeit.');
  }
}

/// Prüft ein Angebot vor dem Speichern (UC6, F-09).
void checkOffer(int priceRappen, String message, int photoCount) {
  if (priceRappen <= 0 || priceRappen > OfferLimits.maxPriceRappen) {
    _invalid('Der Preis liegt ausserhalb des erlaubten Bereichs.');
  }
  if (message.trim().length > OfferLimits.maxMessageLength) {
    _invalid('Die Nachricht ist zu lang.');
  }
  if (photoCount > OfferLimits.maxPhotos) {
    _invalid('Höchstens ${OfferLimits.maxPhotos} Fotos pro Angebot.');
  }
}
