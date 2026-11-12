/// Profil einer Person, die kauft und verkauft (Konzept 2.1).
/// Mailadresse und Passwort führt der Anmeldedienst, nicht diese Klasse.
class User {
  const User({
    required this.id,
    required this.displayName,
    required this.cityId,
    required this.radiusKm,
    required this.memberSince,
    this.avatarUrl,
  });

  final String id;
  final String displayName;

  /// Wohnort, Verweis auf [Place]. Leer, solange das Profil nicht ergänzt ist.
  final int? cityId;
  final String? avatarUrl;

  /// Vorbelegter Umkreis beim Erfassen und Filtern (UC3, UC5).
  final int radiusKm;
  final DateTime memberSince;

  User copyWith({
    String? displayName,
    int? cityId,
    String? avatarUrl,
    int? radiusKm,
  }) {
    return User(
      id: id,
      displayName: displayName ?? this.displayName,
      cityId: cityId ?? this.cityId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      radiusKm: radiusKm ?? this.radiusKm,
      memberSince: memberSince,
    );
  }
}
