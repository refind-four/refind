import 'dart:io';

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

/// Höchstens so viele Einträge liefert der Feed auf einmal (Mengengerüst,
/// TC15: Liste mit 100 Einträgen).
const int maxFeedItems = 100;

/// Prüft die Filter für den Feed (UC5). Ein Suchbegriff, der länger ist
/// als ein Titel, kann nie passen und wird abgewiesen.
void checkFeedFilter(FeedFilter f) {
  if ((f.query?.trim().length ?? 0) > WantLimits.maxTitleLength) {
    _invalid('Der Suchbegriff ist zu lang.');
  }
  if (f.category != null && !kategorien.contains(f.category)) {
    _invalid('Unbekannte Kategorie.');
  }
  final radius = f.radiusKm;
  if (radius != null && (radius < 1 || radius > WantLimits.maxRadiusKm)) {
    _invalid('Der Umkreis liegt ausserhalb des erlaubten Bereichs.');
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

/// Prüft die Grösse der Fotos vor dem Hochladen (F-09). [sizes] sind die
/// Dateigrössen in Bytes. Der Bucket weist zu grosse Dateien zusätzlich ab.
void checkOfferPhotoSizes(Iterable<int> sizes) {
  if (sizes.any((s) => s > OfferLimits.maxPhotoBytes)) {
    _invalid(photoTooLargeMessage);
  }
}

/// Meldung für ein zu grosses Foto, in Maske, Mock und Supabase gleich.
const String photoTooLargeMessage =
    'Ein Foto ist zu gross (höchstens 5 MB). Bitte wähle ein kleineres.';

/// Grösse der Dateien in Bytes. Eine Datei, die es nicht gibt (z.B. in
/// Tests), zählt mit 0. Das Hochladen scheitert dann ohnehin.
List<int> fileSizes(List<File> files) =>
    [for (final f in files) f.existsSync() ? f.lengthSync() : 0];

/// Prüft eine Textnachricht im Chat (UC8, F-13). Dieselbe Grenze prüft die
/// CHECK-Regel message_body_check (supabase/14_chat.sql).
void checkMessageText(String text) {
  final length = text.trim().length;
  if (length == 0) _invalid('Die Nachricht ist leer.');
  if (length > MessageLimits.maxTextLength) {
    _invalid('Die Nachricht ist zu lang (höchstens '
        '${MessageLimits.maxTextLength} Zeichen).');
  }
}

/// Prüft den vereinbarten Preis beim Abschluss (UC8 Schritt 7). Gleiche
/// Grenze wie ein Angebot und die CHECK-Regel in supabase/14_chat.sql.
void checkDealPrice(int agreedPriceRappen) {
  if (agreedPriceRappen <= 0 || agreedPriceRappen > OfferLimits.maxPriceRappen) {
    _invalid('Der Preis liegt ausserhalb des erlaubten Bereichs.');
  }
}
