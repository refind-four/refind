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
