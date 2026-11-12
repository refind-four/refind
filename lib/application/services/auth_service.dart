import '../../data/refind_repository.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';

/// Abläufe zum Registrieren, Anmelden und Abmelden (Konzept 4.2.2, UC1).
/// Spricht nur mit der Schnittstelle RefindRepository, nie direkt mit
/// Supabase. Darum funktioniert er mit Mock und Supabase gleich.
class AuthService {
  AuthService(this._repository);

  final RefindRepository _repository;

  Future<void> signUp(String displayName, String email, String password) =>
      _repository.signUp(displayName.trim(), email.trim(), password);

  Future<User> signIn(String email, String password) =>
      _repository.signIn(email.trim(), password);

  Future<void> resendConfirmation(String email) =>
      _repository.resendConfirmation(email.trim());

  Future<void> signOut() => _repository.signOut();

  /// Liefert das Profil, wenn noch eine gültige Sitzung besteht, sonst null.
  /// UC1 Schritt 1: mit gültiger Sitzung direkt «Meine Gesuche».
  Future<User?> restoreSession() async {
    try {
      return await _repository.getMyProfile();
    } on RepositoryException catch (e) {
      if (e.kind == RepositoryErrorKind.nichtBerechtigt) return null;
      rethrow;
    }
  }

  // Folgt mit Firebase (UC1 Schritt 8): Erlaubnis für Mitteilungen
  // abfragen und Pushtoken mit registerPushToken anmelden.
}
