import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Kleines quadratisches Foto eines Angebots.
/// [source] ist ein Link (Supabase Storage, eine Stunde gültig) oder ein
/// Pfad auf dem Handy (Mock, oder ein Foto, das noch nicht gesendet ist).
/// Mit [enlargeOnTap] öffnet ein Tipp das Foto gross (F-09: Der Käufer
/// soll den Gegenstand gut sehen).
class OfferPhoto extends StatelessWidget {
  const OfferPhoto(this.source, {super.key, this.size = 72, this.enlargeOnTap = false});

  final String source;
  final double size;
  final bool enlargeOnTap;

  Widget _image(BoxFit fit) {
    if (source.startsWith('http')) {
      return Image.network(source, fit: fit, errorBuilder: _fallback);
    }
    if (File(source).existsSync()) {
      return Image.file(File(source), fit: fit, errorBuilder: _fallback);
    }
    return _fallback(null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: size, height: size, child: _image(BoxFit.cover)),
    );
    if (!enlargeOnTap) return thumb;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          key: const Key('offer-photo-large'),
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            // Mit zwei Fingern vergrössern
            child: InteractiveViewer(child: _image(BoxFit.contain)),
          ),
        ),
      ),
      child: thumb,
    );
  }

  static Widget _fallback(BuildContext? context, Object? error, StackTrace? stack) {
    return const ColoredBox(
      color: Colors.white,
      child: Center(child: Icon(Icons.photo_outlined, color: RefindColors.muted)),
    );
  }
}
