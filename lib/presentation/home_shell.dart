import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/services/want_service.dart';
import '../application/state/my_wants_provider.dart';
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

  /// Zählt hoch, wenn man CHAT wählt. Die Chatliste lädt dann neu, damit
  /// z.B. ein Chat nach «Annehmen» (UC7) im Bereich GESUCHE gleich da ist.
  final _chatTabSelected = ValueNotifier<int>(0);

  // IndexedStack behält alle vier Bereiche im Speicher. So bleibt z.B. die
  // Scrollposition im Feed erhalten, wenn man kurz zu den Chats wechselt.
  late final _tabs = [
    const MyWantsScreen(),
    const DiscoverScreen(),
    ChatListScreen(reload: _chatTabSelected),
    const ProfileScreen(),
  ];

  @override
  void dispose() {
    _chatTabSelected.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _index = i);
    if (i == 2) _chatTabSelected.value++;
  }

  @override
  Widget build(BuildContext context) {
    // MyWantsProvider lebt nur, solange jemand angemeldet ist. Nach dem
    // Abmelden verschwindet HomeShell und mit ihr die Liste des Kontos.
    return ChangeNotifierProvider(
      create: (context) => MyWantsProvider(context.read<WantService>())..load(),
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'GESUCHE',
          ),
          NavigationDestination(
            // Kompass: Gesuche anderer entdecken
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
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
