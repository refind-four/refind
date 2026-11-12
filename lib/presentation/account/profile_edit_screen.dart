import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/state/session_provider.dart';
import '../widgets/placeholder_screen.dart';

/// Profil bearbeiten (UC2). Von hier führt «Abmelden» zurück zu «Anmelden».
class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<SessionProvider>().signOut();
    // Alle geöffneten Masken schliessen. Darunter zeigt SessionGate jetzt
    // «Anmelden», weil keine Sitzung mehr besteht.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Profil bearbeiten',
      useCase: 'UC2',
      actions: [
        PlaceholderAction(
          'Speichern',
          primary: true,
          () => Navigator.of(context).pop(),
        ),
        PlaceholderAction('Abmelden', () => _signOut(context)),
      ],
    );
  }
}
