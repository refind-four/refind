import 'dart:io';

import '../../data/refind_repository.dart';
import '../../model/model.dart';

/// Chat und Abschluss (Konzept 4.2.2, UC8). Spricht nur mit der
/// Schnittstelle RefindRepository.
class ChatService {
  ChatService(this._repository);

  final RefindRepository _repository;

  /// UC8 Schritt 1: eigene Chats, zuletzt aktive zuerst.
  Future<List<ChatSummary>> getChats() => _repository.getChats();

  /// Ein Chat für die Kopfzeile von «Chat · Verhandlung», z.B. direkt nach
  /// «Annehmen» (UC7), wenn nur der ChatThread bekannt ist.
  Future<ChatSummary> getChat(String threadId) async {
    final chats = await _repository.getChats();
    return chats.firstWhere((c) => c.thread.id == threadId);
  }

  /// UC8 Schritt 3: Nachrichten in Echtzeit, älteste zuerst.
  Stream<List<Message>> watchMessages(String threadId) =>
      _repository.watchMessages(threadId);

  Future<Message> sendText(String threadId, String text) =>
      _repository.sendText(threadId, text.trim());

  Future<Message> sendPhoto(String threadId, File photo) =>
      _repository.sendPhoto(threadId, photo);

  /// UC8 Schritt 7: Deal abschliessen, nur der Käufer.
  Future<void> closeDeal(String threadId, int agreedPriceRappen) =>
      _repository.closeDeal(threadId, agreedPriceRappen);
}
