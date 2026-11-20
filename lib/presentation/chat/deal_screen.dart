import 'package:flutter/material.dart';

import '../../application/logic/price_logic.dart';
import '../theme.dart';

/// Deal bestätigt (UC8 Schritt 7, Abbildung 11): fasst Preis, Gegenstand,
/// Übergabe und Gegenüber zusammen. «Bewerten» (UC9, F-17) folgt, darum
/// gibt es hier nur «Fertig».
class DealScreen extends StatelessWidget {
  const DealScreen({
    super.key,
    required this.wantTitle,
    required this.agreedPriceRappen,
    required this.otherUserName,
    this.handoverPlace,
  });

  final String wantTitle;
  final int agreedPriceRappen;
  final String otherUserName;

  /// Übergabeort, falls im Chat festgehalten (F-15, folgt).
  final String? handoverPlace;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sentiment_satisfied_alt_outlined,
                  size: 72, color: RefindColors.accent),
              const SizedBox(height: 24),
              Text('Gefunden.',
                  textAlign: TextAlign.center, style: textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Dein Gesuch ist erledigt. Details stehen im Chat mit $otherUserName.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RefindColors.muted),
              ),
              const SizedBox(height: 32),
              DecoratedBox(
                key: const Key('deal-summary'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: RefindColors.ink),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                              child: Text('ABSCHLUSS', style: refindLabelStyle)),
                          Text(formatChf(agreedPriceRappen),
                              style: const TextStyle(
                                  color: RefindColors.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(wantTitle, style: textTheme.titleLarge),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (handoverPlace ?? 'Übergabe im Chat abmachen').toUpperCase(),
                              style: refindLabelStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(otherUserName.toUpperCase(), style: refindLabelStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              OutlinedButton(
                key: const Key('deal-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fertig'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
