# refind – Fakten zur Realisierung

Stand: 20.11.2026 (KW 47), Commit-Stand nach «Profil ohne Platzhalter, F-08».
Zweck: Nachschlagewerk für den Realisierungsbericht. Abweichungen vom Konzept
stehen mit Begründung in `ABWEICHUNGEN.md` (Verweise wie «ABW 12.3»).

Abkürzungen: UC = Anwendungsfall, F/N = Anforderung, TC = Testfall,
RLS = Row Level Security (Zugriffsregeln je Zeile in PostgreSQL).

---

## 1. Dateien unter `lib/` nach Schicht

Schichten nach Konzept Kapitel 4: Präsentation → Anwendung → Datenzugriff.
Das Paket `model` benutzen alle Schichten.

### Start und Konfiguration

| Datei | Aufgabe |
|---|---|
| `main.dart` | Startet die App: bereitet das Backend vor (`initBackend`) und zeigt `RefindApp` mit dem gewählten Repository. |
| `app_config.dart` | Umschalter Mock/Supabase, Supabase-URL und publishableKey, Bucket-Namen und Deep-Link-Adresse an einer Stelle. |

### Präsentationsschicht (`presentation/`)

| Datei | Aufgabe |
|---|---|
| `app.dart` | Wurzel der App: stellt Services und SessionProvider bereit und wählt mit `SessionGate` «Anmelden» oder «Meine Gesuche». |
| `home_shell.dart` | Navigationsleiste mit den vier Bereichen GESUCHE, ENTDECKEN, CHAT, PROFIL; lädt die Chatliste beim Wechsel zu CHAT neu. |
| `theme.dart` | Farben, Schriften und Stile aus dem visuellen Konzept. |
| `account/login_screen.dart` | Maske «Anmelden» (UC1) mit «Mail erneut senden» und Hinweis, wenn der Bestätigungslink nicht geklappt hat. |
| `account/register_screen.dart` | Maske «Registrieren» (UC1): Anzeigename, Mailadresse, Passwort zweimal. |
| `account/profile_screen.dart` | Startmaske «Profil» (UC2): Anzeigename, Wohnort mit Suchradius, Mailadresse, «Profil bearbeiten». |
| `account/profile_edit_screen.dart` | «Profil bearbeiten» (UC2): Name und Mail (nur lesen), «Abmelden», «Konto löschen» mit Eingabe «LÖSCHEN». |
| `wants/my_wants_screen.dart` | «Meine Gesuche» (UC4): Karten mit Status oder Laufzeit, eigene Karte für abgelaufene Gesuche mit «Nochmal aufhängen?». |
| `wants/want_wizard_screen.dart` | «Gesuch aufhängen» in vier Schritten (UC3) mit Prüfung jedes Schritts. |
| `wants/want_option_sheets.dart` | Sheets «Region & Umkreis» (Ortssuche, Umkreis) und «Wie lange sichtbar?» (Laufzeit). |
| `wants/want_detail_screen.dart` | «Gesuch Detail · Angebote» (UC4, UC7): Pausieren/Aktivieren/Nochmal aufhängen, drei Sortierungen, «über Budget», «Annehmen». |
| `wants/want_status_label.dart` | Statustext oben rechts («● LIVE · 5 TAGE», «PAUSIERT», «ABGELAUFEN» …) nach der StatusLogic. |
| `discover/discover_screen.dart` | «Entdecken» (UC5): Suchfeld, Kategorie-Leiste, Feed mit Ladezustand und «Filter zurücksetzen». |
| `discover/feed_card.dart` | Karte eines Gesuchs im Feed: Käufer, Zeit seit Erfassung, Titel, Beschreibung, Preis, Region, «Angebot senden». |
| `discover/filter_sheet.dart` | Sheet «Suchen und filtern»: Suchbegriff, Kategorie, Region und Umkreis (F-07, F-08). |
| `discover/offer_compose_sheet.dart` | Sheet «Angebot senden» (UC6): Preis, Nachricht, bis zu drei Fotos aus Kamera oder Galerie. |
| `chat/chat_list_screen.dart` | «Chats» (UC8 Schritt 1): Gegenüber, letzte Nachricht, Gesuch, Preis, Zeit. |
| `chat/chat_screen.dart` | «Chat · Verhandlung» (UC8): Nachrichten in Echtzeit, Text und Fotos senden, «Deal» für den Käufer. |
| `chat/deal_sheet.dart` | Sheet «Deal abschliessen»: Preis prüfen (vorbelegt mit Angebotspreis) und bestätigen. |
| `chat/deal_screen.dart` | «Deal bestätigt» («Gefunden.») mit Preis, Gegenstand und Gegenüber. |
| `chat/handover_sheet.dart` | Platzhalter «Übergabe festhalten» (F-15), nirgends verlinkt. |
| `chat/rating_sheet.dart` | Platzhalter «Bewertung abgeben» (F-17), nirgends verlinkt. |
| `widgets/choice_chips.dart` | Auswahl-Chips (Kategorien, Zustände, Umkreis) mit Fehlermarkierung. |
| `widgets/connection_error.dart` | Einheitliche Meldung bei fehlender Verbindung mit «Nochmals versuchen» und Text für unerwartete Fehler. |
| `widgets/form_fields.dart` | Beschriftetes Feld, Passwortfeld mit «anzeigen», Knopf mit Ladekreisel. |
| `widgets/offer_photo.dart` | Quadratisches Foto (Link oder Datei), auf Wunsch gross antippbar. |
| `widgets/placeholder_screen.dart` | Vorlage für Platzhalter-Masken; wird nur noch von den zwei unverlinkten Sheets benutzt. |

### Anwendungsschicht (`application/`)

| Datei | Aufgabe |
|---|---|
| `logic/account_rules.dart` | Eingaberegeln für Anmelden und Registrieren (Name, Mail, Passwort, Wiederholung). |
| `logic/want_rules.dart` | Eingaberegeln für «Gesuch erfassen» (Titel, Kategorie, Beschreibung, Budget, Zustand, Region). |
| `logic/offer_rules.dart` | Regeln für Angebote: Preis lesen und prüfen, Nachricht, max. 3 Fotos, «über Budget», wer annehmen darf. |
| `logic/price_logic.dart` | PriceLogic: Rappen ↔ Franken und Schweizer Format «CHF 1'650». |
| `logic/status_logic.dart` | StatusLogic: erlaubte Übergänge nach Abbildung 2, «abgelaufen», erlaubte Knöpfe, Laufzeit. |
| `logic/filter_logic.dart` | FilterLogic: Suchbegriff im Titel, Kategorie, Umkreis (Pythagoras LV95), Sichtbarkeit im Feed. |
| `logic/time_logic.dart` | Zeittexte: «vor 20 Min», verbleibende Laufzeit «14 Tage», Zeit in der Chatliste. |
| `logic/chat_rules.dart` | Chatregeln: Länge der Textnachricht, wer «Deal» wählen darf. |
| `services/auth_service.dart` | Abläufe Registrieren, Anmelden, Abmelden, Sitzung wiederherstellen, Mailadresse, Konto löschen. |
| `services/want_service.dart` | Abläufe für Gesuche: erfassen, eigene laden, Ortssuche, Wohnort, Pausieren/Aktivieren/Nochmal aufhängen. |
| `services/feed_service.dart` | Feed: lädt vom Repository und wendet die FilterLogic an (inkl. Umkreis). |
| `services/offer_service.dart` | Abläufe für Angebote: senden, laden, gesehen markieren, annehmen. |
| `services/chat_service.dart` | Abläufe für den Chat: Chats, Nachrichten in Echtzeit, Text, Foto, Deal. |
| `state/session_provider.dart` | Hält die Sitzung, wechselt zwischen «Anmelden» und App, reagiert auf den Bestätigungslink. |
| `state/my_wants_provider.dart` | Hält die Liste «Meine Gesuche» mit Lade- und Fehlerzustand. |

### Datenzugriffsschicht (`data/`)

| Datei | Aufgabe |
|---|---|
| `refind_repository.dart` | Schnittstelle I2 (Konzept 4.3.2) mit allen Datenzugriffen (Abschnitt 2). |
| `repository_exception.dart` | Fehlerarten und gemeinsame Meldungen (Annehmen, Statuswechsel, Deal). |
| `input_checks.dart` | Prüfungen vor dem Speichern, gemeinsam für Mock und Supabase (zweite Stufe der Inputvalidierung). |
| `mock_refind_repository.dart` | Attrappe im Speicher mit den Testdaten aus `05_testdaten.sql`; für Tests und Vorschau. |
| `supabase_refind_repository.dart` | Betrieb über Supabase: Auth, Tabellen, RPCs, Storage, Realtime; übersetzt Fehler in RepositoryException. |

### Modell (`model/`)

| Datei | Aufgabe |
|---|---|
| `model.dart` | Sammeldatei, exportiert alle Modellklassen. |
| `user.dart` | Profil (Name, Wohnort, Suchradius, Mitglied seit). |
| `place.dart` | Ortschaft mit LV95-Koordinaten und Distanzrechnung. |
| `want.dart` | Gesuch, Status, Kategorien, Zustände je Kategorie und `WantLimits`. |
| `offer.dart` | Angebot, Status, Sortierung und `OfferLimits`. |
| `photo.dart` | Foto zu einem Angebot. |
| `chat_thread.dart` | Chat zu einem angenommenen Angebot mit Übergabe und Abschluss. |
| `message.dart` | Nachricht (Text/Foto) und `MessageLimits`. |
| `rating.dart` | Bewertung nach einem Abschluss. |
| `account_limits.dart` | Grenzwerte für Passwort und Anzeigename. |
| `views.dart` | Hilfsklassen der Schnittstelle: `WantDraft`, `FeedFilter`, `WantSummary`, `FeedItem`, `ChatSummary`, `ProfileStats`. |

---

## 2. Schnittstelle `RefindRepository`

Alle Methoden sind asynchron. Fehlerarten (`RepositoryErrorKind`):
`keineVerbindung` (Netz), `nichtBerechtigt` (keine Sitzung, RLS, falsches
Passwort, zu viele Versuche), `ungueltigeEingabe` (Prüfung, CHECK-Regel),
`konflikt` (Zustand passt nicht, z.B. schon angenommen), `mailNichtBestaetigt`.
**Jede** Supabase-Methode kann zusätzlich `keineVerbindung` werfen; die Spalte
nennt die fachlichen Fälle. Ohne Anmeldung werfen alle Methoden ausser
signUp/signIn/resend `nichtBerechtigt`.

| Methode | Parameter | Rückgabe | Fehlerarten (fachlich) | Supabase |
|---|---|---|---|---|
| `signUp` | displayName, email, password | `void` | ungueltigeEingabe (Name 1–40, Mail, Passwort 8–72), konflikt (Mock: Mail vergeben; Supabase meldet das nicht, ABW 8.5) | umgesetzt |
| `signIn` | email, password | `User` | nichtBerechtigt (falsch, zu viele Versuche), mailNichtBestaetigt | umgesetzt |
| `resendConfirmation` | email | `void` | nichtBerechtigt (zu viele Versuche); sonst still (verrät nichts) | umgesetzt |
| `confirmationLinkResults` | – | `Stream<bool>` | – (false = Link ungültig) | umgesetzt (ABW 1.5) |
| `registerPushToken` | token | `void` | nichtBerechtigt | umgesetzt, App ruft es noch nicht auf (F-16) |
| `signOut` | – | `void` | – | umgesetzt |
| `getMyProfile` | – | `User` | nichtBerechtigt | umgesetzt |
| `getMyEmail` | – | `String` | nichtBerechtigt | umgesetzt (ABW 1.6) |
| `updateProfile` | displayName, cityId, radiusKm, avatar | `User` | ungueltigeEingabe | **offen** (F-02) |
| `deleteAccount` | – | `void` | nichtBerechtigt | umgesetzt (ABW 13.3) |
| `searchPlaces` | query | `List<Place>` | – (leer/zu lang → leere Liste) | umgesetzt |
| `getPlace` | placeId | `Place` | ungueltigeEingabe (nicht gefunden) | umgesetzt (ABW 1.2) |
| `createWant` | WantDraft | `Want` | ungueltigeEingabe (Titel, Kategorie, Beschreibung, Budget, Zustand, Umkreis, Laufzeit, Region) | umgesetzt |
| `getMyWants` | – | `List<WantSummary>` | – | umgesetzt |
| `updateWant` | wantId, WantDraft | `Want` | ungueltigeEingabe, konflikt | **offen** (UC4 Bearbeiten) |
| `setWantStatus` | wantId, status | `void` | konflikt (Wechsel nicht erlaubt, abgelaufen, angenommen), nichtBerechtigt (fremd), ungueltigeEingabe | umgesetzt |
| `republishWant` | wantId | `Want` | konflikt (nicht abgelaufen, angenommen, erledigt), nichtBerechtigt | umgesetzt |
| `getFeed` | FeedFilter | `List<FeedItem>` | ungueltigeEingabe (Suchbegriff > 80, Kategorie, Umkreis) | umgesetzt |
| `createOffer` | wantId, priceRappen, message, photos | `Offer` | ungueltigeEingabe (Preis, Nachricht, > 3 Fotos, Foto > 5 MB), nichtBerechtigt (eigenes Gesuch), konflikt (nimmt keine Angebote mehr an) | umgesetzt |
| `getOffers` | wantId, OfferSort | `List<Offer>` | nichtBerechtigt (fremdes Gesuch, Mock) | umgesetzt |
| `markOffersSeen` | wantId | `void` | – (Fehler werden in der Maske ignoriert) | umgesetzt |
| `acceptOffer` | offerId | `ChatThread` | konflikt (schon angenommen, nicht aktiv), nichtBerechtigt, ungueltigeEingabe (nicht gefunden) | umgesetzt |
| `getChats` | – | `List<ChatSummary>` | – | umgesetzt |
| `watchMessages` | threadId | `Stream<List<Message>>` | nichtBerechtigt (Mock: fremder Chat; Supabase: liefert nichts) | umgesetzt |
| `sendText` | threadId, text | `Message` | ungueltigeEingabe (leer, > 1000), nichtBerechtigt (fremder Chat) | umgesetzt |
| `sendPhoto` | threadId, photo | `Message` | ungueltigeEingabe (> 5 MB, Typ), nichtBerechtigt, konflikt (Bucket fehlt) | umgesetzt |
| `markRead` | threadId | `void` | nichtBerechtigt | **offen** in Supabase (F-14) |
| `setHandover` | threadId, at, place | `void` | ungueltigeEingabe, konflikt | **offen** in Supabase (F-15) |
| `closeDeal` | threadId, agreedPriceRappen | `void` | nichtBerechtigt (nicht Käufer), konflikt (schon abgeschlossen, Gesuch nicht aktiv), ungueltigeEingabe (Preis) | umgesetzt |
| `rateUser` | threadId, stars | `void` | konflikt, ungueltigeEingabe | **offen** in Supabase (F-17) |
| `getProfileStats` | userId | `ProfileStats` | – | **offen** in Supabase (F-18) |

«offen in Supabase» heisst: Das Mock kann es, `SupabaseRefindRepository` wirft
`UnimplementedError`; die App ruft diese Methoden nirgends auf.

---

## 3. Supabase: Funktionen und SQL-Dateien

### 3.1 Funktionen (RPC und intern)

| Name | Schema | Sicherheit | Aufruf | Was sie tut | Datei |
|---|---|---|---|---|---|
| `handle_new_user` | private | definer | Trigger `on_auth_user_created` | legt beim Registrieren das Profil an (Name aus den user metadata) | 04 |
| `is_own_new_offer`, `is_thread_member`, `is_want_owner`, `has_offer_on_want`, `want_open_for_offer`, `can_read_offer`, `can_rate` | private | definer | in RLS-Regeln | Hilfsprüfungen ohne Rekursion in RLS | 04 |
| `accept_offer(p_offer_id)` | public | definer | RPC | nimmt ein Angebot an, sagt die übrigen ab, legt den Chat an (eine Transaktion, Sperre) | 08 |
| `mark_offers_seen(p_want_id)` | public | definer | RPC | setzt Angebote eines eigenen Gesuchs von «neu» auf «gesehen» | 09 |
| `photo_count_ok(p_offer_id)` | private | definer | RLS `photo_insert` | höchstens 3 Fotos pro Angebot | 09 |
| `has_accepted_offer(p_want_id)` | private | definer | in `get_feed`, gibt nur ja/nein | gibt es zum Gesuch ein angenommenes Angebot? | 10 |
| `get_feed()` | public | **invoker** | RPC | aktive, nicht abgelaufene Gesuche anderer ohne angenommenes Angebot (RLS gilt zusätzlich) | 10 |
| `set_want_status(p_want_id, p_status)` | public | definer | RPC | Pausieren/Aktivieren nach Abbildung 2 | 11 |
| `republish_want(p_want_id)` | public | definer | RPC | Nochmal aufhängen: 14 Tage ab jetzt, `created_at` neu | 11 |
| `expire_wants()` | private | definer | pg_cron stündlich | setzt Gesuche ab dem Ablaufdatum auf «abgelaufen» | 12 |
| `uuid_or_null(p_text)` | private | – | Storage-Regeln | Ordnername als uuid, sonst null | 13 |
| `offer_photo_count(p_offer_id)` | private | definer | Storage-Regel | Anzahl Dateien im Ordner eines Angebots | 13 |
| `message_before_insert()` | private | invoker | Trigger auf `message` | Zeit vom Server, `read_at` leer (nur für die App) | 14 |
| `message_after_insert()` | private | definer | Trigger auf `message` | führt `chat_thread.last_activity` nach (nur für die App) | 14 |
| `close_deal(p_thread_id, p_agreed_price)` | public | definer | RPC | Deal abschliessen, Gesuch «erledigt»; nur Käufer, nur einmal | 14 |
| `account_photo_paths()` | public | definer | RPC | Pfade der **eigenen** Fotos (Angebote und Chat) | 15 |
| `delete_own_account()` | public | definer | RPC | löscht alle Daten des Kontos und `auth.users` | 15 |

Alle `public`-Funktionen: `execute` nur für `authenticated` (nicht `anon`).
Alle setzen `search_path` auf leer, prüfen `auth.uid()` selbst und werfen
eigene Codes (42501 nicht berechtigt, P0001 Zustand, P0002 nicht gefunden).

### 3.2 SQL-Dateien `supabase/`

| Datei | Von | Inhalt | Ausgeführt |
|---|---|---|---|
| `01_tabellen.sql` | Team | Export des Schemas: 3 Aufzählungen, 9 Tabellen | ja (Export) |
| `02_rls_regeln.sql` | Team | RLS für alle Tabellen | ja (Export) |
| `03_rechte.sql` | Team | Tabellen- und Spaltenrechte für `authenticated` | ja (Export) |
| `04_funktionen.sql` | Team | Hilfsfunktionen `private.*`, Trigger fürs Profil | ja (Export) |
| `05_testdaten.sql` | Team | 8 Orte, Testdaten Anna/Ben/Cara (10 Gesuche, Angebote, Chats, Bewertungen) | ja |
| `07_check_regeln.sql` | Team | CHECK für want, offer, profile, rating (Teil A prüfen, Teil B anlegen) | ja (ABW 8.2) |
| `08_angebot_annehmen.sql` | Team | `accept_offer` | ja (ABW 8.14) |
| `09_angebote.sql` | Team | `mark_offers_seen`, CHECK Preis/Nachricht, max. 3 Fotos | ja, 20.11.2026 |
| `10_feed.sql` | Claude/Nilton | `get_feed`, `has_accepted_offer` | ja, 19.11.2026 |
| `11_gesuch_status.sql` | Claude/Nilton | `set_want_status`, `republish_want`, Recht auf status/expires_at zurückgenommen | ja, 20.11.2026 |
| `12_ablauf.sql` | Claude/Nilton | `expire_wants`, pg_cron-Auftrag stündlich | ja, 20.11.2026 (pg_cron Job-ID 1 geprüft) |
| `13_speicher.sql` | Claude/Nilton | Buckets `offer-photos`, `chat-photos`, Storage-Regeln | ja, 20.11.2026 (2 Buckets geprüft) |
| `14_chat.sql` | Claude/Nilton | CHECK message/chat_thread, Trigger, Realtime, `close_deal` | ja, 20.11.2026 (Publication message geprüft) |
| `15_konto_loeschen.sql` | Claude/Nilton | `account_photo_paths`, `delete_own_account`, Löschregeln eigener Ordner | ja, 20.11.2026 (2 Funktionen geprüft) |
| `tests_datenzugriff.sql` | Team (Nick) | Tests T1–T8 für RLS und Rechte im SQL Editor | Ergebnis nicht dokumentiert |

Es gibt keine Datei `06_…`. Alle Dateien 01–15 sind in der Datenbank des
Projekts ausgeführt (Stand 20.11.2026). Die Prüfungen in Klammern sind die
Kontrollabfragen am Ende der jeweiligen Datei.

---

## 4. Storage, Echtzeit, Auftrag, Auth

### 4.1 Storage (Dateiablage)

| Bucket | Öffentlich | Max. Grösse | Dateitypen | Pfad |
|---|---|---|---|---|
| `offer-photos` | nein | 5 MB | JPEG, PNG, WebP | `<uid>/<offer_id>/<n>.<typ>` |
| `chat-photos` | nein | 5 MB | JPEG, PNG, WebP | `<thread_id>/<uid>/<zeit>.<typ>` |

| Regel (auf `storage.objects`) | Bedingung | Datei |
|---|---|---|
| `offer_photos_insert` | eigener Ordner, eigenes Angebot «neu», < 3 Dateien | 13 |
| `offer_photos_select` | `can_read_offer` (Verkäufer, Besitzer des Gesuchs) | 13 |
| `offer_photos_delete` | eigener Ordner (`<uid>/…`) | 15 (vorher 13: nur «neu») |
| `chat_photos_insert` | Mitglied des Chats, eigener Unterordner | 13 |
| `chat_photos_select` | Mitglied des Chats | 13 |
| `chat_photos_delete` | eigener Unterordner (`<thread>/<uid>/…`) | 15 |
| update | keine Regel → nie erlaubt | – |

Die App zeigt Fotos über signierte Links (eine Stunde gültig,
`createSignedUrlsResult`). Bucket `avatars` (Konzept S3) fehlt noch (F-02).

### 4.2 Echtzeit (Realtime)

- Tabelle `message` in der Publication `supabase_realtime` (14).
- Die App abonniert `message` mit Filter `thread_id` (`watchMessages`).
- Realtime prüft die RLS-Regel `message_select`: fremde Chats liefern nichts (TC27).

### 4.3 Geplanter Auftrag (pg_cron)

- Auftrag `expire_wants`, Zeitplan `0 * * * *` (jede volle Stunde), ruft
  `private.expire_wants()` auf (12). Erweiterung pg_cron eingeschaltet, Auftrag
  angelegt am 20.11.2026 (Job-ID 1).

### 4.4 Auth-Einstellungen

| Einstellung | Wert | Wo |
|---|---|---|
| Site URL | `ch.refind.app://login-callback` | Dashboard, Authentication → URL Configuration |
| Redirect URLs | `ch.refind.app://login-callback` | ebenda |
| Deep Link in der App | `SupabaseConfig.authRedirectUrl`, `emailRedirectTo` bei signUp und resend | `lib/app_config.dart` |
| Android | Intent-Filter Schema `ch.refind.app`, Host `login-callback`; `flutter_deeplinking_enabled=false` | `AndroidManifest.xml` |
| Verfahren | PKCE (Standard von `supabase_flutter`): Anmeldung über den Link nur auf dem Gerät, das registriert hat | ABW 13.2 |
| Mailversand | eingebauter Versand von Supabase (nur Team-Adressen), kein eigenes SMTP | ABW 8.10 |
| Schlüssel in der App | nur publishableKey; kein service_role-Schlüssel | ABW 7.5 |

---

## 5. Sicherheitsmassnahmen

### 5.1 Übersicht

| Bereich | Massnahme | Wo |
|---|---|---|
| Anmeldung | Supabase Auth, Passwörter als bcrypt-Hash, Zugriffstoken (JWT), Mailbestätigung vor der ersten Anmeldung | Supabase |
| Anmeldung | Fehlermeldungen verraten nicht, ob ein Konto existiert («Mailadresse oder Passwort ist falsch», Registrierung ohne Hinweis auf bestehende Mail) | `mapSupabaseError`, ABW 5.3, 8.5 |
| Anmeldung | Begrenzte Versuche: Supabase Rate Limits; im Mock 5 Fehlversuche → 1 Minute gesperrt | ABW 5.1, 8.4 |
| Anmeldung | Deep Link mit PKCE, Link nur auf dem eigenen Gerät einlösbar | ABW 13.2 |
| Zugriff | RLS auf allen 9 Tabellen: nur eigene bzw. freigegebene Zeilen | 02 |
| Zugriff | Spaltenrechte: z.B. beim Angebot nur price/message änderbar, beim Gesuch status/expires_at gar nicht (nur über Funktionen) | 03, 11 |
| Zugriff | Zustandswechsel nur über definer-Funktionen mit eigener Prüfung (annehmen, gesehen, pausieren, aufhängen, abschliessen, löschen) | 08, 09, 11, 14, 15 |
| Zugriff | Feed zeigt keine fremden Angebote (has_accepted_offer gibt nur ja/nein) | 10 |
| Zugriff | Storage privat, signierte Links, Regeln je Ordner; fremde Dateien nicht löschbar | 13, 15 |
| Zugriff | Realtime mit RLS | 14 |
| Daten | Server setzt Zeit von Nachrichten (nicht zurückdatierbar) | 14 |
| Daten | Konto löschen mit allen Daten (N-05), Bestätigung durch Eingabe «LÖSCHEN» | 15, ABW 13.3 |
| Fehler | Technische Server-Meldungen nur in der Debug-Konsole, der Nutzer sieht verständliche Texte | `mapSupabaseError` |

### 5.2 Inputvalidierung dreifach (Maske → Repository → Datenbank)

| Feld | Grenzwert | Maske | Repository (`input_checks.dart`) | Datenbank |
|---|---|---|---|---|
| Anzeigename | 1–40 Zeichen | ✓ | ✓ | CHECK `profile_display_name_check` (07) |
| Mailadresse | Format `name@domain.tld` | ✓ | ✓ | Supabase Auth |
| Passwort | 8–72 Zeichen | ✓ | ✓ | Supabase Auth (Mindestlänge im Dashboard; Wert nicht dokumentiert) |
| Titel Gesuch | 1–80 Zeichen | ✓ | ✓ | CHECK `want_title_check` (07) |
| Beschreibung | 0–1000 Zeichen | ✓ | ✓ | CHECK `want_description_check` (07) |
| Kategorie | 6 feste Werte | ✓ (Chips) | ✓ | CHECK `want_category_check` (07) |
| Zustand | Liste je Kategorie | ✓ (Chips) | ✓ | CHECK `want_condition_check` (07) |
| Preisobergrenze | > 0 bis CHF 10'000 | ✓ | ✓ | CHECK `want_budget_max_check` (07) |
| Umkreis | 1–200 km | ✓ (Auswahl) | ✓ | CHECK want/profile radius (07) |
| Laufzeit | 7, 14 oder 30 Tage | ✓ (Auswahl) | ✓ | CHECK `want_laufzeit_check` (07) |
| Angebotspreis | > 0 bis CHF 10'000 | ✓ | ✓ | CHECK `offer_price_check` (07, 09) |
| Nachricht zum Angebot | 0–500 Zeichen | ✓ | ✓ | CHECK `offer_message_check` (09) |
| Fotos pro Angebot | höchstens 3 | ✓ | ✓ | RLS `photo_insert` (09), Storage-Regel (13) |
| Fotogrösse/-typ | 5 MB, JPEG/PNG/WebP | ✓ | ✓ | Bucket-Einstellung (13) |
| Suchbegriff Feed | höchstens 80 Zeichen | ✓ | ✓ | – (nur Lesen, `ilike` mit escapten `%`/`_`) |
| Textnachricht | 1–1000 Zeichen | ✓ | ✓ | CHECK `message_body_check` (14) |
| Fotonachricht | Pfad im eigenen Ordner | – | ✓ (Pfad wird erzeugt) | CHECK `message_body_check` (14), Storage-Regel (13) |
| Vereinbarter Preis | > 0 bis CHF 10'000 | ✓ | ✓ | `close_deal` + CHECK `chat_thread_agreed_price_check` (14) |
| Sterne | 1–5 | – (F-17 offen) | Mock | CHECK `rating_stars_check` (07) |

---

## 6. Tests

`flutter test` am 20.11.2026: **254 Tests in 21 Dateien, alle bestanden.**
`flutter analyze`: keine Hinweise. Widget-Tests laufen auf 360 dp Breite
(Samsung SM-S931B), Überläufe lassen einen Test scheitern.

| Datei | Tests | Was sie prüfen |
|---|---|---|
| `account_rules_test.dart` | 6 | Regeln für Name, Mail, Passwort (8/72), Wiederholung |
| `want_rules_test.dart` | 8 | Regeln für Titel (80), Kategorie, Beschreibung, Budget, Zustand, Region |
| `offer_rules_test.dart` | 10 | Preis lesen und prüfen, Nachricht, 3 Fotos, «über Budget», wer annehmen darf |
| `price_logic_test.dart` | 2 | Schweizer Format, Rappen ↔ Franken |
| `status_logic_test.dart` | 17 | Übergänge Abbildung 2, abgelaufen (Grenzfälle), Knöpfe je Status, Laufzeit |
| `filter_logic_test.dart` | 28 | Suchbegriff (Gross/Klein, Leerzeichen, Umlaute, Sonderzeichen), Kategorie, Umkreis (Grenze), Sichtbarkeit, TC13/TC14 |
| `time_logic_test.dart` | 15 | «vor N Min», Laufzeit aufgerundet, Chatliste (heute/gestern/Wochentag/Datum, Zeitumstellung) |
| `chat_rules_test.dart` | 13 | Textlänge 1000/1001, wer «Deal» darf, Repository: Länge, TC27, Deal-Regeln |
| `feed_service_test.dart` | 5 | Feed mit FilterLogic, TC14 Winterthur, Bern 10 km, abgelaufen |
| `mock_refind_repository_test.dart` | 50 | Mock wie Datenbank: UC1 (TC01, TC02), UC3 (TC07, TC08), UC4 (TC10, TC11, TC28), UC5 (TC12–TC14), UC6, UC7, Profilstatistik |
| `supabase_mapping_test.dart` | 27 | Umwandlung Datenbankzeilen → Modell, Fehlerübersetzung, ilike-Muster, Chat-Zeilen |
| `photo_storage_test.dart` | 7 | Fotogrösse 5 MB, Dateityp, signierte Links, Maske, TC16 |
| `widget_test.dart` | 9 | UC1-Abläufe, UC3 Assistent (TC07/TC08), Vinyl-Chips |
| `discover_screen_test.dart` | 14 | Entdecken, Kategorien, Suche, Filter, kein Treffer, Region/Umkreis (TC12–TC14), lange Ortsnamen, Icon |
| `my_wants_screen_test.dart` | 4 | Status/Laufzeit auf Karten, Reihenfolge, abgelaufene Karte, TC11 |
| `want_status_screen_test.dart` | 9 | Knöpfe Pausieren/Aktivieren/Nochmal aufhängen (TC10, TC11), drei Sortierungen (TC18), Hinweise ohne Angebote |
| `offer_screens_test.dart` | 3 | Angebot senden (UC6), max. 3 Fotos (F-09), annehmen → Chat (TC19) |
| `chat_screens_test.dart` | 13 | Chatliste, Chatmaske, Echtzeit (TC20), nicht gesendet, Fotos, Deal (TC24) |
| `confirmation_link_test.dart` | 3 | Bestätigungslink meldet an (TC01), abgelaufener Link, schon angemeldet |
| `delete_account_test.dart` | 7 | Konto löschen: Daten (TC06), Folgen für andere, Dialog «LÖSCHEN», Profil bearbeiten |
| `profile_screen_test.dart` | 4 | Profil mit/ohne Wohnort, «Profil bearbeiten», kein «PLATZHALTER» |
| **Total** | **254** | |

Zusätzlich: `supabase/tests_datenzugriff.sql` (T1–T8, Team) für RLS und Rechte
im SQL Editor; Ergebnis nicht dokumentiert.

---

## 7. Stand der Testfälle TC01–TC30

**Testgerät:** Samsung SM-S931B, Android 17 (laut `adb`), App mit Supabase.
**Getestet am:** Handytest bestanden (Datum). «Automatisch» = Unit- oder
Widget-Test mit dem Mock. **Screenshots:** OneDrive, Ordner
`Realisierung/Testprotokoll` (Dateinamen wie in der Spalte).

| TC | UC / F | Stand | Getestet am (Handy) | Automatisch | Screenshots | Bemerkung |
|---|---|---|---|---|---|---|
| TC01 | UC1, F-01 | umgesetzt | 20.11.2026 bestanden (Deep Link mit Gmail) | ja | TC01_1–2 | ABW 13.1 |
| TC02 | UC1, F-01 | teilweise | – | ja (Mock-Sperre) | – | Grenze von Supabase nicht geprüft (ABW 8.4) |
| TC03 | UC1, UC2 | umgesetzt | nicht protokolliert | teilweise | – | Sitzung bleibt mit Supabase (ABW 6.2) |
| TC04 | UC1, N-04 | Prüfung offen | – | – | – | im Dashboard/Code prüfen (bcrypt, https, Token ≤ 1 h) |
| TC05 | UC2, F-02 | **nicht umgesetzt** | – | – | – | Profil ändern fehlt (F-02, Kann) |
| TC06 | UC2, N-05 | umgesetzt | 20.11.2026 bestanden | ja | TC06_1–3 | fremde Fotos bleiben verwaist (ABW 13.4) |
| TC07 | UC3, F-03 | umgesetzt | 12.11.2026 (Gesuch mit Supabase erfasst) | ja | – | Zeit (< 90 s) nicht gemessen |
| TC08 | UC3, F-03 | umgesetzt | 12.11.2026 (Mock) | ja | – | CHECK-Regeln in der Datenbank zusätzlich |
| TC09 | UC4, F-04 | umgesetzt | 20.11.2026 bestanden («gesehen» nach dem Öffnen) | teilweise | – | `mark_offers_seen` (09) |
| TC10 | UC4, F-05 | umgesetzt | 20.11.2026 bestanden | ja | TC10_1–4 | |
| TC11 | UC4, F-05 | umgesetzt | 20.11.2026 bestanden | ja | TC11_1–3 | pg_cron Job-ID 1 (12) |
| TC12 | UC5, F-06 | umgesetzt | 19.11.2026 bestanden | ja | TC12_1–2 | |
| TC13 | UC5, F-07 | umgesetzt | 19.11.2026 bestanden | ja | TC13_1–2 | |
| TC14 | UC5, F-08 | umgesetzt | 20.11.2026, **Bestätigung ausstehend** | ja | – | Maske seit 20.11.2026 |
| TC15 | UC5, N-02, N-03 | teilweise | – | – | – | max. 100 Einträge, Ladezustand; volles Mengengerüst fehlt |
| TC16 | UC6, F-09 | umgesetzt | 20.11.2026 bestanden | ja | wird im Systemtest wiederholt | Buckets (13) |
| TC17 | UC6, F-16 | **nicht umgesetzt** | – | – | – | keine Pushmitteilungen (Kann, Prio 2) |
| TC18 | UC7, F-10, F-11 | umgesetzt | 20.11.2026 bestanden (alle drei Sortierungen) | ja | TC18_1–3 | |
| TC19 | UC7, F-12 | teilweise | – | ja | – | Annehmen, Chat, Feed ok; Absage per Push fehlt (F-16) |
| TC20 | UC8, F-13 | umgesetzt | 20.11.2026 bestanden (Echtzeit, Nachricht über SQL Editor als Ben) | ja (Mock-Echtzeit) | TC20_1–2 | Publication (14) |
| TC21 | UC8, F-14 | **nicht umgesetzt** | – | – | – | Lesebestätigung zurückgestellt (ABW 12.12) |
| TC22 | UC8, F-15 | **nicht umgesetzt** | – | – | – | Übergabe zurückgestellt (ABW 12.12) |
| TC23 | UC8, F-16, N-05 | **nicht umgesetzt** | – | – | – | keine Pushmitteilungen |
| TC24 | UC8, F-05 | umgesetzt | 20.11.2026 bestanden | ja | TC24_1–2 | `close_deal` (14) |
| TC25 | UC9, F-17 | **nicht umgesetzt** | – | – | – | Bewertung zurückgestellt |
| TC26 | UC9, F-18 | **nicht umgesetzt** | – | Mock-Statistik | – | Anzeige fehlt |
| TC27 | UC8, F-19, N-04 | umgesetzt | 19.11.2026 mit Thomas Fehr (Lesen fremder Chat: 0 Zeilen); 20.11.2026 Insert als Cara → Fehler 42501 (RLS) | ja (Mock) | TC27_1–4 | RLS und Realtime mit RLS |
| TC28 | UC4, F-19 | umgesetzt | – | ja (Mock) | – | `tests_datenzugriff.sql` T2 (Team), Ergebnis nicht dokumentiert |
| TC29 | alle, N-01 | teilweise | App läuft auf SM-S931B (Android 17) | – | – | Emulator nicht getestet |
| TC30 | UC3, N-06 | offen | – | – | – | braucht zwei Mitlernende |

**Zusammenfassung:**

- **Stand:** umgesetzt 17, teilweise 5 (TC02, TC15, TC19, TC29, dazu TC04 als
  offene Prüfung), nicht umgesetzt 7 (TC05, TC17, TC21–TC23, TC25, TC26),
  offen 1 (TC30).
- **Auf dem Handy mit Supabase bestanden (13):** TC01, TC06, TC07, TC09,
  TC10, TC11, TC12, TC13, TC16, TC18, TC20, TC24, TC27.
- **Bestätigung ausstehend:** TC14.
- **Mit Screenshots (10):** TC01, TC06, TC10, TC11, TC12, TC13, TC18, TC20,
  TC24, TC27; TC16 wird im Systemtest wiederholt.
