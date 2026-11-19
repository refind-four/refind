import 'package:flutter/material.dart';

import '../../application/logic/filter_logic.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/choice_chips.dart';
import '../widgets/form_fields.dart';

/// Suchen und filtern (UC5 Schritt 3 und 4, F-07, Abbildung 9).
///
/// Öffnet sich über «Entdecken», vorbelegt mit den aktuellen Filtern.
/// «Gesuche anzeigen» gibt die neuen Filter zurück, Wischen nach unten
/// schliesst das Sheet ohne Änderung (Rückgabe null).
Future<FeedFilter?> showFilterSheet(BuildContext context, FeedFilter current) {
  return showModalBottomSheet<FeedFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FilterSheet(current: current),
  );
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.current});

  final FeedFilter current;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _query;
  late String? _category;

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

  void _apply() {
    if (!_formKey.currentState!.validate()) return;
    final query = _query.text.trim();
    Navigator.of(context).pop(FeedFilter(
      query: query.isEmpty ? null : query,
      category: _category,
      // Ortschaft und Umkreis (F-08) bleiben, wie sie waren.
      placeId: widget.current.placeId,
      radiusKm: widget.current.radiusKm,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
