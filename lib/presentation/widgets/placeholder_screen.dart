import 'package:flutter/material.dart';

import '../theme.dart';

/// Ein Weg zu einer anderen Maske (Pfeil in Abbildung 4).
class PlaceholderAction {
  const PlaceholderAction(this.label, this.onPressed, {this.primary = false});

  final String label;
  final VoidCallback onPressed;

  /// Schwarzer Haupt-Button statt umrandetem Button.
  final bool primary;
}

/// Vorläufige Maske: zeigt Titel und Anwendungsfall und bietet die Wege
/// zu den nächsten Masken an. Wird Maske für Maske durch die echte
/// Umsetzung ersetzt.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.useCase,
    this.actions = const [],
    this.isTabRoot = false,
  });

  final String title;
  final String useCase;
  final List<PlaceholderAction> actions;

  /// Startmaske eines Bereichs der Navigationsleiste (ohne Zurück-Pfeil).
  final bool isTabRoot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isTabRoot ? null : AppBar(),
      body: SafeArea(
        child: _PlaceholderContent(title: title, useCase: useCase, actions: actions),
      ),
    );
  }
}

/// Öffnet ein Sheet, das sich von unten über die Maske schiebt (Kapitel 3.1).
Future<void> showPlaceholderSheet(
  BuildContext context, {
  required String title,
  required String useCase,
  List<PlaceholderAction> actions = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: _PlaceholderContent(
        title: title,
        useCase: useCase,
        actions: actions,
        shrinkWrap: true,
      ),
    ),
  );
}

class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent({
    required this.title,
    required this.useCase,
    required this.actions,
    this.shrinkWrap = false,
  });

  final String title;
  final String useCase;
  final List<PlaceholderAction> actions;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('PLATZHALTER · $useCase', style: refindLabelStyle),
        const SizedBox(height: 32),
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: action.primary
                ? FilledButton(onPressed: action.onPressed, child: Text(action.label))
                : OutlinedButton(onPressed: action.onPressed, child: Text(action.label)),
          ),
      ],
    );
  }
}
