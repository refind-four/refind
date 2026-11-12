import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Angebot senden (UC6) – Sheet über «Entdecken».
Future<void> showOfferComposeSheet(BuildContext context) {
  return showPlaceholderSheet(
    context,
    title: 'Angebot senden',
    useCase: 'UC6',
    actions: [
      PlaceholderAction(
        'Angebot senden',
        primary: true,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
}
