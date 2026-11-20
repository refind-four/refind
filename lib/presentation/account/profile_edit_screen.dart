import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import '../widgets/placeholder_screen.dart';

/// Profil bearbeiten (UC2). Von hier führt «Abmelden» zurück zu «Anmelden».
/// «Konto löschen» löscht das Konto mit allen Daten (TC06, N-05).
/// Name, Wohnort und Bild ändern folgt (F-02).
class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<SessionProvider>().signOut();
    // Alle geöffneten Masken schliessen. Darunter zeigt SessionGate jetzt
    // «Anmelden», weil keine Sitzung mehr besteht.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<SessionProvider>().deleteAccount();
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
          const SnackBar(content: Text('Dein Konto und deine Daten sind gelöscht.')));
    } on RepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.kind == RepositoryErrorKind.keineVerbindung
            ? 'Keine Verbindung. Dein Konto ist noch nicht gelöscht.'
            : e.message),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(unexpectedErrorMessage)));
    }
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
        PlaceholderAction('Konto löschen', () => _deleteAccount(context)),
      ],
    );
  }
}

/// Rückfrage vor dem Löschen: Erst wenn «LÖSCHEN» eingetippt ist, wird der
/// rote Knopf aktiv. So löscht niemand sein Konto aus Versehen.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  /// Wort, das man zur Bestätigung eintippen muss.
  static const confirmWord = 'LÖSCHEN';

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _confirmed => _input.text.trim() == DeleteAccountDialog.confirmWord;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Konto löschen?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gelöscht werden deine Gesuche, Angebote, Chats, Fotos und '
              'Bewertungen, auch die Angebote anderer zu deinen Gesuchen und '
              'eure Chats. Das lässt sich nicht rückgängig machen.',
            ),
            const SizedBox(height: 16),
            const Text('Tippe zur Bestätigung ${DeleteAccountDialog.confirmWord} ein.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              key: const Key('delete-confirm-input'),
              controller: _input,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: DeleteAccountDialog.confirmWord),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('delete-confirm'),
          style: FilledButton.styleFrom(backgroundColor: RefindColors.accent),
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Konto löschen'),
        ),
      ],
    );
  }
}
