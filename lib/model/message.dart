/// Art einer Nachricht (F-13).
enum MessageKind { text, foto }

/// Nachricht im Chat (Konzept 2.1). Bei [MessageKind.foto] enthält
/// [body] die Adresse des Fotos.
class Message {
  const Message({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String threadId;
  final String senderId;
  final MessageKind kind;
  final String body;
  final DateTime createdAt;

  /// Zeitpunkt, zu dem der Empfänger die Nachricht gelesen hat (F-14).
  final DateTime? readAt;

  Message copyWith({DateTime? readAt}) {
    return Message(
      id: id,
      threadId: threadId,
      senderId: senderId,
      kind: kind,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
