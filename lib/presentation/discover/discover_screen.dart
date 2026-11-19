import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/filter_logic.dart';
import '../../application/services/feed_service.dart';
import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import 'feed_card.dart';
import 'filter_sheet.dart';
import 'offer_compose_sheet.dart';

/// Entdecken (UC5, F-06, Abbildung 9). Startmaske des Bereichs ENTDECKEN.
///
/// Zeigt die aktiven Gesuche anderer Konten, das neueste zuerst. Die
/// Kategorie-Chips filtern sofort (UC5 Schritt 2), das Suchfeld öffnet
/// «Suchen und filtern» (UC5 Schritt 3).
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  FeedFilter _filter = const FeedFilter();
  List<FeedItem> _items = const [];
  bool _loading = true;
  String? _error;
  DateTime _loadedAt = DateTime.now();

  /// Zählt die Ladevorgänge. Wechselt man schnell die Kategorie, darf eine
  /// ältere, langsamere Antwort die neuere nicht überschreiben.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final viewerId = context.read<SessionProvider>().user?.id ?? '';
      final items = await context
          .read<FeedService>()
          .getFeed(_filter, viewerId: viewerId);
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loadedAt = DateTime.now();
      });
    } on RepositoryException catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e.kind == RepositoryErrorKind.keineVerbindung
          ? 'Keine Verbindung. Bitte prüfe dein Internet und versuche es nochmals.'
          : e.message);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _setCategory(String? category) {
    if (category == _filter.category) return;
    _filter = FeedFilter(
      query: _filter.query,
      category: category,
      placeId: _filter.placeId,
      radiusKm: _filter.radiusKm,
    );
    _load();
  }

  void _resetFilter() {
    _filter = const FeedFilter();
    _load();
  }

  /// UC5 Schritt 3 bis 5: Sheet öffnen, mit den neuen Filtern neu laden.
  Future<void> _openFilterSheet() async {
    final filter = await showFilterSheet(context, _filter);
    if (filter == null || !mounted) return;
    _filter = filter;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text('Entdecken',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SearchField(query: _filter.query, onTap: _openFilterSheet),
            ),
            const SizedBox(height: 12),
            _CategoryBar(selected: _filter.category, onSelected: _setCategory),
            const SizedBox(height: 8),
            SizedBox(
              height: 2,
              child: _loading && _items.isNotEmpty
                  ? const LinearProgressIndicator(color: RefindColors.ink)
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _list()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    // Erstes Laden: Ladezustand (UC5 Schritt 1)
    if (_loading && _items.isEmpty && _error == null) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator(key: Key('feed-loading'))),
      ]);
    }
    if (_error != null) {
      return _Message(
        text: _error!,
        color: RefindColors.accent,
        buttonLabel: 'Nochmals versuchen',
        onPressed: _load,
      );
    }
    if (_items.isEmpty) {
      // UC5 Ausnahme «Kein Gesuch passt»: Hinweis und Filter zurücksetzen
      return FilterLogic.hasActiveFilter(_filter)
          ? _Message(
              text: 'Kein Gesuch passt zu deiner Suche.',
              buttonLabel: 'Filter zurücksetzen',
              onPressed: _resetFilter,
            )
          : const _Message(text: 'Im Moment sucht niemand etwas.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FeedCard(
        item: _items[i],
        now: _loadedAt,
        onOffer: () => showOfferComposeSheet(context, _items[i]),
      ),
    );
  }
}

/// Suchfeld «Wer sucht was?». Keine Eingabe hier: ein Tipp öffnet das
/// Sheet «Suchen und filtern» (UC5 Schritt 3).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.query, required this.onTap});

  final String? query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = query?.trim() ?? '';
    return Material(
      color: RefindColors.field,
      shape: const StadiumBorder(),
      child: InkWell(
        key: const Key('feed-search'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: RefindColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text.isEmpty ? 'Wer sucht was?' : text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text.isEmpty ? RefindColors.muted : RefindColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leiste unter dem Suchfeld: «Alle» und die sechs Kategorien (F-06).
/// Lässt sich seitlich wischen, damit sie auch auf schmalen Handys passt.
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...kategorien];
    return SingleChildScrollView(
      key: const Key('feed-categories'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('feed-chip-${option ?? 'Alle'}'),
                label: Text((option ?? 'Alle').toUpperCase()),
                selected: option == selected,
                showCheckmark: false,
                onSelected: (_) => onSelected(option),
                labelStyle: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: option == selected ? Colors.white : RefindColors.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hinweis in der Mitte der Liste, wahlweise mit Knopf.
class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.color = RefindColors.muted,
    this.buttonLabel,
    this.onPressed,
  });

  final String text;
  final Color color;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // ListView, damit «nach unten ziehen» auch hier neu lädt.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: color)),
        if (buttonLabel != null) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: onPressed,
              child: Text(buttonLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
