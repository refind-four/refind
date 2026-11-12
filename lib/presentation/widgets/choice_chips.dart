import 'package:flutter/material.dart';

import '../theme.dart';

/// Reihe von Auswahl-Chips wie «Uhren · Möbel · Velo» (Konzept 3.3).
/// Genau ein Wert ist gewählt (oder keiner). Mit [errorText] wird die
/// Auswahl als fehlend markiert (UC3: «markiert das fehlende Feld»).
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelOf,
    this.errorText,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String Function(T)? labelOf;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(labelOf?.call(option) ?? '$option'),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
                labelStyle: TextStyle(
                  color: option == selected ? Colors.white : RefindColors.ink,
                ),
                side: errorText != null
                    ? const BorderSide(color: RefindColors.accent)
                    : null,
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText!,
              style: const TextStyle(color: RefindColors.accent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
