import 'package:flutter/material.dart';

import 'account/profile_screen.dart';
import 'chat/chat_list_screen.dart';
import 'discover/discover_screen.dart';
import 'wants/my_wants_screen.dart';

/// Rahmen nach der Anmeldung: Navigationsleiste am unteren Rand mit den
/// vier Bereichen Gesuche, Entdecken, Chat und Profil (Konzept 3.1).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // IndexedStack behält alle vier Bereiche im Speicher. So bleibt z.B. die
  // Scrollposition im Feed erhalten, wenn man kurz zu den Chats wechselt.
  static const _tabs = [
    MyWantsScreen(),
    DiscoverScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'GESUCHE',
          ),
          NavigationDestination(
            icon: Icon(Icons.circle_outlined),
            selectedIcon: Icon(Icons.circle),
            label: 'ENTDECKEN',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'CHAT',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'PROFIL',
          ),
        ],
      ),
    );
  }
}
