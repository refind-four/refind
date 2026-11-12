import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';

/// Gesuch aufhängen in vier Schritten (UC3, Konzept 3.3):
/// Titel → Kategorie und Beschreibung → Details → Gesuch ist live.
class WantWizardScreen extends StatefulWidget {
  const WantWizardScreen({super.key});

  @override
  State<WantWizardScreen> createState() => _WantWizardScreenState();
}

class _WantWizardScreenState extends State<WantWizardScreen> {
  static const _steps = [
    'Titel',
    'Kategorie und Beschreibung',
    'Details',
    'Gesuch ist live',
  ];

  int _step = 0;

  bool get _isLast => _step == _steps.length - 1;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: _steps[_step],
      useCase: 'UC3 · SCHRITT ${_step + 1} VON ${_steps.length}',
      actions: [
        PlaceholderAction(
          _isLast ? 'Zu meinen Gesuchen' : 'Weiter',
          primary: true,
          () {
            if (_isLast) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step++);
            }
          },
        ),
      ],
    );
  }
}
