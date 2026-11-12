import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Bewertung abgeben (UC9) – Sheet über «Deal bestätigt».
Future<void> showRatingSheet(BuildContext context) {
  return showPlaceholderSheet(
    context,
    title: 'Bewertung abgeben',
    useCase: 'UC9',
    actions: [
      PlaceholderAction(
        'Bewertung senden',
        primary: true,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
}
