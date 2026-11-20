import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/price_logic.dart';
import '../../application/logic/time_logic.dart';
import '../../application/services/chat_service.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import 'chat_screen.dart';

/// Chats (UC8 Schritt 1, Abbildung 10). Startmaske des Bereichs CHAT.
/// Je Chat: Gegenüber, letzte Nachricht, Gesuchstitel, Angebotspreis, Zeit.
/// Ungelesene Nachrichten zeigt die Liste erst mit «gelesen» (F-14).
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.reload});

  /// Löst ein Neuladen aus, z.B. wenn man den Bereich CHAT wählt.
  final Listenable? reload;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSummary> _chats = const [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.reload?.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reload?.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final chats = await context.read<ChatService>().getChats();
      if (mounted && request == _request) setState(() => _chats = chats);
    } on RepositoryException catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e.kind == RepositoryErrorKind.keineVerbindung
          ? 'Keine Verbindung. Ziehe die Liste nach unten, um es nochmals zu versuchen.'
          : e.message);
    } catch (_) {
      if (mounted && request == _request) setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(ChatSummary chat) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(summary: chat)),
    );
    // Letzte Nachricht und Reihenfolge nachführen
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Text('Chats', style: Theme.of(context).textTheme.headlineMedium),
            ),
            const Divider(height: 1),
            Expanded(child: RefreshIndicator(onRefresh: _load, child: _list())),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loading && _chats.isEmpty && _error == null) {
      return ListView(children: const [
        SizedBox(height: 120),
        Center(child: CircularProgressIndicator()),
      ]);
    }
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error!, style: const TextStyle(color: RefindColors.accent)),
      ]);
    }
    if (_chats.isEmpty) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Text(
          'Noch keine Chats. Ein Chat beginnt, sobald ein Angebot angenommen ist.',
          style: TextStyle(color: RefindColors.muted),
        ),
      ]);
    }
    final now = DateTime.now();
    return ListView.separated(
      key: const Key('chat-list'),
      itemCount: _chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) =>
          _ChatTile(chat: _chats[i], now: now, onTap: () => _open(_chats[i])),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.now, required this.onTap});

  final ChatSummary chat;
  final DateTime now;
  final VoidCallback onTap;

  /// Vorschau der letzten Nachricht.
  String get _preview {
    final m = chat.lastMessage;
    if (m == null) {
      return chat.thread.isClosed ? 'Deal abgeschlossen' : 'Angebot angenommen';
    }
    return m.kind == MessageKind.foto ? 'Foto' : m.body;
  }

  @override
  Widget build(BuildContext context) {
    final name = chat.otherUserName.trim();
    final price = chat.offerPriceRappen;
    final time = chat.lastMessage?.createdAt ?? chat.thread.lastActivity;
    return InkWell(
      key: Key('chat-tile-${chat.thread.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(color: RefindColors.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(formatChatTime(time, now),
                          style: const TextStyle(
                              fontSize: 12, color: RefindColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      chat.wantTitle.toUpperCase(),
                      if (price != null) formatChf(price),
                      if (chat.thread.isClosed) 'ERLEDIGT',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: refindLabelStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
