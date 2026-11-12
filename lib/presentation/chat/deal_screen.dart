import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'rating_sheet.dart';

/// Deal bestätigt (UC8, UC9). Von hier geht es zur Bewertung.
class DealScreen extends StatelessWidget {
  const DealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Deal bestätigt',
      useCase: 'UC8, UC9',
      actions: [
        PlaceholderAction(
          'Bewertung abgeben',
          primary: true,
          () => showRatingSheet(context),
        ),
      ],
    );
  }
}
