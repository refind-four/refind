import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/mock_refind_repository.dart';
import 'data/refind_repository.dart';
import 'data/supabase_refind_repository.dart';

/// Welche Umsetzung des RefindRepository beim Start aktiv ist
/// (Konzept 4.1: «eine Einstellung beim Start der App»).
enum RepositoryMode { mock, supabase }

/// Hier umschalten:
/// * [RepositoryMode.mock]: Testdaten im Speicher, ohne Internet
///   (Konten anna/ben/cara@refind.test, Passwort refind123, wie 05_testdaten.sql)
/// * [RepositoryMode.supabase]: echtes Backend, braucht Internet
///
/// Nach dem Umschalten genügt Hot Reload nicht, weil main() neu laufen
/// muss: im Terminal von `flutter run` ein grosses `R` drücken.
/// Die Tests benutzen immer das Mock.
const RepositoryMode repositoryMode = RepositoryMode.supabase;

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

  /// Bucket in Supabase Storage für die Fotos der Angebote (UC6, F-09).
  /// Noch leer: Etienne richtet die Dateiablage bis 26.11.2026 ein. Bis
  /// dahin werden Angebote ohne Fotos gespeichert. Danach hier den Namen
  /// eintragen, z.B. 'offer-photos'.
  static const String? offerPhotoBucket = null;
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
      // initBackend() hat Supabase vorher eingerichtet.
      return SupabaseRefindRepository(
        Supabase.instance.client,
        photoBucket: SupabaseConfig.offerPhotoBucket,
      );
  }
}
