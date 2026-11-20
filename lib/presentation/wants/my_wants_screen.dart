import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/price_logic.dart';
import '../../application/logic/status_logic.dart';
import '../../application/services/want_service.dart';
import '../../application/state/my_wants_provider.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import 'want_detail_screen.dart';
import 'want_status_label.dart';
import 'want_wizard_screen.dart';

/// Meine Gesuche (UC4, Konzept Abbildung 8). Startmaske des Bereichs GESUCHE.
/// Zeigt je Gesuch Kategorie, Status, Titel, Preisobergrenze, Region und die
/// neuen Angebote, dazu den Status oder die verbleibende Laufzeit.
/// Abgelaufene Gesuche erscheinen als eigene Karte mit «Nochmal aufhängen?».
class MyWantsScreen extends StatelessWidget {
  const MyWantsScreen({super.key});

  Future<void> _openWizard(BuildContext context) async {
    final provider = context.read<MyWantsProvider>();
    final created = await Navigator.of(context).push<Want>(
      MaterialPageRoute(builder: (_) => const WantWizardScreen()),
    );
    // UC3 Schritt 6: «Meine Gesuche» mit dem neuen Gesuch zeigen.
    if (created != null) await provider.load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MyWantsProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('refind', style: textTheme.titleLarge),
                  const SizedBox(height: 16),
                  const Text('Meine Gesuche',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.load,
                child: _list(context, provider),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: FilledButton(
                onPressed: () => _openWizard(context),
                child: const Text('+ Gesuch aufhängen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, MyWantsProvider provider) {
    // ListView auch für leere Zustände, damit «nach unten ziehen» geht.
    if (provider.loading && provider.wants.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    if (provider.error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(provider.error!, style: const TextStyle(color: RefindColors.accent)),
      ]);
    }
    if (provider.wants.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Text(
          'Du hast noch kein Gesuch. Häng eines auf, und Verkäufer melden sich bei dir.',
          style: TextStyle(color: RefindColors.muted),
        ),
      ]);
    }
    // Abbildung 8: offene Gesuche zuerst, abgelaufene als eigene Karte
    // darunter, erledigte zuletzt. Innerhalb davon neueste zuerst.
    final now = DateTime.now();
    int rank(WantSummary s) {
      if (s.want.status == WantStatus.erledigt) return 2;
      final expired = StatusLogic.isExpired(s.want, now,
          hasAcceptedOffer: s.hasAcceptedOffer);
      return expired ? 1 : 0;
    }

    final wants = [
      for (final r in [0, 1, 2]) ...provider.wants.where((s) => rank(s) == r),
    ];
    return ListView.separated(
      key: const Key('my-wants-list'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: wants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => rank(wants[i]) == 1
          ? _ExpiredCard(summary: wants[i])
          : _WantCard(summary: wants[i], now: now),
    );
  }
}

/// Detail öffnen und danach die Liste neu laden (Zähler, Status).
Future<void> _openDetail(BuildContext context, WantSummary summary) async {
  final provider = context.read<MyWantsProvider>();
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => WantDetailScreen(summary: summary)),
  );
  await provider.load();
}

class _WantCard extends StatelessWidget {
  const _WantCard({required this.summary, required this.now});

  final WantSummary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final want = summary.want;
    final offers = summary.newOfferCount > 0
        ? '${summary.newOfferCount} neue${summary.newOfferCount == 1 ? 's' : ''} '
            'Angebot${summary.newOfferCount == 1 ? '' : 'e'}'
        : '${summary.offerCount} Angebot${summary.offerCount == 1 ? '' : 'e'}';

    return Material(
      key: Key('want-card-${want.id}'),
      color: Colors.white,
      child: InkWell(
        onTap: () => _openDetail(context, summary),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Die Kategorie gibt nach, wenn der Platz nicht reicht
                  // (360 dp, «● LIVE · 14 TAGE»).
                  Expanded(
                    child: Text(want.category.toUpperCase(),
                        style: refindLabelStyle, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  // Status oder verbleibende Laufzeit (Abbildung 8)
                  WantStatusText(
                    want: want,
                    hasAcceptedOffer: summary.hasAcceptedOffer,
                    now: now,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(want.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'bis ${formatChf(want.budgetMaxRappen)} · ${summary.region.name}',
                style: const TextStyle(color: RefindColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                offers,
                style: TextStyle(
                  fontSize: 13,
                  color: summary.newOfferCount > 0
                      ? RefindColors.accent
                      : RefindColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eigene Karte für ein abgelaufenes Gesuch (Abbildung 8: «Rennvelo Gr. 56
/// – abgelaufen. Nochmal aufhängen?»). Der Link hängt es gleich wieder auf
/// (UC4 Schritt 6), ein Tipp auf die Karte öffnet das Detail.
class _ExpiredCard extends StatefulWidget {
  const _ExpiredCard({required this.summary});

  final WantSummary summary;

  @override
  State<_ExpiredCard> createState() => _ExpiredCardState();
}

class _ExpiredCardState extends State<_ExpiredCard> {
  bool _busy = false;

  Future<void> _republish() async {
    final provider = context.read<MyWantsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<WantService>().republishWant(widget.summary.want);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Gesuch hängt wieder, 14 Tage lang.')));
      await provider.load();
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, _republish);
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(unexpectedErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final want = widget.summary.want;
    return DecoratedBox(
      key: Key('want-expired-${want.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: RefindColors.muted.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => _openDetail(context, widget.summary),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          // Text und Link untereinander: Auf 360 dp passen Symbol, Titel
          // und «Nochmal aufhängen?» nicht in eine Zeile.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: RefindColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${want.title} – abgelaufen.',
                      style: const TextStyle(color: RefindColors.muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: Key('republish-${want.id}'),
                  onPressed: _busy ? null : _republish,
                  style: TextButton.styleFrom(foregroundColor: RefindColors.accent),
                  child: const Text('Nochmal aufhängen?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
