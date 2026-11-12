import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'chat_screen.dart';

/// Chats (UC8). Startmaske des Bereichs CHAT.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Chats',
      useCase: 'UC8',
      isTabRoot: true,
      actions: [
        PlaceholderAction(
          'Chat öffnen',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
        ),
      ],
    );
  }
}
