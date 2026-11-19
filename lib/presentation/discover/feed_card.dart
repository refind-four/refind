import 'package:flutter/material.dart';

import '../../application/logic/price_logic.dart';
import '../../application/logic/time_logic.dart';
import '../../model/model.dart';
import '../theme.dart';

/// Karte eines Gesuchs im Feed (Abbildung 9, UC5 Schritt 1): Name des
/// Käufers, Zeit seit der Erfassung, Titel, Beschreibung, Preisobergrenze
/// und «Angebot senden».
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.item,
    required this.now,
    required this.onOffer,
  });

  final FeedItem item;

  /// Bezugszeit für «vor 20 Min». Von aussen, damit Tests sie festlegen können.
  final DateTime now;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    final want = item.want;
    final name = item.buyerName.trim();
    return Material(
      key: Key('feed-card-${want.id}'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: RefindColors.background,
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: RefindColors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatSince(want.createdAt, now).toUpperCase(),
                  style: refindLabelStyle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(want.title, style: Theme.of(context).textTheme.titleLarge),
            if (want.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                want.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: RefindColors.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                // Preis und Region je in eigener Zeile. Die Region darf
                // umbrechen und wird nie abgeschnitten (z.B. «Muri bei Bern»).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bis ${formatChf(want.budgetMaxRappen)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.region.name,
                        key: Key('feed-region-${want.id}'),
                        style: const TextStyle(
                            fontSize: 13, color: RefindColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: Key('feed-offer-${want.id}'),
                  onPressed: onOffer,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RefindColors.accent,
                    side: const BorderSide(color: RefindColors.accent),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 40),
                  ),
                  child: const Text('Angebot senden'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
