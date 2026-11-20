import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../application/logic/chat_rules.dart';
import '../../application/logic/price_logic.dart';
import '../../application/services/chat_service.dart';
import '../../application/state/session_provider.dart';
import '../../data/input_checks.dart' show fileSizes, photoTooLargeMessage;
import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../discover/offer_compose_sheet.dart' show PhotoPicker, pickPhotoWithImagePicker;
import '../theme.dart';
import 'deal_screen.dart';
import 'deal_sheet.dart';
import '../widgets/offer_photo.dart';

/// Chat · Verhandlung (UC8, F-13, Abbildung 10).
///
/// Kopfzeile: Gegenüber, Gesuchstitel, Angebotspreis. Darunter die
/// Nachrichten, neue erscheinen ohne Neuladen (Echtzeit). Unten «+» für
/// Fotos, das Eingabefeld und beim Käufer «Deal».
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.thread,
    this.summary,
    this.pickPhoto = pickPhotoWithImagePicker,
  }) : assert(thread != null || summary != null);

  /// Fotos aus Kamera oder Galerie. Tests geben eine eigene Funktion mit.
  final PhotoPicker pickPhoto;

  /// Chat direkt nach «Annehmen» (UC7). Namen, Titel und Preis lädt die
  /// Maske dann selbst.
  final ChatThread? thread;

  /// Chat aus der Chatliste, mit Namen, Titel und Preis.
  final ChatSummary? summary;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Nachricht, die gerade gesendet wird oder nicht gesendet werden konnte.
class _Pending {
  _Pending(this.text);

  final String text;
  bool failed = false;
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  ChatSummary? _chat;
  List<Message> _messages = const [];
  bool _loadingMessages = true;
  String? _error;
  StreamSubscription<List<Message>>? _subscription;

  /// Gesendete Nachrichten, die die Echtzeit noch nicht geliefert hat.
  final List<Message> _sent = [];
  final List<_Pending> _pending = [];

  /// Ein Foto wird gerade hochgeladen.
  bool _sendingPhoto = false;

  /// Chat nach dem Abschluss (Preis und Zeit), sonst null.
  ChatThread? _closedThread;

  /// «Deal» läuft gerade.
  bool _closing = false;

  ChatThread get _thread =>
      _closedThread ?? _chat?.thread ?? widget.summary?.thread ?? widget.thread!;

  /// UC8 Schritt 7: Preis prüfen und bestätigen, dann «Deal bestätigt».
  Future<void> _closeDeal() async {
    final chat = _chat;
    final price = await showDealSheet(
      context,
      wantTitle: chat?.wantTitle ?? '',
      offerPriceRappen: chat?.offerPriceRappen,
    );
    if (price == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _closing = true);
    try {
      await context.read<ChatService>().closeDeal(_threadId, price);
      if (!mounted) return;
      final now = DateTime.now();
      setState(() => _closedThread = _thread.copyWith(
          agreedPriceRappen: price, closedAt: now, lastActivity: now));
      await navigator.push(MaterialPageRoute(
        builder: (_) => DealScreen(
          wantTitle: chat?.wantTitle ?? '',
          agreedPriceRappen: price,
          otherUserName: chat?.otherUserName ?? '',
          handoverPlace: _thread.handoverPlace,
        ),
      ));
    } on RepositoryException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(e.kind == RepositoryErrorKind.keineVerbindung
                ? 'Keine Verbindung. Der Deal ist noch nicht abgeschlossen.'
                : e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Der Deal ist noch nicht abgeschlossen.')));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  String get _threadId => widget.summary?.thread.id ?? widget.thread!.id;

  String get _myId => context.read<SessionProvider>().user?.id ?? '';

  @override
  void initState() {
    super.initState();
    _chat = widget.summary;
    _text.addListener(() => setState(() {}));
    if (_chat == null) _loadHeader();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// Nach «Annehmen» kennt die Maske nur den Chat: Namen, Titel und Preis
  /// für die Kopfzeile nachladen.
  Future<void> _loadHeader() async {
    try {
      final chat = await context.read<ChatService>().getChat(_threadId);
      if (mounted) setState(() => _chat = chat);
    } catch (_) {
      // Die Kopfzeile bleibt dann schlicht, die Nachrichten gehen trotzdem.
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    setState(() {
      _loadingMessages = true;
      _error = null;
    });
    _subscription = context.read<ChatService>().watchMessages(_threadId).listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _messages = messages;
          _loadingMessages = false;
          // Was die Echtzeit jetzt liefert, braucht keine Kopie mehr.
          final ids = {for (final m in messages) m.id};
          _sent.removeWhere((m) => ids.contains(m.id));
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loadingMessages = false;
          _error = e is RepositoryException && e.kind != RepositoryErrorKind.keineVerbindung
              ? e.message
              : 'Keine Verbindung. Die Nachrichten konnten nicht geladen werden.';
        });
      },
    );
  }

  Future<void> _send([_Pending? retry]) async {
    final text = retry?.text ?? _text.text.trim();
    if (!canSendText(text)) return;
    final pending = retry ?? _Pending(text);
    setState(() {
      pending.failed = false;
      if (retry == null) {
        _pending.add(pending);
        _text.clear();
      }
    });
    try {
      final message = await context.read<ChatService>().sendText(_threadId, text);
      if (!mounted) return;
      setState(() {
        _pending.remove(pending);
        if (!_messages.any((m) => m.id == message.id)) _sent.add(message);
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      // UC8 Ausnahme: als nicht gesendet markieren, erneut senden anbieten.
      setState(() => pending.failed = true);
      if (e.kind != RepositoryErrorKind.keineVerbindung) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) setState(() => pending.failed = true);
    }
  }

  /// UC8 Schritt 3: «+» → Kamera oder Galerie → Foto senden.
  Future<void> _pickAndSendPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto aufnehmen'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Aus der Galerie wählen'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    File? photo;
    try {
      photo = await widget.pickPhoto(source);
    } catch (_) {
      // z.B. Zugriff auf Kamera verweigert
    }
    if (photo == null || !mounted) return;
    await _sendPhoto(photo);
  }

  Future<void> _sendPhoto(File photo) async {
    final messenger = ScaffoldMessenger.of(context);
    // Prüfung in der App, Repository und Bucket prüfen noch einmal
    if (fileSizes([photo]).single > OfferLimits.maxPhotoBytes) {
      messenger.showSnackBar(const SnackBar(content: Text(photoTooLargeMessage)));
      return;
    }
    setState(() => _sendingPhoto = true);
    try {
      final message = await context.read<ChatService>().sendPhoto(_threadId, photo);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) _sent.add(message);
      });
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(e is RepositoryException &&
                  e.kind != RepositoryErrorKind.keineVerbindung
              ? e.message
              : 'Das Foto wurde nicht gesendet.'),
          action: SnackBarAction(label: 'Nochmal', onPressed: () => _sendPhoto(photo)),
        ));
    } finally {
      if (mounted) setState(() => _sendingPhoto = false);
    }
  }

  /// Nachrichten aus der Echtzeit und eben gesendete, älteste zuerst.
  List<Message> get _allMessages {
    final ids = {for (final m in _messages) m.id};
    return [..._messages, ..._sent.where((m) => !ids.contains(m.id))]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final thread = _thread;
    final price = chat?.offerPriceRappen;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chat?.otherUserName ?? 'Chat',
                key: const Key('chat-title'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (chat != null)
              Text(chat.wantTitle.toUpperCase(),
                  overflow: TextOverflow.ellipsis, style: refindLabelStyle),
          ],
        ),
        actions: [
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(formatChf(price),
                    key: const Key('chat-price'),
                    style: const TextStyle(color: RefindColors.accent)),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _messageList(chat, thread)),
            const Divider(height: 1),
            _inputBar(thread),
          ],
        ),
      ),
    );
  }

  Widget _messageList(ChatSummary? chat, ChatThread thread) {
    if (_loadingMessages && _messages.isEmpty && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(padding: const EdgeInsets.all(24), children: [
        Text(_error!, style: const TextStyle(color: RefindColors.accent)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
              onPressed: _subscribe, child: const Text('Nochmals versuchen')),
        ),
      ]);
    }
    final me = _myId;
    final messages = _allMessages;
    final items = <Widget>[
      if (chat != null)
        Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.white,
            child: Text('ANGEBOT AUF «${chat.wantTitle.toUpperCase()}»',
                textAlign: TextAlign.center, style: refindLabelStyle),
          ),
        ),
      for (final m in messages) _Bubble(message: m, mine: m.senderId == me),
      for (final p in _pending)
        _PendingBubble(pending: p, onRetry: () => _send(p)),
      if (_sendingPhoto)
        const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Foto wird gesendet …',
                key: Key('chat-photo-sending'),
                style: TextStyle(fontSize: 12, color: RefindColors.muted)),
          ),
        ),
      if (thread.isClosed)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'DEAL ABGESCHLOSSEN'
              '${thread.agreedPriceRappen == null ? '' : ' · ${formatChf(thread.agreedPriceRappen!)}'}',
              key: const Key('chat-closed'),
              style: refindLabelStyle.copyWith(color: RefindColors.accent),
            ),
          ),
        ),
    ];
    // reverse: Die neueste Nachricht steht unten, die Liste startet dort.
    return ListView(
      key: const Key('chat-messages'),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: items.reversed.toList(),
    );
  }

  Widget _inputBar(ChatThread thread) {
    final error = messageTextError(_text.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            key: const Key('chat-add-photo'),
            tooltip: 'Foto senden',
            onPressed: _sendingPhoto ? null : _pickAndSendPhoto,
            icon: const Icon(Icons.add_circle_outline),
          ),
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: _text,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Nachricht',
                errorText: error,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: const Key('chat-send'),
            tooltip: 'Senden',
            onPressed: canSendText(_text.text) ? () => _send() : null,
            icon: const Icon(Icons.send),
            color: RefindColors.accent,
          ),
          // «Deal» nur beim Käufer und nur im offenen Chat (UC8 Ausnahme)
          if (canCloseDeal(thread, _myId))
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: FilledButton(
                key: const Key('chat-deal'),
                style: FilledButton.styleFrom(
                  backgroundColor: RefindColors.accent,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _closing ? null : _closeDeal,
                child: const Text('Deal'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sprechblase: eigene rechts dunkel, die des Gegenübers links weiss.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(message.createdAt).format(context);
    final content = message.kind == MessageKind.foto
        ? OfferPhoto(message.body, size: 160, enlargeOnTap: true)
        : Text(message.body,
            style: TextStyle(color: mine ? Colors.white : RefindColors.ink));
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('message-${message.id}'),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: message.kind == MessageKind.foto
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? RefindColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white70 : RefindColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// Eigene Nachricht, die noch unterwegs ist oder nicht gesendet wurde.
class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.pending, required this.onRetry});

  final _Pending pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: RefindColors.ink.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(pending.text, style: const TextStyle(color: Colors.white)),
          ),
          if (pending.failed)
            TextButton(
              key: const Key('chat-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: RefindColors.accent),
              child: const Text('Nicht gesendet · Nochmal versuchen'),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('wird gesendet …',
                  style: TextStyle(fontSize: 10, color: RefindColors.muted)),
            ),
        ],
      ),
    );
  }
}
