import 'dart:io';

import '../model/model.dart';

/// Interne Schnittstelle I2 zwischen Anwendungsschicht und Daten
/// (Konzept 4.3.2). Alle Methoden sind asynchron und werfen bei einem
/// Fehler eine RepositoryException. Beträge sind ganze Rappen.
///
/// Umsetzungen:
/// * MockRefindRepository: Testdaten im Speicher, ohne Netz
/// * SupabaseRefindRepository: Betrieb über Supabase (folgt später)
abstract interface class RefindRepository {
  // --- Konto (UC1, UC2) ---

  /// Konto anlegen, Bestätigungsmail auslösen.
  Future<void> signUp(String displayName, String email, String password);

  /// Anmelden und Sitzung speichern.
  Future<User> signIn(String email, String password);

  /// Bestätigungsmail erneut senden (UC1, Ausnahme «nicht bestätigt»).
  /// Ergänzung zu Konzept 4.3.2. Verrät nicht, ob es das Konto gibt.
  Future<void> resendConfirmation(String email);

  /// Ergebnis des Bestätigungslinks aus der Mail (UC1 Schritt 5, TC01).
  /// Der Link öffnet die App (Deep Link) und meldet an, ohne signIn.
  /// true: angemeldet. false: Link ungültig oder abgelaufen.
  /// Ergänzung zu Konzept 4.3.2.
  Stream<bool> get confirmationLinkResults;

  /// Pushtoken des Geräts speichern.
  Future<void> registerPushToken(String token);

  /// Abmelden und Pushtoken entfernen.
  Future<void> signOut();

  /// Eigenes Profil laden.
  Future<User> getMyProfile();

  /// Profil ändern.
  Future<User> updateProfile(
    String displayName,
    int cityId,
    int radiusKm,
    File? avatar,
  );

  /// Konto mit allen Daten löschen.
  Future<void> deleteAccount();

  /// Ortschaften für Wohnort und Region suchen.
  Future<List<Place>> searchPlaces(String query);

  /// Eine Ortschaft lesen, z.B. den Wohnort für die Vorbelegung in UC3.
  /// Ergänzung zu Konzept 4.3.2.
  Future<Place> getPlace(int placeId);

  // --- Gesuche (UC3, UC4) ---

  Future<Want> createWant(WantDraft draft);
  Future<List<WantSummary>> getMyWants();
  Future<Want> updateWant(String wantId, WantDraft draft);

  /// Pausieren oder aktivieren.
  Future<void> setWantStatus(String wantId, WantStatus status);

  /// Abgelaufenes Gesuch erneut veröffentlichen.
  Future<Want> republishWant(String wantId);

  // --- Entdecken und Angebote (UC5 bis UC7) ---

  Future<List<FeedItem>> getFeed(FeedFilter filter);
  Future<Offer> createOffer(
    String wantId,
    int priceRappen,
    String message,
    List<File> photos,
  );
  Future<List<Offer>> getOffers(String wantId, OfferSort sort);
  Future<void> markOffersSeen(String wantId);
  Future<ChatThread> acceptOffer(String offerId);

  // --- Chat, Abschluss, Bewertung (UC8, UC9) ---

  Future<List<ChatSummary>> getChats();

  /// Nachrichten eines Chats in Echtzeit.
  Stream<List<Message>> watchMessages(String threadId);
  Future<Message> sendText(String threadId, String text);
  Future<Message> sendPhoto(String threadId, File photo);
  Future<void> markRead(String threadId);
  Future<void> setHandover(String threadId, DateTime at, String place);
  Future<void> closeDeal(String threadId, int agreedPriceRappen);
  Future<void> rateUser(String threadId, int stars);
  Future<ProfileStats> getProfileStats(String userId);
}
