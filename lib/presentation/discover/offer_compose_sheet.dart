import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../application/logic/offer_rules.dart';
import '../../application/logic/price_logic.dart';
import '../../application/services/offer_service.dart';
import '../../data/input_checks.dart' show fileSizes, photoTooLargeMessage;
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/connection_error.dart' show unexpectedErrorMessage;
import '../widgets/form_fields.dart';
import '../widgets/offer_photo.dart';

/// Wählt ein Foto aus Kamera oder Galerie. Tests geben eine Attrappe mit.
typedef PhotoPicker = Future<File?> Function(ImageSource source);

/// Standard: image_picker, verkleinert auf höchstens 1600 px, JPEG 80 %.
/// So bleiben die Fotos klein (mobiles Netz, Speicherplatz in Storage).
Future<File?> pickPhotoWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return file == null ? null : File(file.path);
}

/// Angebot senden (UC6, F-09, Konzept Kapitel 3.5) – Sheet über «Entdecken».
/// Liefert das gespeicherte Angebot, oder null, wenn abgebrochen.
Future<Offer?> showOfferComposeSheet(
  BuildContext context,
  FeedItem item, {
  PhotoPicker pickPhoto = pickPhotoWithImagePicker,
}) {
  return showModalBottomSheet<Offer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => OfferComposeSheet(item: item, pickPhoto: pickPhoto),
  );
}

class OfferComposeSheet extends StatefulWidget {
  const OfferComposeSheet({
    super.key,
    required this.item,
    this.pickPhoto = pickPhotoWithImagePicker,
  });

  final FeedItem item;
  final PhotoPicker pickPhoto;

  @override
  State<OfferComposeSheet> createState() => _OfferComposeSheetState();
}

class _OfferComposeSheetState extends State<OfferComposeSheet> {
  final _formKey = GlobalKey<FormState>();

  /// Nach dem ersten erfolglosen «Angebot senden» wird bei jeder Eingabe
  /// neu geprüft, wie in Anmelden und Registrieren. Sonst bliebe «Bitte gib
  /// einen Preis ein.» stehen und verdeckte den Hinweis «über der
  /// Preisobergrenze».
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  final _price = TextEditingController();
  final _message = TextEditingController();
  final List<File> _photos = [];
  bool _busy = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    // Hinweis «über Budget» sofort nachführen.
    _price.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _price.dispose();
    _message.dispose();
    super.dispose();
  }

  Want get _want => widget.item.want;

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Aus der Galerie wählen'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final file = await widget.pickPhoto(source);
      if (file == null || !mounted || !canAddPhoto(_photos.length)) return;
      // Prüfung in der App: zu grosse Fotos gar nicht erst aufnehmen.
      // Repository und Bucket prüfen dieselbe Grenze noch einmal.
      if (fileSizes([file]).single > OfferLimits.maxPhotoBytes) {
        setState(() => _saveError = photoTooLargeMessage);
        return;
      }
      setState(() {
        _photos.add(file);
        _saveError = null;
      });
    } catch (_) {
      // z.B. Zugriff auf Kamera verweigert
      if (mounted) {
        setState(() => _saveError = 'Das Foto konnte nicht geladen werden.');
      }
    }
  }

  Future<void> _send() async {
    setState(() => _saveError = null);
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() => _busy = true);
    try {
      final offer = await context.read<OfferService>().createOffer(
            _want.id,
            parseChfToRappen(_price.text)!,
            _message.text,
            List.of(_photos),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(offer);
      messenger.showSnackBar(SnackBar(
        content: Text(offer.photos.length < _photos.length
            ? 'Angebot gesendet. Die Fotos konnten noch nicht gespeichert werden.'
            : 'Angebot gesendet.'),
      ));
    } on RepositoryException catch (e) {
      // Auch bei «keine Verbindung»: Meldung im Sheet (eine SnackBar läge
      // hinter dem Sheet). Die Eingaben bleiben, «Angebot senden» ist der
      // Knopf zum Wiederholen (Konzept 2.3).
      if (mounted) setState(() => _saveError = e.message);
    } catch (_) {
      if (mounted) setState(() => _saveError = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = parseChfToRappen(_price.text);
    final overBudget =
        price != null && isOverBudget(price, _want.budgetMaxRappen);

    return Padding(
      // Platz für die Tastatur
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Angebot senden', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '${_want.title} · ${widget.item.buyerName} sucht bis '
                '${formatChf(_want.budgetMaxRappen)}',
                style: const TextStyle(color: RefindColors.muted),
              ),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Dein Preis (CHF)',
                child: TextFormField(
                  key: const Key('offer-price'),
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  validator: validateOfferPrice,
                  decoration: InputDecoration(
                    hintText: 'z.B. ${rappenToChf(_want.budgetMaxRappen)}',
                    helperText: overBudget
                        ? 'Liegt über der Preisobergrenze. Der Käufer sieht das.'
                        : null,
                    helperStyle: const TextStyle(color: RefindColors.accent),
                  ),
                ),
              ),
              LabeledField(
                label: 'Nachricht',
                child: TextFormField(
                  key: const Key('offer-message'),
                  controller: _message,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: OfferLimits.maxMessageLength,
                  validator: validateOfferMessage,
                  decoration: const InputDecoration(
                    hintText: 'Zustand, Zubehör, Übergabe …',
                  ),
                ),
              ),
              Text(
                'FOTOS (${_photos.length}/${OfferLimits.maxPhotos})',
                style: refindLabelStyle,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Stack(
                      children: [
                        OfferPhoto(_photos[i].path),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: InkWell(
                            onTap: _busy
                                ? null
                                : () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: RefindColors.ink,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (canAddPhoto(_photos.length))
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: OutlinedButton(
                        key: const Key('offer-add-photo'),
                        onPressed: _busy ? null : _addPhoto,
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (_saveError != null) FormMessage(_saveError!),
              Theme(
                // Rostrot wie im visuellen Konzept (theme.dart)
                data: Theme.of(context).copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      backgroundColor: RefindColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                child: BusyButton(label: 'Angebot senden', busy: _busy, onPressed: _send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
