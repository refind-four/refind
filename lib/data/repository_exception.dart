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
