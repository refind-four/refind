import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/mock_refind_repository.dart';
import 'data/refind_repository.dart';

/// Welche Umsetzung des RefindRepository beim Start aktiv ist
/// (Konzept 4.1: «eine Einstellung beim Start der App»).
enum RepositoryMode { mock, supabase }

/// Hier umstellen, sobald SupabaseRefindRepository existiert.
const RepositoryMode repositoryMode = RepositoryMode.mock;

/// Verbindung zu unserem Supabase-Projekt. Steht nur hier, nirgends sonst.
///
/// Der publishableKey ist kein Geheimnis: Er steckt in jeder App, die
/// ausgeliefert wird, und darf nur das, was die RLS-Regeln
/// (supabase/02_rls_regeln) erlauben. Der geheime service_role-Schlüssel
/// gehört NIE in die App.
class SupabaseConfig {
  static const String url = 'https://sngoydgogjondrnrnxam.supabase.co';
  static const String publishableKey =
      'sb_publishable_h3FoHWhSjMaR6vpQOP-eGQ__mV15SiE';
}

/// Bereitet das Backend vor. Wird in main() vor runApp aufgerufen.
/// Im Mock-Modus passiert nichts, so startet die App auch ohne Internet.
Future<void> initBackend() async {
  if (repositoryMode == RepositoryMode.supabase) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
}

RefindRepository createRepository() {
  switch (repositoryMode) {
    case RepositoryMode.mock:
      return MockRefindRepository();
    case RepositoryMode.supabase:
      throw UnimplementedError('SupabaseRefindRepository folgt im nächsten Schritt.');
  }
}
