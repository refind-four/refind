// Eingaberegeln für «Anmelden» und «Registrieren» (UC1).
// Reine Funktionen ohne Netz, deshalb mit Unittests prüfbar (N-08).
// Jede Funktion liefert null, wenn die Eingabe stimmt, sonst die Meldung.
// Die Meldungen sagen, welches Feld betroffen ist und was zu tun ist.

import '../../model/account_limits.dart';

export '../../model/account_limits.dart';

final RegExp _mailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Bitte gib einen Anzeigenamen ein.';
  if (name.length > maxDisplayNameLength) {
    return 'Der Anzeigename darf höchstens $maxDisplayNameLength Zeichen lang sein.';
  }
  return null;
}

String? validateEmail(String? value) {
  final mail = value?.trim() ?? '';
  if (mail.isEmpty) return 'Bitte gib deine Mailadresse ein.';
  if (!_mailPattern.hasMatch(mail)) {
    return 'Bitte gib eine gültige Mailadresse ein, z.B. name@beispiel.ch.';
  }
  return null;
}

/// Beim Anmelden nur prüfen, ob etwas eingegeben ist. Die Länge wird hier
/// absichtlich nicht geprüft, damit bestehende Konten auch nach einer
/// Änderung der Regel noch funktionieren.
String? validatePasswordFilled(String? value) {
  if (value == null || value.isEmpty) return 'Bitte gib dein Passwort ein.';
  return null;
}

/// Beim Registrieren die Länge prüfen.
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Bitte wähle ein Passwort.';
  if (value.length < minPasswordLength) {
    return 'Das Passwort muss mindestens $minPasswordLength Zeichen lang sein '
        '(jetzt ${value.length}).';
  }
  if (value.length > maxPasswordLength) {
    return 'Das Passwort darf höchstens $maxPasswordLength Zeichen lang sein.';
  }
  return null;
}

/// UC1: Stimmen die beiden Passwörter nicht überein, wird das zweite Feld
/// markiert.
String? validatePasswordRepeat(String? repeat, String password) {
  if (repeat == null || repeat.isEmpty) return 'Bitte wiederhole dein Passwort.';
  if (repeat != password) return 'Die Passwörter stimmen nicht überein.';
  return null;
}
