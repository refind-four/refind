import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/offer_rules.dart';
import '../../application/logic/price_logic.dart';
import '../../application/services/offer_service.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../chat/chat_screen.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import '../widgets/offer_photo.dart';

/// Gesuch Detail · Angebote (UC4, UC7, F-10 bis F-12).
///
/// Zeigt alle Angebote zum Gesuch, sortiert nach Preis oder Datum. Angebote
/// über der Preisobergrenze sind gekennzeichnet (F-11). «Annehmen» ruft die
/// Datenbank-Funktion accept_offer auf und öffnet danach den Chat (F-12).
/// Bearbeiten und Pausieren (UC4) folgen.
class WantDetailScreen extends StatefulWidget {
  const WantDetailScreen({super.key, required this.summary});

  final WantSummary summary;

  @override
  State<WantDetailScreen> createState() => _WantDetailScreenState();
}

class _WantDetailScreenState extends State<WantDetailScreen> {
  // Kapitel 3.3 verlangt die Sortierung nach Preis, darum vorgewählt.
  OfferSort _sort = OfferSort.guenstigste;
  List<Offer> _offers = const [];
  bool _loading = true;
  String? _error;
  String? _acceptingId;
  bool _markedSeen = false;

  Want get _want => widget.summary.want;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<OfferService>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offers = await service.getOffers(_want.id, _sort);
      if (!mounted) return;
      setState(() => _offers = offers);
      // Einmal pro Besuch: neue Angebote als gesehen markieren. Die Liste
      // zeigt «NEU» trotzdem noch, bis man sie neu lädt.
      if (!_markedSeen && offers.any((o) => o.status == OfferStatus.neu)) {
        _markedSeen = true;
        await service.markOffersSeen(_want.id);
      }
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

  void _changeSort(OfferSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _load();
  }

  Future<void> _confirmAccept(Offer offer) async {
    final others = _offers
        .where((o) =>
            o.id != offer.id &&
            (o.status == OfferStatus.neu || o.status == OfferStatus.gesehen))
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Angebot annehmen?'),
        content: Text(
          '${offer.sellerName ?? 'Verkäufer'} · ${formatChf(offer.priceRappen)}\n\n'
          '${others == 0 ? '' : 'Die anderen $others offenen Angebote werden abgesagt. '}'
          'Danach öffnet sich der Chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annehmen'),
          ),
        ],
      ),
    );
    if (ok == true) await _accept(offer);
  }

  Future<void> _accept(Offer offer) async {
    setState(() => _acceptingId = offer.id);
    try {
      final thread = await context.read<OfferService>().acceptOffer(offer.id);
      if (!mounted) return;
      // F-12: Danach öffnet sich der Chat. «Zurück» führt zu «Meine Gesuche».
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(thread: thread)),
      );
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, () => _accept(offer));
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
        // Z.B. schon angenommen: Liste neu laden, damit sie stimmt.
        if (e.kind == RepositoryErrorKind.konflikt) _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(unexpectedErrorMessage)));
      }
    } finally {
      if (mounted) setState(() => _acceptingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_want.category.toUpperCase(), style: refindLabelStyle),
                  const SizedBox(height: 8),
                  Text(_want.title, style: textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'bis ${formatChf(_want.budgetMaxRappen)} · '
                    '${widget.summary.region.name}',
                    style: const TextStyle(color: RefindColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('ANGEBOTE (${_offers.length})', style: refindLabelStyle),
                      const Spacer(),
                      _SortChip('Günstigste', OfferSort.guenstigste, _sort, _changeSort),
                      const SizedBox(width: 8),
                      _SortChip('Neueste', OfferSort.neueste, _sort, _changeSort),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: RefreshIndicator(onRefresh: _load, child: _list())),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading && _offers.isEmpty) {
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
    if (_offers.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Text('Noch keine Angebote. Wir sagen dir Bescheid, sobald eines kommt.',
            style: TextStyle(color: RefindColors.muted)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _offers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final offer = _offers[i];
        return _OfferCard(
          offer: offer,
          budgetRappen: _want.budgetMaxRappen,
          canAccept: canAcceptOffer(_want, offer, _offers),
          busy: _acceptingId == offer.id,
          disabled: _acceptingId != null,
          onAccept: () => _confirmAccept(offer),
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(this.label, this.value, this.selected, this.onSelected);

  final String label;
  final OfferSort value;
  final OfferSort selected;
  final ValueChanged<OfferSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      labelStyle: TextStyle(color: isSelected ? Colors.white : RefindColors.ink),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.budgetRappen,
    required this.canAccept,
    required this.busy,
    required this.disabled,
    required this.onAccept,
  });

  final Offer offer;
  final int budgetRappen;
  final bool canAccept;
  final bool busy;
  final bool disabled;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final overBudget = overBudgetLabel(offer.priceRappen, budgetRappen);
    final faded = offer.status == OfferStatus.abgesagt;
    final statusColor = switch (offer.status) {
      OfferStatus.neu || OfferStatus.angenommen => RefindColors.accent,
      _ => RefindColors.muted,
    };

    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (offer.sellerName ?? 'Verkäufer').toUpperCase(),
                      style: refindLabelStyle,
                    ),
                  ),
                  Text(offerStatusLabel(offer.status),
                      style: refindLabelStyle.copyWith(color: statusColor)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatChf(offer.priceRappen),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 12),
                  if (overBudget != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        overBudget,
                        key: Key('over-budget-${offer.id}'),
                        style: refindLabelStyle.copyWith(color: RefindColors.accent),
                      ),
                    ),
                ],
              ),
              if (offer.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(offer.message),
              ],
              if (offer.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [for (final p in offer.photos) OfferPhoto(p.url)],
                ),
              ],
              if (canAccept) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: Key('accept-${offer.id}'),
                    style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                    onPressed: disabled ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Annehmen'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
