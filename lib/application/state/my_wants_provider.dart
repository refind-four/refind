import 'package:flutter/foundation.dart';

import '../../data/repository_exception.dart';
import '../../model/model.dart';
import '../services/want_service.dart';

/// Eigene Gesuche mit Zählern für Angebote (Konzept 4.2.2, UC3, UC4).
/// «Meine Gesuche» hört zu und zeigt die Liste neu, sobald [load] fertig ist.
class MyWantsProvider extends ChangeNotifier {
  MyWantsProvider(this._service);

  final WantService _service;

  List<WantSummary> _wants = const [];
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  List<WantSummary> get wants => _wants;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _wants = await _service.getMyWants();
    } on RepositoryException catch (e) {
      _error = e.kind == RepositoryErrorKind.keineVerbindung
          ? 'Keine Verbindung. Ziehe die Liste nach unten, um es nochmals zu versuchen.'
          : e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  // Nach dem Abmelden wird der Provider entsorgt. Eine Antwort, die erst
  // danach eintrifft, darf ihn nicht mehr benachrichtigen.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
