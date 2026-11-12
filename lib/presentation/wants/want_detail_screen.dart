import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../widgets/placeholder_screen.dart';

/// Gesuch Detail · Angebote (UC4, UC7).
/// «Annehmen» öffnet den Chat zum angenommenen Angebot.
class WantDetailScreen extends StatelessWidget {
  const WantDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Gesuch Detail · Angebote',
      useCase: 'UC4, UC7',
      actions: [
        PlaceholderAction(
          'Angebot annehmen',
          primary: true,
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
        ),
      ],
    );
  }
}
