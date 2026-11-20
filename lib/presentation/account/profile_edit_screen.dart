import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import '../widgets/form_fields.dart';

/// Profil bearbeiten (UC2). Zeigt Anzeigename und Mailadresse (nur lesen)
/// und bietet «Abmelden» und «Konto löschen» (TC06, N-05).
/// Name, Wohnort und Profilbild ändern (F-02) ist noch offen.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    try {
      final email = await context.read<SessionProvider>().myEmail();
      if (mounted) setState(() => _email = email);
    } catch (_) {
      // Ohne Verbindung bleibt das Feld leer, der Rest geht trotzdem.
      if (mounted) setState(() => _email = '');
    }
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await context.read<SessionProvider>().signOut();
    // Alle geöffneten Masken schliessen. Darunter zeigt SessionGate jetzt
    // «Anmelden», weil keine Sitzung mehr besteht.
    navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

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
    final user = context.watch<SessionProvider>().user;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text('Profil bearbeiten',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            LabeledField(
              label: 'Anzeigename',
              child: _ReadOnlyValue(user?.displayName ?? '', key: const Key('profile-name')),
            ),
            LabeledField(
              label: 'Mailadresse',
              child: _ReadOnlyValue(_email ?? '…', key: const Key('profile-email')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _signOut, child: const Text('Abmelden')),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('profile-delete'),
              onPressed: _deleteAccount,
              style: TextButton.styleFrom(foregroundColor: RefindColors.accent),
              child: const Text('Konto löschen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wert, den man hier nur ansehen, nicht ändern kann.
class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: Text(value, overflow: TextOverflow.ellipsis),
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
