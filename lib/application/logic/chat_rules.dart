import '../../model/model.dart';

// Regeln für den Chat (UC8). Reine Fachlogik ohne Netz, darum mit
// Unittests prüfbar (N-08). Repository und Datenbank prüfen dieselbe
// Grenze noch einmal (input_checks.dart, supabase/14_chat.sql).

/// Kann der Text gesendet werden? Leer (oder nur Leerzeichen) nicht, und
/// nicht länger als [MessageLimits.maxTextLength] Zeichen.
bool canSendText(String text) {
  final length = text.trim().length;
  return length > 0 && length <= MessageLimits.maxTextLength;
}

/// Hinweis unter dem Eingabefeld, wenn der Text zu lang ist, sonst null.
/// Ein leeres Feld ist kein Fehler, «Senden» ist dann nur nicht aktiv.
String? messageTextError(String text) {
  final length = text.trim().length;
  if (length <= MessageLimits.maxTextLength) return null;
  return 'Höchstens ${MessageLimits.maxTextLength} Zeichen (jetzt $length).';
}

/// Darf diese Person «Deal» wählen? Nur der Käufer, und nur solange der
/// Chat nicht abgeschlossen ist (UC8 Schritt 7 und Ausnahme).
bool canCloseDeal(ChatThread thread, String myId) =>
    thread.buyerId == myId && !thread.isClosed;
