import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/price_logic.dart';
import '../../application/state/my_wants_provider.dart';
import '../../model/model.dart';
import '../theme.dart';
import 'want_detail_screen.dart';
import 'want_wizard_screen.dart';

/// Meine Gesuche (UC4, Konzept Abbildung 8). Startmaske des Bereichs GESUCHE.
/// Zeigt je Gesuch Kategorie, Status, Titel, Preisobergrenze, Region und die
/// neuen Angebote. Pausieren, Bearbeiten und abgelaufene Karten folgen mit UC4.
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      itemCount: provider.wants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _WantCard(summary: provider.wants[i]),
    );
  }
}

class _WantCard extends StatelessWidget {
  const _WantCard({required this.summary});

  final WantSummary summary;

  (String, Color) get _status => switch (summary.want.status) {
        WantStatus.aktiv => ('● LIVE', RefindColors.accent),
        WantStatus.pausiert => ('PAUSIERT', RefindColors.muted),
        WantStatus.abgelaufen => ('ABGELAUFEN', RefindColors.muted),
        WantStatus.erledigt => ('ERLEDIGT', RefindColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    final want = summary.want;
    final (statusText, statusColor) = _status;
    final offers = summary.newOfferCount > 0
        ? '${summary.newOfferCount} neue${summary.newOfferCount == 1 ? 's' : ''} '
            'Angebot${summary.newOfferCount == 1 ? '' : 'e'}'
        : '${summary.offerCount} Angebot${summary.offerCount == 1 ? '' : 'e'}';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () async {
          final provider = context.read<MyWantsProvider>();
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WantDetailScreen(summary: summary)),
          );
          // Zähler «neue Angebote» und Status nachführen (gesehen, angenommen).
          await provider.load();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(want.category.toUpperCase(), style: refindLabelStyle),
                  const Spacer(),
                  Text(
                    statusText,
                    style: refindLabelStyle.copyWith(color: statusColor),
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
