import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'deal_screen.dart';
import 'handover_sheet.dart';

/// Chat · Verhandlung (UC8).
/// «+» öffnet «Übergabe festhalten», «Deal» führt zu «Deal bestätigt».
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

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
