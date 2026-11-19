import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/price_logic.dart';
import '../../application/services/offer_service.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import 'filter_sheet.dart';
import 'offer_compose_sheet.dart';

/// Entdecken (UC5). Startmaske des Bereichs ENTDECKEN.
///
/// VORLÄUFIG: einfache Liste der Gesuche anderer Personen, damit sich
/// «Angebot senden» (UC6) testen lässt. Karten, Suchen und Filtern nach
/// Abbildung 4 folgen mit UC5 (siehe ABWEICHUNGEN.md).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  List<FeedItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<OfferService>().getFeed(const FeedFilter());
      if (mounted) setState(() => _items = items);
    } on RepositoryException catch (e) {
      if (mounted) {
        setState(() => _error = e.kind == RepositoryErrorKind.keineVerbindung
            ? 'Keine Verbindung. Ziehe die Liste nach unten, um es nochmals zu versuchen.'
            : e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text('Entdecken', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Suchen und filtern',
                    icon: const Icon(Icons.tune),
                    onPressed: () => showFilterSheet(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _list()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading && _items.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error!, style: const TextStyle(color: RefindColors.accent)),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Text('Im Moment sucht niemand etwas.',
            style: TextStyle(color: RefindColors.muted)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _FeedCard(item: _items[i]),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final want = item.want;
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(want.category.toUpperCase(), style: refindLabelStyle),
            const SizedBox(height: 8),
            Text(want.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'bis ${formatChf(want.budgetMaxRappen)} · ${item.region.name} · '
              '${item.buyerName}',
              style: const TextStyle(color: RefindColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showOfferComposeSheet(context, item),
                style: TextButton.styleFrom(foregroundColor: RefindColors.accent),
                child: const Text('Angebot senden →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
