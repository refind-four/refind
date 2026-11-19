import '../../data/refind_repository.dart';
import '../../model/model.dart';
import '../logic/filter_logic.dart';

/// Feed «Entdecken» (Konzept 4.2.2, UC5). Spricht nur mit der
/// Schnittstelle RefindRepository.
///
/// Das Repository liefert schon nur sichtbare Gesuche (bei Supabase prüft
/// das die Datenbank, siehe supabase/09_feed.sql). Der Service wendet danach
/// die FilterLogic an. So gelten in der App immer dieselben Regeln, egal ob
/// Mock oder Supabase dahintersteht.
class FeedService {
  FeedService(this._repository);

  final RefindRepository _repository;

  Future<List<FeedItem>> getFeed(
    FeedFilter filter, {
    required String viewerId,
    DateTime? now,
  }) async {
    final items = await _repository.getFeed(filter);
    final placeId = filter.placeId;
    final origin = placeId == null ? null : await _repository.getPlace(placeId);
    final at = now ?? DateTime.now();

    // Zweite Sicherung: eigene, pausierte oder inzwischen abgelaufene
    // Gesuche nie anzeigen. Angenommene Angebote kann nur die Datenbank
    // prüfen, darum hier false.
    final visible = items.where((i) => FilterLogic.isVisibleInFeed(
          i.want,
          viewerId: viewerId,
          now: at,
          hasAcceptedOffer: false,
        ));
    return FilterLogic.apply(visible, filter, origin: origin);
  }

  Future<List<Place>> searchPlaces(String query) => _repository.searchPlaces(query);
}
