import 'photo.dart';
import 'want.dart';

/// Status eines Angebots (Konzept Abbildung 2).
enum OfferStatus { neu, gesehen, angenommen, abgesagt }

/// Sortierung der Angebotsliste eines Gesuchs (UC7 Schritt 3, F-10, TC18):
/// «Preis aufsteigend, Preis absteigend oder nach Eingang». Bei gleichem
/// Preis steht das neuere Angebot zuerst.
enum OfferSort { neueste, guenstigste, teuerste }

/// Grenzwerte für Angebote (UC6, F-09). Liegen im Paket model, weil Maske
/// und Repository dieselben Werte prüfen (wie [WantLimits]).
class OfferLimits {
  /// F-09: höchstens drei Fotos pro Angebot.
  static const int maxPhotos = 3;

  /// Nachricht ist freiwillig, aber nicht beliebig lang (Vorschlag).
  static const int maxMessageLength = 500;

  /// Höchster Preis: wie die höchste Preisobergrenze, CHF 10'000 (Vorschlag).
  static const int maxPriceRappen = WantLimits.maxBudgetRappen;

  /// Grösstes Foto: 5 MB. Derselbe Wert steht als file_size_limit am
  /// Bucket (supabase/13_speicher.sql). Die App verkleinert Fotos beim
  /// Auswählen auf 1600 px, damit sind sie meist unter 1 MB.
  static const int maxPhotoBytes = 5 * 1024 * 1024;
}

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
    this.sellerName,
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

  /// Anzeigename des Verkäufers, zur Anzeige mitgeladen (Ergänzung).
  final String? sellerName;

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
      sellerName: sellerName,
    );
  }
}
