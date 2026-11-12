// Eingaberegeln für «Anmelden» und «Registrieren» (UC1).
// Reine Funktionen ohne Netz, deshalb mit Unittests prüfbar (N-08).
// Jede Funktion liefert null, wenn die Eingabe stimmt, sonst die Meldung.

/// Mindestlänge des Passworts. Im Konzept nicht festgelegt, Annahme des
/// Teams. Supabase muss beim Einrichten (KW 47) auf denselben Wert.
const int minPasswordLength = 8;

final RegExp _mailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateDisplayName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Bitte gib einen Anzeigenamen ein.';
  if (value.trim().length > 40) return 'Höchstens 40 Zeichen.';
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Bitte gib deine Mailadresse ein.';
  if (!_mailPattern.hasMatch(value.trim())) return 'Diese Mailadresse ist ungültig.';
  return null;
}

/// Beim Anmelden nur prüfen, ob etwas eingegeben ist.
String? validatePasswordFilled(String? value) {
  if (value == null || value.isEmpty) return 'Bitte gib dein Passwort ein.';
  return null;
}

/// Beim Registrieren zusätzlich die Mindestlänge prüfen.
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Bitte wähle ein Passwort.';
  if (value.length < minPasswordLength) {
    return 'Mindestens $minPasswordLength Zeichen.';
  }
  return null;
}

/// UC1: Stimmen die beiden Passwörter nicht überein, wird das zweite Feld
/// markiert.
String? validatePasswordRepeat(String? repeat, String password) {
  if (repeat != password) return 'Die Passwörter stimmen nicht überein.';
  return null;
}
