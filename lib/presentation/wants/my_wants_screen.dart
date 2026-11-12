import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'want_detail_screen.dart';
import 'want_wizard_screen.dart';

/// Meine Gesuche (UC4). Startmaske des Bereichs GESUCHE.
class MyWantsScreen extends StatelessWidget {
  const MyWantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Meine Gesuche',
      useCase: 'UC4',
      isTabRoot: true,
      actions: [
        PlaceholderAction(
          'Gesuch aufhängen',
          primary: true,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WantWizardScreen()),
          ),
        ),
        PlaceholderAction(
          'Gesuch öffnen',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WantDetailScreen()),
          ),
        ),
      ],
    );
  }
}
