import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Kleines quadratisches Foto eines Angebots.
/// [source] ist ein Link (Supabase Storage) oder ein Pfad auf dem Handy
/// (Mock, oder ein Foto, das noch nicht gesendet ist).
class OfferPhoto extends StatelessWidget {
  const OfferPhoto(this.source, {super.key, this.size = 72});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget image;
    if (source.startsWith('http')) {
      image = Image.network(source, fit: BoxFit.cover, errorBuilder: _fallback);
    } else if (File(source).existsSync()) {
      image = Image.file(File(source), fit: BoxFit.cover, errorBuilder: _fallback);
    } else {
      image = _fallback(context, null, null);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _fallback(BuildContext context, Object? error, StackTrace? stack) {
    return const ColoredBox(
      color: Colors.white,
      child: Icon(Icons.photo_outlined, color: RefindColors.muted),
    );
  }
}
