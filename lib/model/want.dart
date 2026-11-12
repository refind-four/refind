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

/// Zustände je Kategorie (Whitelist). Das Konzept legt nur die Uhren fest
/// («Original», «Serviciert», «Egal»), die übrigen hat das Team am
/// 12.11.2026 festgelegt (siehe ABWEICHUNGEN.md, Abschnitt 4).
/// Der letzte Wert ist die Vorauswahl.
const Map<String, List<String>> zustaende = {
  'Uhren': ['Original', 'Serviciert', 'Egal'],
  'Möbel': ['Wie neu', 'Gebraucht', 'Egal'],
  'Velo': ['Fahrbereit', 'Revisionsbedürftig', 'Egal'],
  'Vinyl': ['Neuwertig', 'Gebraucht (leichtes Knistern ok)', 'Egal'],
  'Kameras': ['Voll funktionsfähig', 'Mit Mängeln', 'Egal'],
  'Werkzeug': ['Neu', 'Gebraucht', 'Egal'],
};

/// Grenzwerte für Gesuche. Liegen im Paket model, weil Maske (Anwendungs-
/// schicht) und Repository (Datenzugriffsschicht) dieselben Werte prüfen.
class WantLimits {
  static const int maxTitleLength = 80;
  static const int maxDescriptionLength = 1000;

  /// Höchste Preisobergrenze: CHF 10'000 in Rappen. Im Konzept offen
  /// (Factsheet Inputvalidierung: «Maximalpreis noch offen»), vom Team am
  /// 12.11.2026 bestätigt.
  static const int maxBudgetRappen = 1000000;

  /// Schrittweite des Reglers in Rappen (CHF 50).
  static const int budgetStepRappen = 5000;

  /// UC3: Laufzeit vorbelegt mit 14 Tagen.
  static const int defaultDurationDays = 14;
  static const List<int> durationOptions = [7, 14, 30];
  static const List<int> radiusOptions = [10, 20, 30, 50, 100];

  /// Grösster erlaubter Umkreis. Der Profilwert (z.B. 25 km) muss nicht in
  /// [radiusOptions] stehen, aber in diesem Bereich liegen.
  static const int maxRadiusKm = 200;
}

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
