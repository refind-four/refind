import '../../data/refind_repository.dart';
import '../../model/model.dart';

/// Abläufe rund um Gesuche (Konzept 4.2.2, UC3 und UC4).
/// Spricht nur mit der Schnittstelle RefindRepository.
class WantService {
  WantService(this._repository);

  final RefindRepository _repository;

  Future<Want> createWant(WantDraft draft) => _repository.createWant(draft);

  Future<List<WantSummary>> getMyWants() => _repository.getMyWants();

  /// UC4 Schritt 3: Pausieren oder Aktivieren. Gibt das Gesuch mit dem
  /// neuen Status zurück, damit die Maske es gleich anzeigen kann.
  Future<Want> setWantStatus(Want want, WantStatus status) async {
    await _repository.setWantStatus(want.id, status);
    return want.copyWith(status: status);
  }

  /// UC4 Schritt 6: Nochmal aufhängen (14 Tage ab heute, Status aktiv).
  Future<Want> republishWant(Want want) => _repository.republishWant(want.id);

  Future<List<Place>> searchPlaces(String query) => _repository.searchPlaces(query);

  /// Wohnort für die Vorbelegung der Region (UC3 Schritt 4).
  /// Neue Konten haben noch keinen Wohnort, dann bleibt die Region leer.
  Future<Place?> homePlace(User user) async {
    final cityId = user.cityId;
    if (cityId == null) return null;
    return _repository.getPlace(cityId);
  }
}
