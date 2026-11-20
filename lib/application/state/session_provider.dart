import 'dart:async';

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
  SessionProvider(this._auth) {
    _linkSubscription = _auth.confirmationLinkResults.listen(_onConfirmationLink);
  }

  final AuthService _auth;
  late final StreamSubscription<bool> _linkSubscription;

  SessionStatus _status = SessionStatus.unbekannt;
  User? _user;
  String? _linkNotice;

  SessionStatus get status => _status;
  User? get user => _user;

  /// Hinweis für «Anmelden», wenn der Bestätigungslink nicht geklappt hat.
  String? get linkNotice => _linkNotice;

  /// UC1 Schritt 5: Der Link aus der Mail hat die App geöffnet. Bei Erfolg
  /// ist die Sitzung schon da: Profil laden, SessionGate zeigt dann «Meine
  /// Gesuche». Ein angemeldeter Nutzer (signedIn nach signIn) bleibt so.
  Future<void> _onConfirmationLink(bool success) async {
    if (success) {
      if (_status == SessionStatus.angemeldet) return;
      _linkNotice = null;
      await restore();
    } else {
      _linkNotice = confirmationLinkFailedMessage;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _linkSubscription.cancel();
    super.dispose();
  }

  Future<void> restore() async {
    try {
      _setUser(await _auth.restoreSession());
    } catch (_) {
      // Ohne Verbindung beim Start: zur Anmeldung, dort gibt es eine Meldung.
      _setUser(null);
    }
  }

  Future<void> signIn(String email, String password) async {
    final user = await _auth.signIn(email, password);
    _linkNotice = null;
    _setUser(user);
  }

  Future<void> signUp(String displayName, String email, String password) =>
      _auth.signUp(displayName, email, password);

  Future<void> resendConfirmation(String email) => _auth.resendConfirmation(email);

  Future<void> signOut() async {
    await _auth.signOut();
    _setUser(null);
  }

  /// UC2, TC06: Konto löschen, danach zeigt SessionGate «Anmelden».
  Future<void> deleteAccount() async {
    await _auth.deleteAccount();
    _setUser(null);
  }

  void _setUser(User? user) {
    _user = user;
    _status = user == null ? SessionStatus.abgemeldet : SessionStatus.angemeldet;
    notifyListeners();
  }
}

/// Meldung, wenn der Bestätigungslink nicht geklappt hat (abgelaufen, schon
/// benutzt oder auf einem anderen Gerät angefordert). Die Mailadresse kann
/// trotzdem bestätigt sein: Supabase prüft den Link, bevor er die App öffnet.
const String confirmationLinkFailedMessage =
    'Der Link hat nicht geklappt. Ist deine Mailadresse schon bestätigt, '
    'melde dich hier an. Sonst lass dir die Mail nochmals senden.';
