import 'package:flutter/material.dart';

/// Fehlerfall für alle Anwendungsfälle (Konzept 2.3): Fehlt die Verbindung,
/// zeigt die App eine Meldung, behält die Eingaben und bietet an, die Aktion
/// zu wiederholen.
void showConnectionError(BuildContext context, VoidCallback retry) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: const Text('Keine Verbindung. Deine Eingaben sind noch da.'),
        action: SnackBarAction(label: 'Wiederholen', onPressed: retry),
      ),
    );
}
