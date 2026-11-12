/// Status eines Gesuchs (Konzept Abbildung 2).
enum WantStatus { aktiv, pausiert, abgelaufen, erledigt }

/// Die sechs Kategorien aus dem visuellen Konzept (Konzept 2.1).
const List<String> kategorien = [
  'Uhren',
  'Möbel',
  'Velo',
  'Vinyl',
  'Kameras',
  'Werkzeug',
];

/// Gesuch eines Käufers (Konzept 2.1). Beträge in ganzen Rappen.
class Want {
  const Want({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.category,
    required this.description,
    required this.budgetMaxRappen,
    required this.condition,
    required this.regionId,
    required this.radiusKm,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
  });

  final String id;
  final String ownerId;
  final String title;
  final String category;
  final String description;
  final int budgetMaxRappen;
  final String condition;

  /// Region, Verweis auf [Place].
  final int regionId;
  final int radiusKm;
  final DateTime createdAt;
  final DateTime expiresAt;
  final WantStatus status;

  Want copyWith({
    String? title,
    String? category,
    String? description,
    int? budgetMaxRappen,
    String? condition,
    int? regionId,
    int? radiusKm,
    DateTime? expiresAt,
    WantStatus? status,
  }) {
    return Want(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      budgetMaxRappen: budgetMaxRappen ?? this.budgetMaxRappen,
      condition: condition ?? this.condition,
      regionId: regionId ?? this.regionId,
      radiusKm: radiusKm ?? this.radiusKm,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }
}
