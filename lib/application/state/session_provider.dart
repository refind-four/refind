import 'package:flutter/foundation.dart';

import '../../model/model.dart';
import '../services/auth_service.dart';

enum SessionStatus {
  /// Beim Start, solange noch geprüft wird, ob eine Sitzung besteht.
  unbekannt,
  abgemeldet,
  angemeldet,
}

/// Hält die Sitzung und den angemeldeten Nutzer (Konzept 4.2.2).
/// Ändert sich etwas, ruft er notifyListeners() auf, und alle Masken, die
/// zuhören, bauen sich neu auf. So wechselt die App nach dem Anmelden von
/// selbst zu «Meine Gesuche» und nach dem Abmelden zurück zu «Anmelden».
///
/// Fehler (RepositoryException) gibt er an die Maske weiter, damit sie
/// die passende Meldung neben den Eingaben anzeigen kann.
class SessionProvider extends ChangeNotifier {
  SessionProvider(this._auth);

  final AuthService _auth;

  SessionStatus _status = SessionStatus.unbekannt;
  User? _user;

  SessionStatus get status => _status;
  User? get user => _user;

  Future<void> restore() async {
    try {
      _setUser(await _auth.restoreSession());
    } catch (_) {
      // Ohne Verbindung beim Start: zur Anmeldung, dort gibt es eine Meldung.
      _setUser(null);
    }
  }

  Future<void> signIn(String email, String password) async {
    _setUser(await _auth.signIn(email, password));
  }

  Future<void> signUp(String displayName, String email, String password) =>
      _auth.signUp(displayName, email, password);

  Future<void> resendConfirmation(String email) => _auth.resendConfirmation(email);

  Future<void> signOut() async {
    await _auth.signOut();
    _setUser(null);
  }

  void _setUser(User? user) {
    _user = user;
    _status = user == null ? SessionStatus.abgemeldet : SessionStatus.angemeldet;
    notifyListeners();
  }
}
