import 'package:flutter/material.dart';

import '../../model/model.dart';
import '../widgets/placeholder_screen.dart';
import 'deal_screen.dart';
import 'handover_sheet.dart';

/// Chat · Verhandlung (UC8).
/// «+» öffnet «Übergabe festhalten», «Deal» führt zu «Deal bestätigt».
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.thread});

  /// Chat, der angezeigt wird. Nach «Annehmen» (UC7) der neue Chat.
  /// Wird mit UC8 benutzt, der Platzhalter zeigt ihn noch nicht an.
  final ChatThread? thread;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Chat · Verhandlung',
      useCase: 'UC8',
      actions: [
        PlaceholderAction('+ Übergabe festhalten', () => showHandoverSheet(context)),
        PlaceholderAction(
          'Deal',
          primary: true,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DealScreen()),
          ),
        ),
      ],
    );
  }
}
