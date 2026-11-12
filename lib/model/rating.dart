/// Bewertung nach einem Abschluss. Jede Seite bewertet die andere
/// genau einmal (F-17).
class Rating {
  const Rating({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.threadId,
    required this.stars,
    required this.createdAt,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final String threadId;

  /// 1 bis 5 Sterne.
  final int stars;
  final DateTime createdAt;
}
