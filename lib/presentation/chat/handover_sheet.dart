import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Übergabe festhalten (UC8) – Sheet über «Chat · Verhandlung».
Future<void> showHandoverSheet(BuildContext context) {
  return showPlaceholderSheet(
    context,
    title: 'Übergabe festhalten',
    useCase: 'UC8',
    actions: [
      PlaceholderAction(
        'Speichern',
        primary: true,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
}
