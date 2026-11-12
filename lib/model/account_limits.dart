// Grenzwerte für Konten. Liegen im Paket model, weil Anwendungsschicht
// (Eingabeprüfung in der Maske) und Datenzugriffsschicht (Prüfung im
// Repository) dieselben Werte brauchen. So stehen sie nur an einer Stelle.

/// Mindestlänge des Passworts. Im Konzept nicht festgelegt, vom Team am
/// 12.11.2026 bestätigt (siehe ABWEICHUNGEN.md). Supabase muss beim
/// Einrichten auf denselben Wert gestellt werden (Authentication → Policies).
const int minPasswordLength = 8;

/// Höchstlänge des Passworts. bcrypt, mit dem der Anmeldedienst Passwörter
/// speichert (N-04), berücksichtigt nur die ersten 72 Bytes.
const int maxPasswordLength = 72;

/// Höchstlänge des Anzeigenamens.
const int maxDisplayNameLength = 40;
