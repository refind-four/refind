import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'filter_sheet.dart';
import 'offer_compose_sheet.dart';

/// Entdecken (UC5). Startmaske des Bereichs ENTDECKEN.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Entdecken',
      useCase: 'UC5',
      isTabRoot: true,
      actions: [
        PlaceholderAction('Suchen und filtern', () => showFilterSheet(context)),
        PlaceholderAction(
          'Angebot senden',
          primary: true,
          () => showOfferComposeSheet(context),
        ),
      ],
    );
  }
}
