import 'dart:io';

import '../../data/refind_repository.dart';
import '../../data/repository_exception.dart';
import '../../model/model.dart';

/// Abläufe rund um Angebote (Konzept 4.2.2, UC5 bis UC7).
/// Spricht nur mit der Schnittstelle RefindRepository.
class OfferService {
  OfferService(this._repository);

  final RefindRepository _repository;

  /// Gesuche anderer Personen (UC5). Wird vorläufig für «Angebot senden»
  /// gebraucht, bis die Maske «Entdecken» fertig ist.
  Future<List<FeedItem>> getFeed(FeedFilter filter) => _repository.getFeed(filter);

  /// UC6: Angebot mit Preis (Rappen), Nachricht und höchstens drei Fotos.
  Future<Offer> createOffer(
    String wantId,
    int priceRappen,
    String message,
    List<File> photos,
  ) =>
      _repository.createOffer(wantId, priceRappen, message.trim(), photos);

  /// UC7: Angebote zu einem eigenen Gesuch.
  Future<List<Offer>> getOffers(String wantId, OfferSort sort) =>
      _repository.getOffers(wantId, sort);

  /// UC7: neue Angebote als «gesehen» markieren. Klappt das nicht (z.B.
  /// kein Netz), ist das nicht schlimm: Beim nächsten Öffnen wird es
  /// nochmals versucht. Darum wird der Fehler hier nicht weitergegeben.
  Future<void> markOffersSeen(String wantId) async {
    try {
      await _repository.markOffersSeen(wantId);
    } on RepositoryException {
      // bewusst ignoriert, siehe oben
    }
  }

  /// UC7 / F-12: Angebot annehmen. Liefert den neuen Chat.
  Future<ChatThread> acceptOffer(String offerId) => _repository.acceptOffer(offerId);
}
