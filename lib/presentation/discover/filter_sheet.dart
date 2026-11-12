import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Suchen und filtern (UC5) – Sheet über «Entdecken».
Future<void> showFilterSheet(BuildContext context) {
  return showPlaceholderSheet(
    context,
    title: 'Suchen und filtern',
    useCase: 'UC5',
    actions: [
      PlaceholderAction(
        'Gesuche anzeigen',
        primary: true,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
}
