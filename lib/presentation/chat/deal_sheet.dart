import 'package:flutter/material.dart';

import '../../application/logic/offer_rules.dart';
import '../../application/logic/price_logic.dart';
import '../theme.dart';
import '../widgets/form_fields.dart';

/// Deal abschliessen (UC8 Schritt 7): Der Käufer prüft den mit dem
/// Angebotspreis vorbelegten Preis und bestätigt. Liefert den Preis in
/// Rappen, oder null, wenn abgebrochen.
Future<int?> showDealSheet(
  BuildContext context, {
  required String wantTitle,
  required int? offerPriceRappen,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        DealSheet(wantTitle: wantTitle, offerPriceRappen: offerPriceRappen),
  );
}

class DealSheet extends StatefulWidget {
  const DealSheet({super.key, required this.wantTitle, required this.offerPriceRappen});

  final String wantTitle;
  final int? offerPriceRappen;

  @override
  State<DealSheet> createState() => _DealSheetState();
}

class _DealSheetState extends State<DealSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    // Vorbelegt mit dem Angebotspreis, ohne «CHF» (wie «Angebot senden»)
    final offer = widget.offerPriceRappen;
    _price = TextEditingController(
        text: offer == null ? '' : formatChf(offer).replaceFirst('CHF ', ''));
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(parseChfToRappen(_price.text));
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offerPriceRappen;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Deal abschliessen',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                [
                  widget.wantTitle.toUpperCase(),
                  if (offer != null) 'ANGEBOT ${formatChf(offer)}',
                ].join(' · '),
                style: refindLabelStyle,
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Vereinbarter Preis (CHF)',
                child: TextFormField(
                  key: const Key('deal-price'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: validateOfferPrice,
                  onFieldSubmitted: (_) => _confirm(),
                ),
              ),
              const Text(
                'Danach ist dein Gesuch erledigt. Das lässt sich nicht rückgängig machen.',
                style: TextStyle(color: RefindColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('deal-confirm'),
                style: FilledButton.styleFrom(backgroundColor: RefindColors.accent),
                onPressed: _confirm,
                child: const Text('Deal bestätigen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
