import 'dart:math';

/// Ortschaft aus dem Ortschaftenverzeichnis von swisstopo (Konzept 2.1).
/// Koordinaten im Schweizer Landeskoordinatensystem LV95.
class Place {
  const Place({
    required this.id,
    required this.plz,
    required this.name,
    required this.e,
    required this.n,
  });

  final int id;
  final int plz;
  final String name;

  /// Ost-Koordinate LV95 in Metern.
  final int e;

  /// Nord-Koordinate LV95 in Metern.
  final int n;

  /// Distanz in Kilometern nach dem Satz des Pythagoras (Konzept 4.2.3).
  double distanceKmTo(Place other) {
    final de = (e - other.e).toDouble();
    final dn = (n - other.n).toDouble();
    return sqrt(de * de + dn * dn) / 1000;
  }

  /// Anzeige wie «3011 Bern».
  String get label => '$plz $name';
}
