import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../application/logic/price_logic.dart';
import '../../application/logic/want_rules.dart';
import '../../application/services/want_service.dart';
import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/choice_chips.dart';
import '../widgets/connection_error.dart';
import '../widgets/form_fields.dart';
import 'want_option_sheets.dart';

/// Gesuch aufhängen in vier Schritten (UC3, F-03, Konzept 3.3):
///
/// 1. Titel                         «Was suchst du?»
/// 2. Kategorie und Beschreibung    «Worum geht es genau?»
/// 3. Details                       «Wie viel, welcher Zustand?»
/// 4. Gesuch ist live               «Dein Gesuch hängt.»
///
/// Erst «Weiter» in Schritt 3 speichert. Fehlt etwas, bleibt die Maske im
/// Schritt und markiert das Feld (UC3 Ausnahmen, TC08). «Abbrechen» in
/// Schritt 1 speichert nichts. Gibt das neue Gesuch zurück, sonst null.
class WantWizardScreen extends StatefulWidget {
  const WantWizardScreen({super.key});

  @override
  State<WantWizardScreen> createState() => _WantWizardScreenState();
}

class _WantWizardScreenState extends State<WantWizardScreen> {
  static const _stepCount = 4;

  int _step = 0; // 0 bis 3
  bool _busy = false;

  // Eingaben
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  int _budgetRappen = 0;
  String? _condition;
  Place? _region;
  late int _radiusKm;
  late final int _profileRadiusKm;
  int _durationDays = WantLimits.defaultDurationDays;

  // Fehlermeldungen je Feld (null = kein Fehler)
  String? _titleError;
  String? _categoryError;
  String? _descriptionError;
  String? _budgetError;
  String? _regionError;
  String? _saveError;

  Want? _created;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionProvider>().user;
    // UC3 Schritt 4: Umkreis aus dem Profil, Region aus dem Wohnort.
    _profileRadiusKm = user?.radiusKm ?? 20;
    _radiusKm = _profileRadiusKm;
    if (user != null) _loadHomePlace(user);
  }

  Future<void> _loadHomePlace(User user) async {
    try {
      final place = await context.read<WantService>().homePlace(user);
      if (mounted && _region == null) setState(() => _region = place);
    } on RepositoryException {
      // Kein Wohnort ladbar: Region bleibt leer und muss gewählt werden.
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Ablauf
  // ---------------------------------------------------------------------

  /// Prüft die Felder des aktuellen Schritts. true = alles in Ordnung.
  bool _validateStep() {
    setState(() {
      switch (_step) {
        case 0:
          _titleError = validateWantTitle(_title.text);
        case 1:
          _categoryError = validateWantCategory(_category);
          _descriptionError = validateWantDescription(_description.text);
        case 2:
          _budgetError = validateWantBudget(_budgetRappen);
          _regionError = validateWantRegion(_region);
      }
    });
    return switch (_step) {
      0 => _titleError == null,
      1 => _categoryError == null && _descriptionError == null,
      2 => _budgetError == null && _regionError == null,
      _ => true,
    };
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_validateStep()) return;
    if (_step == 2) {
      await _save();
    } else {
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0 || _step == 3) {
      Navigator.of(context).pop(_created);
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _saveError = null;
    });
    final draft = WantDraft(
      title: _title.text.trim(),
      category: _category!,
      description: _description.text.trim(),
      budgetMaxRappen: _budgetRappen,
      condition: _condition!,
      regionId: _region!.id,
      radiusKm: _radiusKm,
      durationDays: _durationDays,
    );
    try {
      final want = await context.read<WantService>().createWant(draft);
      if (!mounted) return;
      setState(() {
        _created = want;
        _step = 3;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, _save);
      } else {
        // Das Repository hat etwas abgelehnt, das die Maske durchgelassen
        // hat. Meldung zeigen, Eingaben behalten.
        setState(() => _saveError = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _saveError = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectCategory(String category) {
    setState(() {
      if (_category != category) {
        _category = category;
        // Vorauswahl «Egal» (letzter Wert), passend zur neuen Kategorie.
        _condition = zustaende[category]!.last;
      }
      _categoryError = null;
    });
  }

  Future<void> _changeRegion() async {
    final result = await showRegionSheet(
      context,
      region: _region,
      radiusKm: _radiusKm,
      profileRadiusKm: _profileRadiusKm,
    );
    if (result == null) return;
    setState(() {
      _region = result.region;
      _radiusKm = result.radiusKm;
      _regionError = null;
    });
  }

  Future<void> _changeDuration() async {
    final days = await showDurationSheet(context, current: _durationDays);
    if (days != null) setState(() => _durationDays = days);
  }

  // ---------------------------------------------------------------------
  // Oberfläche
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // PopScope: Die Zurück-Taste von Android geht einen Schritt zurück,
    // statt den ganzen Assistenten zu schliessen.
    return PopScope(
      canPop: _step == 0 || _step == 3,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step < 3) _topBar(),
                      Expanded(child: _stepContent()),
                      const SizedBox(height: 16),
                      if (_saveError != null) FormMessage(_saveError!),
                      _bottomButton(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        TextButton(
          // minimumSize Breite 0: sonst wird kurzer Text wie «Zurück» in
          // einer Mindestbreite zentriert und wirkt eingerückt.
          style: TextButton.styleFrom(
            foregroundColor: RefindColors.muted,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 48),
          ),
          onPressed: _busy ? null : _back,
          child: Text(_step == 0 ? 'Abbrechen' : 'Zurück'),
        ),
        const Spacer(),
        Text('SCHRITT ${_step + 1} / $_stepCount', style: refindLabelStyle),
      ],
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      0 => _titleStep(),
      1 => _categoryStep(),
      2 => _detailsStep(),
      _ => _liveStep(),
    };
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 28),
        child: Text(text, style: Theme.of(context).textTheme.headlineLarge),
      );

  // Schritt 1: Titel
  Widget _titleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Was suchst du?'),
        TextField(
          key: const Key('want-title'),
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _next(),
          // Zähler zeigen, aber nicht abschneiden: So sieht man beim
          // Einfügen eines langen Textes, dass er zu lang ist.
          maxLength: WantLimits.maxTitleLength,
          maxLengthEnforcement: MaxLengthEnforcement.none,
          onChanged: (_) {
            if (_titleError != null) {
              setState(() => _titleError = validateWantTitle(_title.text));
            }
          },
          decoration: InputDecoration(
            hintText: 'z.B. Omega Seamaster 166.062',
            errorText: _titleError,
          ),
        ),
        const SizedBox(height: 4),
        const Text('MARKE + MODELL + REFERENZ FINDET MEHR', style: refindLabelStyle),
      ],
    );
  }

  // Schritt 2: Kategorie und Beschreibung
  Widget _categoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Worum geht es genau?'),
        LabeledField(
          label: 'Kategorie',
          child: ChoiceChips<String>(
            key: const Key('want-category'),
            options: kategorien,
            selected: _category,
            onSelected: _selectCategory,
            errorText: _categoryError,
          ),
        ),
        LabeledField(
          label: 'Beschreibung',
          child: TextField(
            key: const Key('want-description'),
            controller: _description,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            maxLength: WantLimits.maxDescriptionLength,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            onChanged: (_) {
              if (_descriptionError != null) {
                setState(() =>
                    _descriptionError = validateWantDescription(_description.text));
              }
            },
            decoration: InputDecoration(
              hintText: 'Was ist dir wichtig? Zustand, Zubehör, Farbe …',
              errorText: _descriptionError,
            ),
          ),
        ),
      ],
    );
  }

  // Schritt 3: Details
  Widget _detailsStep() {
    final maxChf = rappenToChf(WantLimits.maxBudgetRappen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Wie viel, welcher Zustand?'),
        const Text('BUDGET', style: refindLabelStyle),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Flexible + FittedBox: Der Betrag schrumpft bei grosser Schrift,
            // statt rechts überzulaufen.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatChf(_budgetRappen),
                  key: const Key('want-budget-value'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('max.', style: TextStyle(color: RefindColors.muted)),
          ],
        ),
        Slider(
          key: const Key('want-budget'),
          value: _budgetRappen.toDouble(),
          min: 0,
          max: WantLimits.maxBudgetRappen.toDouble(),
          divisions: WantLimits.maxBudgetRappen ~/ WantLimits.budgetStepRappen,
          onChanged: (v) => setState(() {
            _budgetRappen = v.round();
            if (_budgetError != null) _budgetError = validateWantBudget(_budgetRappen);
          }),
        ),
        Row(
          children: [
            const Text('CHF 0', style: refindLabelStyle),
            const Spacer(),
            Text(formatChf(chfToRappen(maxChf)), style: refindLabelStyle),
          ],
        ),
        if (_budgetError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _budgetError!,
              style: const TextStyle(color: RefindColors.accent, fontSize: 12),
            ),
          ),
        const SizedBox(height: 24),
        LabeledField(
          label: 'Zustand',
          child: ChoiceChips<String>(
            options: zustaende[_category] ?? const [],
            selected: _condition,
            onSelected: (c) => setState(() => _condition = c),
          ),
        ),
        const Text('REGION & LAUFZEIT', style: refindLabelStyle),
        const SizedBox(height: 8),
        _ChangeRow(
          key: const Key('want-region'),
          text: _region == null
              ? 'Region wählen'
              : '${_region!.name} + $_radiusKm km',
          errorText: _regionError,
          onTap: _changeRegion,
        ),
        const SizedBox(height: 8),
        _ChangeRow(
          key: const Key('want-duration'),
          text: '$_durationDays Tage sichtbar',
          onTap: _changeDuration,
        ),
      ],
    );
  }

  // Schritt 4: Gesuch ist live
  Widget _liveStep() {
    final want = _created!;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.description_outlined, size: 72, color: RefindColors.ink),
        const SizedBox(height: 24),
        Text('Dein Gesuch hängt.',
            textAlign: TextAlign.center, style: textTheme.headlineLarge),
        const SizedBox(height: 12),
        const Text(
          'Wir sagen dir Bescheid, sobald jemand ein Angebot schickt. '
          'Meist geht das schnell.',
          textAlign: TextAlign.center,
          style: TextStyle(color: RefindColors.muted),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DEIN GESUCH', style: refindLabelStyle),
              const SizedBox(height: 8),
              Text(want.title, style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'bis ${formatChf(want.budgetMaxRappen)} · ${_region!.name} · '
                '$_durationDays Tage',
                style: const TextStyle(color: RefindColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomButton() {
    if (_step == 3) {
      return FilledButton(
        onPressed: () => Navigator.of(context).pop(_created),
        child: const Text('Zu meinen Gesuchen'),
      );
    }
    return BusyButton(label: 'Weiter', busy: _busy, onPressed: _next);
  }
}

/// Weisse Zeile «Bern + 25 km … ändern» (Konzept Abbildung 7, Details).
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    super.key,
    required this.text,
    required this.onTap,
    this.errorText,
  });

  final String text;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.white,
          shape: errorText == null
              ? null
              : const Border.fromBorderSide(BorderSide(color: RefindColors.accent)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(text)),
                  const Text('ändern', style: TextStyle(color: RefindColors.muted)),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: const TextStyle(color: RefindColors.accent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
