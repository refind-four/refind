import 'package:flutter/material.dart';

import '../../application/logic/status_logic.dart';
import '../../application/logic/time_logic.dart';
import '../../model/model.dart';
import '../theme.dart';

/// Status oben rechts auf der Karte und in «Gesuch Detail» (Abbildung 8):
/// «● LIVE · 5 TAGE», «PAUSIERT · 5 TAGE», «ANGEBOT ANGENOMMEN»,
/// «ABGELAUFEN» oder «ERLEDIGT». Ob abgelaufen, entscheidet die StatusLogic.
(String, Color) wantStatusLabel(
  Want want, {
  required bool hasAcceptedOffer,
  required DateTime now,
}) {
  if (want.status == WantStatus.erledigt) return ('ERLEDIGT', RefindColors.muted);
  if (hasAcceptedOffer) return ('ANGEBOT ANGENOMMEN', RefindColors.accent);
  final status =
      StatusLogic.effectiveStatus(want, now, hasAcceptedOffer: hasAcceptedOffer);
  final remaining = StatusLogic.remaining(want, now);
  final left = remaining == null ? '' : ' · ${formatRemaining(remaining).toUpperCase()}';
  return switch (status) {
    WantStatus.aktiv => ('● LIVE$left', RefindColors.accent),
    WantStatus.pausiert => ('PAUSIERT$left', RefindColors.muted),
    WantStatus.abgelaufen => ('ABGELAUFEN', RefindColors.muted),
    WantStatus.erledigt => ('ERLEDIGT', RefindColors.muted),
  };
}

/// [wantStatusLabel] als Text im Stil der Kategorie-Beschriftung.
class WantStatusText extends StatelessWidget {
  const WantStatusText({
    super.key,
    required this.want,
    required this.hasAcceptedOffer,
    required this.now,
  });

  final Want want;
  final bool hasAcceptedOffer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (text, color) =
        wantStatusLabel(want, hasAcceptedOffer: hasAcceptedOffer, now: now);
    return Text(text, style: refindLabelStyle.copyWith(color: color));
  }
}
