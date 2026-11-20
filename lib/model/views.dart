// Hilfsklassen der Schnittstelle RefindRepository (Konzept 4.3.2).
// Sie enthalten Eingaben oder ergänzen eine Entität um Zähler oder
// Namen für die Anzeige.

import 'chat_thread.dart';
import 'message.dart';
import 'place.dart';
import 'want.dart';

/// Eingaben aus UC3 «Gesuch aufhängen».
class WantDraft {
  const WantDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.budgetMaxRappen,
    required this.condition,
    required this.regionId,
    required this.radiusKm,
    required this.durationDays,
  });

  final String title;
  final String category;
  final String description;
  final int budgetMaxRappen;
  final String condition;
  final int regionId;
  final int radiusKm;

  /// Laufzeit des Gesuchs in Tagen.
  final int durationDays;
}

/// Filter aus UC5 «Entdecken, suchen und filtern».
class FeedFilter {
  const FeedFilter({this.query, this.category, this.placeId, this.radiusKm});

  final String? query;
  final String? category;
  final int? placeId;
  final int? radiusKm;
}

/// Eigenes Gesuch mit Zählern für Angebote und Ortschaft (UC4).
class WantSummary {
  const WantSummary({
    required this.want,
    required this.offerCount,
    required this.newOfferCount,
    required this.region,
    this.hasAcceptedOffer = false,
  });

  final Want want;
  final int offerCount;
  final int newOfferCount;

  /// Ist ein Angebot angenommen? Dann läuft das Gesuch nicht mehr ab und
  /// lässt sich nicht mehr pausieren oder nochmal aufhängen (UC4, Ausnahme).
  final bool hasAcceptedOffer;

  /// Region des Gesuchs, damit die Karte «Bern» statt einer Nummer zeigt.
  final Place region;
}

/// Gesuch im Feed mit Name des Käufers und Ortschaft (UC5).
class FeedItem {
  const FeedItem({
    required this.want,
    required this.buyerName,
    required this.region,
    this.distanceKm,
  });

  final Want want;
  final String buyerName;
  final Place region;

  /// Distanz zur gefilterten Ortschaft, falls ein Ort gewählt ist.
  final double? distanceKm;
}

/// Chat in der Chatliste (UC8).
class ChatSummary {
  const ChatSummary({
    required this.thread,
    required this.otherUserName,
    required this.wantTitle,
    required this.unreadCount,
    this.lastMessage,
  });

  final ChatThread thread;
  final String otherUserName;
  final String wantTitle;
  final int unreadCount;
  final Message? lastMessage;
}

/// Kennzahlen eines Kontos (Sicht profile_stats, Konzept 4.2.4).
class ProfileStats {
  const ProfileStats({
    required this.averageStars,
    required this.dealCount,
    required this.activeWantCount,
  });

  /// Durchschnittsbewertung, leer ohne Bewertungen.
  final double? averageStars;
  final int dealCount;
  final int activeWantCount;
}
