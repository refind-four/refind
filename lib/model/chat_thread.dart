/// Chat zu einem angenommenen Angebot (Konzept 2.1).
/// Hält Übergabe, vereinbarten Preis und Abschluss fest.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.offerId,
    required this.wantId,
    required this.buyerId,
    required this.sellerId,
    required this.lastActivity,
    this.handoverAt,
    this.handoverPlace,
    this.agreedPriceRappen,
    this.closedAt,
  });

  final String id;
  final String offerId;
  final String wantId;
  final String buyerId;
  final String sellerId;
  final DateTime lastActivity;
  final DateTime? handoverAt;
  final String? handoverPlace;
  final int? agreedPriceRappen;
  final DateTime? closedAt;

  bool get isClosed => closedAt != null;

  /// Die jeweils andere Person im Chat.
  String otherUserId(String myId) => myId == buyerId ? sellerId : buyerId;

  ChatThread copyWith({
    DateTime? lastActivity,
    DateTime? handoverAt,
    String? handoverPlace,
    int? agreedPriceRappen,
    DateTime? closedAt,
  }) {
    return ChatThread(
      id: id,
      offerId: offerId,
      wantId: wantId,
      buyerId: buyerId,
      sellerId: sellerId,
      lastActivity: lastActivity ?? this.lastActivity,
      handoverAt: handoverAt ?? this.handoverAt,
      handoverPlace: handoverPlace ?? this.handoverPlace,
      agreedPriceRappen: agreedPriceRappen ?? this.agreedPriceRappen,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
