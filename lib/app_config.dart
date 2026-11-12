import 'data/mock_refind_repository.dart';
import 'data/refind_repository.dart';

/// Welche Umsetzung des RefindRepository beim Start aktiv ist
/// (Konzept 4.1: «eine Einstellung beim Start der App»).
enum RepositoryMode { mock, supabase }

/// Hier umstellen, sobald SupabaseRefindRepository existiert (KW 47).
const RepositoryMode repositoryMode = RepositoryMode.mock;

RefindRepository createRepository() {
  switch (repositoryMode) {
    case RepositoryMode.mock:
      return MockRefindRepository();
    case RepositoryMode.supabase:
      throw UnimplementedError('SupabaseRefindRepository folgt in KW 47.');
  }
}
