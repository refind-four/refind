// Zeitangaben für die Anzeige (UC5 Schritt 1: «Zeit seit der Erfassung»).
// Reine Fachlogik ohne Netz, darum mit Unittests prüfbar (N-08).

/// Zeit seit [from], wie in Abbildung 9: «vor 20 Min», «vor 2 Std».
///
/// * unter 1 Minute (oder [from] liegt wegen einer falsch gehenden Uhr in
///   der Zukunft): «gerade eben»
/// * unter 1 Stunde: «vor N Min»
/// * unter 1 Tag: «vor N Std»
/// * sonst: «vor 1 Tag», «vor N Tagen»
String formatSince(DateTime from, DateTime now) {
  final diff = now.difference(from);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inHours < 1) return 'vor ${diff.inMinutes} Min';
  if (diff.inDays < 1) return 'vor ${diff.inHours} Std';
  return diff.inDays == 1 ? 'vor 1 Tag' : 'vor ${diff.inDays} Tagen';
}

/// Verbleibende Laufzeit eines Gesuchs (UC4, Abbildung 8: «2 TAGE»).
///
/// * ab 1 Tag: «1 Tag», «N Tage». Angefangene Tage werden aufgerundet:
///   Ein frisch aufgehängtes Gesuch mit 14 Tagen Laufzeit zeigt «14 Tage»,
///   auch wenn schon ein paar Sekunden vergangen sind (13 Tage 23 Std).
/// * unter 1 Tag, ab 1 Stunde: «N Std» (abgerundet)
/// * ab 1 Minute: «N Min» (abgerundet)
/// * darunter oder schon vorbei: «< 1 Min»
String formatRemaining(Duration remaining) {
  if (remaining.inDays >= 1) {
    final days = (remaining.inMicroseconds / Duration.microsecondsPerDay).ceil();
    return days == 1 ? '1 Tag' : '$days Tage';
  }
  if (remaining.inHours >= 1) return '${remaining.inHours} Std';
  if (remaining.inMinutes >= 1) return '${remaining.inMinutes} Min';
  return '< 1 Min';
}
