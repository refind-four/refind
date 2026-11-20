/// Art eines Fehlers beim Datenzugriff (Konzept 4.3.2).
///
/// [mailNichtBestaetigt] ist eine Ergänzung zum Konzept: UC1 verlangt, dass
/// die App bei nicht bestätigter Mailadresse anbietet, die Mail erneut zu
/// senden. Dafür muss sie diesen Fall von «falsches Passwort» unterscheiden.
enum RepositoryErrorKind {
  keineVerbindung,
  nichtBerechtigt,
  ungueltigeEingabe,
  konflikt,
  mailNichtBestaetigt,
}

/// Wird von allen Methoden des [RefindRepository] bei einem Fehler geworfen.
class RepositoryException implements Exception {
  const RepositoryException(this.kind, this.message);

  final RepositoryErrorKind kind;

  /// Verständliche Meldung, die die App anzeigen kann.
  final String message;

  @override
  String toString() => 'RepositoryException(${kind.name}): $message';
}

/// Meldung, wenn ein Angebot nicht mehr angenommen werden kann (UC7):
/// Gesuch nicht mehr aktiv, schon ein anderes angenommen, oder das Angebot
/// ist abgesagt. Mock und Supabase zeigen denselben Text.
const String acceptConflictMessage =
    'Dieses Angebot lässt sich nicht mehr annehmen. Bitte lade die Angebote neu.';

/// Meldung, wenn ein Gesuch nicht pausiert, aktiviert oder nochmal
/// aufgehängt werden kann (UC4): Status hat sich geändert, Gesuch ist
/// abgelaufen, oder ein Angebot wurde angenommen. Mock und Supabase zeigen
/// denselben Text.
const String wantStatusConflictMessage =
    'Das geht bei diesem Gesuch gerade nicht. Bitte lade es neu.';
