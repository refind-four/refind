import 'package:flutter/material.dart';

import '../widgets/placeholder_screen.dart';
import 'profile_edit_screen.dart';

/// Profil (UC2). Startmaske des Bereichs PROFIL.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Profil',
      useCase: 'UC2',
      isTabRoot: true,
      actions: [
        PlaceholderAction(
          'Profil bearbeiten',
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
          ),
        ),
      ],
    );
  }
}
