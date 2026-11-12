import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/services/want_service.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/choice_chips.dart';
import '../widgets/form_fields.dart';

/// Ergebnis von «Region & Umkreis ändern».
class RegionChoice {
  const RegionChoice(this.region, this.radiusKm);

  final Place region;
  final int radiusKm;
}

/// Sheet zum Ändern von Region und Umkreis (UC3 Schritt 4, «ändern»).
///
/// [profileRadiusKm] ist der Suchradius aus dem Profil. Er steht immer in
/// der Auswahl, auch wenn vorher ein anderer Umkreis gewählt wurde.
Future<RegionChoice?> showRegionSheet(
  BuildContext context, {
  required Place? region,
  required int radiusKm,
  required int profileRadiusKm,
}) {
  return showModalBottomSheet<RegionChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RegionSheet(
      region: region,
      radiusKm: radiusKm,
      profileRadiusKm: profileRadiusKm,
    ),
  );
}

/// Sheet zum Ändern der Laufzeit (UC3 Schritt 4, «ändern»).
Future<int?> showDurationSheet(BuildContext context, {required int current}) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Wie lange sichtbar?',
                style: Theme.of(sheetContext).textTheme.headlineMedium),
            const SizedBox(height: 24),
            ChoiceChips<int>(
              options: WantLimits.durationOptions,
              selected: current,
              labelOf: (d) => '$d Tage',
              onSelected: (d) => Navigator.of(sheetContext).pop(d),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RegionSheet extends StatefulWidget {
  const _RegionSheet({
    required this.region,
    required this.radiusKm,
    required this.profileRadiusKm,
  });

  final Place? region;
  final int radiusKm;
  final int profileRadiusKm;

  @override
  State<_RegionSheet> createState() => _RegionSheetState();
}

class _RegionSheetState extends State<_RegionSheet> {
  final _query = TextEditingController();
  late Place? _region = widget.region;
  late int _radiusKm = widget.radiusKm;
  List<Place> _results = const [];
  String? _error;

  /// Umkreis-Auswahl: feste Werte plus der Wert aus dem Profil.
  List<int> get _radiusOptions => ({
        ...WantLimits.radiusOptions,
        widget.profileRadiusKm,
        widget.radiusKm,
      }.toList()
        ..sort());

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final results = await context.read<WantService>().searchPlaces(query);
      // Antwort gehört zu einer älteren Eingabe? Dann nicht anzeigen.
      if (!mounted || query != _query.text) return;
      setState(() {
        _results = results.take(8).toList();
        _error = null;
      });
    } on RepositoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Platz für die Tastatur lassen.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Region & Umkreis',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Ortschaft',
                child: TextField(
                  key: const Key('region-search'),
                  controller: _query,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: _region?.label ?? 'Ort oder PLZ suchen',
                    errorText: _error,
                  ),
                ),
              ),
              for (final place in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(place.label),
                  trailing: place.id == _region?.id
                      ? const Icon(Icons.check, color: RefindColors.ink)
                      : null,
                  onTap: () => setState(() {
                    _region = place;
                    _query.clear();
                    _results = const [];
                  }),
                ),
              if (_region != null && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text('Gewählt: ${_region!.label}'),
                ),
              LabeledField(
                label: 'Umkreis',
                child: ChoiceChips<int>(
                  options: _radiusOptions,
                  selected: _radiusKm,
                  labelOf: (km) => '$km km',
                  onSelected: (km) => setState(() => _radiusKm = km),
                ),
              ),
              FilledButton(
                onPressed: _region == null
                    ? null
                    : () => Navigator.of(context).pop(RegionChoice(_region!, _radiusKm)),
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
