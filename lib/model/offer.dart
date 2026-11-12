import 'photo.dart';

/// Status eines Angebots (Konzept Abbildung 2).
enum OfferStatus { neu, gesehen, angenommen, abgesagt }

/// Sortierung der Angebotsliste eines Gesuchs (UC7).
enum OfferSort { neueste, guenstigste }

/// Angebot eines Verkäufers zu einem Gesuch (Konzept 2.1).
class Offer {
  const Offer({
    required this.id,
    required this.wantId,
    required this.sellerId,
    required this.priceRappen,
    required this.message,
    required this.createdAt,
    required this.status,
    this.photos = const [],
  });

  final String id;
  final String wantId;
  final String sellerId;
  final int priceRappen;
  final String message;
  final DateTime createdAt;
  final OfferStatus status;

  /// Zugehörige Fotos (höchstens drei, F-09), zur Anzeige mitgeladen.
  final List<Photo> photos;

  Offer copyWith({OfferStatus? status}) {
    return Offer(
      id: id,
      wantId: wantId,
      sellerId: sellerId,
      priceRappen: priceRappen,
      message: message,
      createdAt: createdAt,
      status: status ?? this.status,
      photos: photos,
    );
  }
}
