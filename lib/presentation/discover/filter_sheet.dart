import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/filter_logic.dart';
import '../../application/services/want_service.dart';
import '../../application/state/session_provider.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../wants/want_option_sheets.dart';
import '../widgets/choice_chips.dart';
import '../widgets/form_fields.dart';

/// Ergebnis von «Suchen und filtern»: die Filter und die gewählte
/// Ortschaft (für die Anzeige «Winterthur + 20 km» in «Entdecken»).
class FilterChoice {
  const FilterChoice(this.filter, this.place);

  final FeedFilter filter;

  /// Ortschaft für den Umkreis (F-08), oder null für die ganze Schweiz.
  final Place? place;
}

/// Suchen und filtern (UC5 Schritt 3 und 4, F-07, F-08, Abbildung 9).
///
/// Öffnet sich über «Entdecken», vorbelegt mit den aktuellen Filtern.
/// «Gesuche anzeigen» gibt die neuen Filter zurück, Wischen nach unten
/// schliesst das Sheet ohne Änderung (Rückgabe null).
Future<FilterChoice?> showFilterSheet(
  BuildContext context,
  FeedFilter current, {
  Place? currentPlace,
}) {
  return showModalBottomSheet<FilterChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FilterSheet(current: current, currentPlace: currentPlace),
  );
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.current, this.currentPlace});

  final FeedFilter current;
  final Place? currentPlace;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _query;
  late String? _category;

  /// F-08: Ortschaft und Umkreis. Ohne Ortschaft: ganze Schweiz.
  late Place? _place = widget.currentPlace;
  late int _radiusKm = widget.current.radiusKm ?? _profileRadius;

  int get _profileRadius =>
      context.read<SessionProvider>().user?.radiusKm ?? WantLimits.radiusOptions[1];

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.current.query ?? '')
      ..addListener(() => setState(() {}));
    _category = widget.current.category;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// F-07: Der Suchbegriff ist freiwillig. Länger als ein Titel ergibt keinen
  /// Sinn, darum höchstens so lang wie ein Titel (80 Zeichen).
  String? _validateQuery(String? value) {
    final length = (value ?? '').trim().length;
    if (length > FilterLogic.maxQueryLength) {
      return 'Der Suchbegriff darf höchstens ${FilterLogic.maxQueryLength} '
          'Zeichen lang sein (jetzt $length).';
    }
    return null;
  }

  /// UC5 Schritt 4: Ortschaft und Umkreis wählen. Das Sheet ist mit dem
  /// Wohnort und dem Suchradius aus dem Profil vorbelegt, solange noch
  /// keine Ortschaft gewählt ist.
  Future<void> _changeRegion() async {
    final user = context.read<SessionProvider>().user;
    var region = _place;
    if (region == null && user != null) {
      try {
        region = await context.read<WantService>().homePlace(user);
      } catch (_) {
        // Ohne Verbindung: Sheet ohne Vorbelegung
      }
    }
    if (!mounted) return;
    final choice = await showRegionSheet(
      context,
      region: region,
      radiusKm: _place == null ? _profileRadius : _radiusKm,
      profileRadiusKm: _profileRadius,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _place = choice.region;
      _radiusKm = choice.radiusKm;
    });
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    final query = _query.text.trim();
    final place = _place;
    Navigator.of(context).pop(FilterChoice(
      FeedFilter(
        query: query.isEmpty ? null : query,
        category: _category,
        placeId: place?.id,
        radiusKm: place == null ? null : _radiusKm,
      ),
      place,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final place = _place;
    return Padding(
      // Platz für die Tastatur
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Suchen und filtern', style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              const Text('NUR AKTIVE GESUCHE ANDERER', style: refindLabelStyle),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Suchbegriff',
                child: TextFormField(
                  key: const Key('filter-query'),
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  validator: _validateQuery,
                  onFieldSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    hintText: 'z.B. Leica',
                    helperText: 'Sucht im Titel der Gesuche.',
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : TextButton(
                            key: const Key('filter-query-clear'),
                            onPressed: _query.clear,
                            style: TextButton.styleFrom(
                              foregroundColor: RefindColors.muted,
                            ),
                            child: const Text('löschen'),
                          ),
                  ),
                ),
              ),
              LabeledField(
                label: 'Kategorie',
                child: ChoiceChips<String?>(
                  options: const [null, ...kategorien],
                  selected: _category,
                  labelOf: (c) => c ?? 'Alle',
                  onSelected: (c) => setState(() => _category = c),
                ),
              ),
              // F-08: Region und Umkreis (Abbildung 9: «Winterthur + 20 km ändern»)
              LabeledField(
                label: 'Region & Umkreis',
                child: Material(
                  color: RefindColors.field,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            place == null
                                ? 'Ganze Schweiz'
                                : '${place.name} + $_radiusKm km',
                            key: const Key('filter-region'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (place != null)
                          IconButton(
                            key: const Key('filter-region-clear'),
                            tooltip: 'Ganze Schweiz',
                            icon: const Icon(Icons.close, size: 18),
                            color: RefindColors.muted,
                            onPressed: () => setState(() => _place = null),
                          ),
                        TextButton(
                          key: const Key('filter-region-change'),
                          onPressed: _changeRegion,
                          style: TextButton.styleFrom(
                              foregroundColor: RefindColors.muted),
                          child: const Text('ändern'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('filter-apply'),
                onPressed: _apply,
                child: const Text('Gesuche anzeigen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
