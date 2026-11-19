import '../../model/model.dart';

/// FilterLogic (Konzept 4.2.2, UC5): Suchbegriff, Kategorie und Distanz
/// zwischen zwei Ortschaften. Reine Fachlogik ohne Netz, darum mit
/// Unittests prüfbar (N-08). Mock und Supabase benutzen dieselben Regeln.
class FilterLogic {
  FilterLogic._();

  /// Längster erlaubter Suchbegriff. Ein Titel hat höchstens 80 Zeichen,
  /// ein längerer Suchbegriff könnte also nie passen.
  static const int maxQueryLength = WantLimits.maxTitleLength;

  /// Suchbegriff vereinheitlichen: Leerzeichen am Rand weg, mehrere
  /// Leerzeichen zu einem, Kleinbuchstaben. «  LEICA   M6 » → «leica m6».
  /// Leer oder null → '' (= kein Suchbegriff).
  static String normalizeQuery(String? query) {
    if (query == null) return '';
    return query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  /// F-07: Der Titel enthält den Suchbegriff, ohne Rücksicht auf Gross- und
  /// Kleinschreibung. Ohne Suchbegriff passt jeder Titel.
  static bool matchesQuery(String title, String? query) {
    final q = normalizeQuery(query);
    if (q.isEmpty) return true;
    final t = title.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    return t.contains(q);
  }

  /// F-06: Gesuch gehört zur gewählten Kategorie. Keine Kategorie → alle.
  static bool matchesCategory(String category, String? selected) =>
      selected == null || category == selected;

  /// F-08: Region liegt höchstens [radiusKm] von [origin] entfernt.
  /// Genau auf der Grenze zählt noch dazu («höchstens», UC5 Schritt 5).
  /// Ohne Ortschaft oder ohne Umkreis passt jede Region.
  static bool isWithinRadius(Place region, Place? origin, int? radiusKm) {
    if (origin == null || radiusKm == null) return true;
    return origin.distanceKmTo(region) <= radiusKm;
  }

  /// F-06: Darf das Gesuch im Feed von [viewerId] erscheinen?
  /// Nur aktive, nicht abgelaufene Gesuche anderer Konten ohne
  /// angenommenes Angebot. Läuft es genau jetzt ab, ist es schon weg
  /// (wie die RLS-Regel want_select: expires_at > now()).
  static bool isVisibleInFeed(
    Want want, {
    required String viewerId,
    required DateTime now,
    required bool hasAcceptedOffer,
  }) {
    return want.ownerId != viewerId &&
        want.status == WantStatus.aktiv &&
        want.expiresAt.isAfter(now) &&
        !hasAcceptedOffer;
  }

  /// Passt ein Eintrag zu allen gewählten Filtern?
  static bool matches(FeedItem item, FeedFilter filter, {Place? origin}) {
    return matchesCategory(item.want.category, filter.category) &&
        matchesQuery(item.want.title, filter.query) &&
        isWithinRadius(item.region, origin, filter.radiusKm);
  }

  /// Filtert und sortiert: das neueste Gesuch zuerst (UC5 Schritt 1).
  static List<FeedItem> apply(
    Iterable<FeedItem> items,
    FeedFilter filter, {
    Place? origin,
  }) {
    return items.where((i) => matches(i, filter, origin: origin)).toList()
      ..sort((a, b) => b.want.createdAt.compareTo(a.want.createdAt));
  }

  /// Ist mindestens ein Filter gesetzt? Dann bietet die Maske bei einer
  /// leeren Liste «Filter zurücksetzen» an (UC5, Ausnahme).
  static bool hasActiveFilter(FeedFilter filter) =>
      normalizeQuery(filter.query).isNotEmpty ||
      filter.category != null ||
      (filter.placeId != null && filter.radiusKm != null);
}
