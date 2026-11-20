# Abweichungen vom Konzeptbericht

Bezug: *2_1_Konzeptbericht_refind*, Speicherdatum 29.10.2026.
Stand: 19.11.2026 (KW 47), nach Anmelden/Registrieren (UC1), Gesuch erfassen (UC3),
SupabaseRefindRepository für UC1 und UC3 (Abschnitt 8) sowie Angebot senden,
ansehen und annehmen (UC6, UC7, Abschnitt 9) sowie Entdecken, Suchen und
filtern (UC5, Abschnitt 10) und Gesuche verwalten (UC4, F-05, Abschnitt 11) sowie
Chat und Abschluss (UC8, Abschnitt 12), Stand 20.11.2026.
Alle Team-Entscheide wurden am 12.11.2026 vom Team bestätigt, Vinyl mit
geänderten Zuständen (Abschnitt 4).

Diese Liste ist die Grundlage für den Realisierungsbericht. Jede Abweichung
hat einen Status:

- **umgesetzt**: so im Code, Begründung reicht für den Bericht
- **vom Team bestätigt (Datum)**: war eine Annahme, das Team hat sie an diesem Datum bestätigt
- **offen**: im Konzept verlangt, aber noch nicht umgesetzt

---

## 1. Schnittstelle RefindRepository (Kapitel 4.3.2)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 1.1 | Methoden von `signUp` bis `getProfileStats` | Neue Methode `Future<void> resendConfirmation(String email)` | UC1, Ausnahme «Mailadresse noch nicht bestätigt»: Die App soll anbieten, die Mail erneut zu senden. Ohne diese Methode geht das nicht. Die Methode verrät nicht, ob es das Konto gibt. | umgesetzt |
| 1.2 | Methoden von `signUp` bis `getProfileStats` | Neue Methode `Future<Place> getPlace(int placeId)` | UC3 Schritt 4: Die Region ist mit dem Wohnort vorbelegt. Das Profil kennt nur `cityId`. Um «Bern» anzuzeigen, muss die Ortschaft gelesen werden. | umgesetzt |
| 1.3 | `RepositoryException` mit vier Arten: keine Verbindung, nicht berechtigt, ungültige Eingabe, Konflikt | Fünfte Art `mailNichtBestaetigt` | Die Maske muss «nicht bestätigt» von «falsches Passwort» unterscheiden, damit sie «Mail erneut senden» nur im richtigen Fall zeigt. | umgesetzt |
| 1.4 | `getOffers(String wantId, OfferSort sort)`, Werte von `OfferSort` nicht festgelegt | `OfferSort { neueste, guenstigste, teuerste }`. Bei gleichem Preis steht das neuere Angebot zuerst. | UC7 Schritt 3 und TC18 verlangen «Preis aufsteigend, Preis absteigend oder nach Eingang», vorgegeben Preis aufsteigend. Bis 20.11.2026 fehlte `teuerste` (Preis absteigend), `neueste` war hier fälschlich als Ergänzung bezeichnet. In «Gesuch Detail · Angebote» heissen die Chips «Günstigste», «Teuerste», «Neueste», vorgewählt ist «Günstigste». | vom Team bestätigt (12.11.2026), `teuerste` ergänzt (20.11.2026) |

## 2. Fachliche Entitätstypen und Hilfsklassen (Kapitel 2.1, 4.3.2)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 2.1 | `User.cityID : int` (Pflicht) | `int? cityId` (darf leer sein) | Die Maske «Registrieren» (UC1) fragt keinen Wohnort ab. Ein neues Konto hat also zuerst keinen Wohnort. Er wird in «Profil bearbeiten» (UC2) ergänzt. Bis dahin muss die Region in UC3 von Hand gewählt werden. | umgesetzt |
| 2.2 | `WantSummary` ergänzt `Want` um Zähler | Zusätzlich das Feld `region : Place` | «Meine Gesuche» zeigt je Gesuch die Region (Kapitel 3.3). Ohne das Feld bräuchte jede Karte einen eigenen Datenzugriff. | umgesetzt |
| 2.3 | `Photo` ist eine eigene Entität mit `offerID` | `Offer` trägt zusätzlich die Liste `photos` | Bequemer für die Anzeige der Angebotsliste. In der Datenbank bleibt `photo` eine eigene Tabelle. | umgesetzt |
| 2.4 | Paket `model` enthält die Klassen der Entitätstypen | Zusätzlich Grenzwerte (`account_limits.dart`, `WantLimits` in `want.dart`) und die Zustandsliste | Maske (Anwendungsschicht) und Repository (Datenzugriffsschicht) brauchen dieselben Werte. Im Paket `model` dürfen beide Schichten sie verwenden, ohne die Schichtrichtung zu verletzen. | umgesetzt |
| 2.5 | `Offer` hat die Attribute aus Kapitel 2.1 | Zusätzlich `sellerName` (Anzeigename des Verkäufers, freiwillig) | Die Angebotsliste (UC7) zeigt, von wem ein Angebot ist. Ohne das Feld bräuchte jede Karte einen eigenen Datenzugriff (wie 2.2). | umgesetzt |
| 2.6 | Grenzwerte für Angebote nicht festgelegt | `OfferLimits` in `model/offer.dart` (siehe 3.10 bis 3.12) | Wie 2.4: Maske und Repository prüfen dieselben Werte | umgesetzt |

## 3. Eingaberegeln und Grenzwerte (Inputvalidierung, Modul 183)

Das Konzept und das Factsheet Inputvalidierung lassen diese Werte offen
(«Noch offen: Längen, Maximalpreis …»). Die Werte stehen je an einer Stelle
im Code und gelten in der Maske **und** im Repository. Bei Supabase müssen
dieselben Werte als CHECK-Regeln bzw. in den Auth-Einstellungen stehen.

| Nr. | Feld | Regel im Code | Stelle im Code | Status |
|---|---|---|---|---|
| 3.1 | Passwort | mindestens **8**, höchstens **72** Zeichen. 72, weil bcrypt (N-04) nur 72 Bytes berücksichtigt. | `model/account_limits.dart` | vom Team bestätigt (12.11.2026) |
| 3.2 | Anzeigename | Pflicht, höchstens **40** Zeichen | `model/account_limits.dart` | vom Team bestätigt (12.11.2026) |
| 3.3 | Mailadresse | Format `name@domain.tld` | `application/logic/account_rules.dart` | umgesetzt |
| 3.4 | Titel des Gesuchs | Pflicht, höchstens **80** Zeichen (Vorschlag aus dem Factsheet) | `WantLimits.maxTitleLength` | umgesetzt |
| 3.5 | Beschreibung | **freiwillig**, höchstens **1000** Zeichen. F-03 nennt die Beschreibung, die Ausnahmen in UC3 verlangen aber nur Titel, Kategorie und Preisobergrenze. | `WantLimits.maxDescriptionLength` | vom Team bestätigt (12.11.2026) |
| 3.6 | Preisobergrenze | grösser als **CHF 0**, höchstens **CHF 10'000**, Regler in Schritten von **CHF 50**. Abbildung 7 zeigt einen Regler bis CHF 3'200. Das reicht für Möbel nicht (Testdaten: Eames CHF 4'500). | `WantLimits.maxBudgetRappen`, `budgetStepRappen` | vom Team bestätigt (12.11.2026) |
| 3.7 | Kategorie | nur die sechs Kategorien aus Kapitel 2.1 (Whitelist) | `kategorien` in `model/want.dart` | umgesetzt |
| 3.8 | Umkreis | Auswahl 10/20/30/50/100 km plus Wert aus dem Profil, erlaubt 1–200 km | `WantLimits.radiusOptions`, `maxRadiusKm` | vom Team bestätigt (12.11.2026) |
| 3.9 | Laufzeit | Auswahl **7, 14 oder 30 Tage**, vorbelegt 14 (UC3) | `WantLimits.durationOptions` | vom Team bestätigt (12.11.2026) |
| 3.10 | Preis des Angebots | Pflicht, grösser als **CHF 0**, höchstens **CHF 10'000** (wie die höchste Preisobergrenze). Eingabe als «1650», «1'650» oder «1650.50». | `OfferLimits.maxPriceRappen`, `parseChfToRappen` in `application/logic/offer_rules.dart` | Vorschlag, vom Team zu bestätigen |
| 3.11 | Nachricht zum Angebot | **freiwillig**, höchstens **500** Zeichen | `OfferLimits.maxMessageLength` | Vorschlag, vom Team zu bestätigen |
| 3.12 | Fotos zum Angebot | höchstens **3** (F-09), verkleinert auf höchstens 1600 px, JPEG 80 % | `OfferLimits.maxPhotos`, `pickPhotoWithImagePicker` | umgesetzt |

## 4. Zustände je Kategorie (Kapitel 2.1)

Das Konzept legt nur die Uhren fest («Original», «Serviciert», «Egal»).
Die übrigen Kategorien soll das Team «zu Beginn der Realisierung» festlegen.
Das Team hat die Listen am 12.11.2026 festgelegt (`zustaende` in
`model/want.dart`). Bei Vinyl hat es den Vorschlag geändert: «Sehr gut» wurde
zu «Gebraucht (leichtes Knistern ok)». Der letzte Wert ist jeweils «Egal» und
vorausgewählt.

| Kategorie | Zustände | Status |
|---|---|---|
| Uhren | Original, Serviciert, Egal | aus dem Konzept |
| Möbel | Wie neu, Gebraucht, Egal | vom Team bestätigt (12.11.2026) |
| Velo | Fahrbereit, Revisionsbedürftig, Egal | vom Team bestätigt (12.11.2026) |
| Vinyl | Neuwertig, Gebraucht (leichtes Knistern ok), Egal | vom Team bestätigt (12.11.2026), geändert |
| Kameras | Voll funktionsfähig, Mit Mängeln, Egal | vom Team bestätigt (12.11.2026) |
| Werkzeug | Neu, Gebraucht, Egal | vom Team bestätigt (12.11.2026) |

## 5. Masken und Abläufe (Kapitel 3, UC1, UC3)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 5.1 | UC1: «Die Zahl der Anmeldeversuche ist begrenzt» (ohne Zahl) | Im Mock: nach **5** Fehlversuchen **1 Minute** gesperrt. Bei Supabase legt der Anmeldedienst die Grenze fest (siehe 8.4). | TC02 testbar machen | umgesetzt (Mock) |
| 5.2 | UC1 Schritt 5: Bestätigung über den Link in der Mail | Im Mock bestätigt «Mail erneut senden» das Konto sofort | Der Mock verschickt keine Mails. So lässt sich TC01 ohne Supabase durchspielen. | umgesetzt (Mock) |
| 5.3 | UC1 Ausnahme «Mailadresse bereits registriert» | Meldung «Die Registrierung ist mit diesen Angaben nicht möglich.» | Verrät nichts über das bestehende Konto, wie UC1 verlangt (siehe auch Factsheet, «Was kann schiefgehen?», Punkt 3: zu genaue Fehlermeldungen) | umgesetzt |
| 5.4 | Kapitel 2.3: Fehlende Verbindung → Meldung, Eingaben behalten, wiederholen | Wie im Konzept. Zusätzlich zeigt ein **unerwarteter Fehler** «Etwas ist schiefgelaufen. Bitte versuche es nochmals.» | Kein stiller Absturz | umgesetzt |
| 5.5 | Abbildung 4: «ändern» bei Region, Umkreis und Laufzeit, ohne eigene Maske | Zwei zusätzliche Sheets: «Region & Umkreis» (Ortssuche und Umkreis) und «Wie lange sichtbar?» | Irgendwo müssen die neuen Werte eingegeben werden. Die Sheets folgen dem Muster aus Kapitel 3.1. | umgesetzt |
| 5.6 | Abbildung 13, Paket `logic`: PriceLogic, StatusLogic, FilterLogic | Zusätzlich `account_rules.dart` und `want_rules.dart`. In der Datenzugriffsschicht zusätzlich `data/input_checks.dart` (Prüfungen, die Mock und Supabase gemeinsam benutzen). | Die Eingaberegeln sind Fachlogik ohne Netz und lassen sich mit Unittests prüfen (N-08). Gemeinsame Prüfungen sorgen dafür, dass Mock und Supabase gleich reagieren. | umgesetzt |
| 5.7 | Abbildung 13: Masken je Paket | Zusätzlich `SessionGate` (wählt nach der Sitzung «Anmelden» oder «Meine Gesuche», UC1 Schritt 1) und `HomeShell` (Navigationsleiste) | Technische Bausteine, keine eigenen Masken | umgesetzt |
| 5.8 | Darstellung für iPhone gezeichnet | Android: Systemleiste, Tastatur und Zurück-Taste von Android. Die Zurück-Taste geht im Assistenten einen Schritt zurück. | refind ist eine Android-App (Kapitel 3) | umgesetzt |

## 6. Noch nicht umgesetzt (offen)

| Nr. | Konzept | Stand |
|---|---|---|
| 6.1 | UC1 Schritt 8: Erlaubnis für Mitteilungen und Pushtoken anmelden | folgt mit Firebase Cloud Messaging |
| 6.2 | UC1 Kurzbeschreibung: «Die Sitzung bleibt bestehen, bis sie sich abmeldet» | Mit Supabase umgesetzt: `supabase_flutter` speichert die Sitzung, beim Start lädt `getMyProfile` das Profil. Nur mit dem Mock ist die Sitzung nach einem Neustart weg. |
| 6.3 | UC4 in «Meine Gesuche»: Pausieren, Bearbeiten, eigene Karte für abgelaufene Gesuche, verbleibende Laufzeit | Seit 20.11.2026 umgesetzt bis auf «Bearbeiten» (Abschnitt 11). |
| 6.4 | Alle übrigen Masken aus Abbildung 4 | Platzhalter mit den Wegen aus Abbildung 4 |
| 6.5 | `SupabaseRefindRepository` für UC2, UC9 und Teile von UC4 und UC8 | Noch offen: `updateProfile`, `deleteAccount`, `getProfileStats` (UC2), `updateWant` (UC4 Bearbeiten), `markRead` (F-14), `setHandover` (F-15), `rateUser` (UC9). Diese Methoden werfen `UnimplementedError` («folgt mit UCx»), die App ruft sie noch nirgends auf. Umgesetzt sind UC1, UC3, UC4 ohne Bearbeiten (Abschnitt 11), UC5 (10), UC6 und UC7 (9), UC8 ohne F-14 bis F-16 (12). |

## 7. Projekt-Einstellungen (nicht im Konzept festgelegt)

| Nr. | Einstellung | Wert |
|---|---|---|
| 7.1 | Paket-ID der Android-App | `ch.refind.refind` |
| 7.2 | Plattformen | nur Android (kein iOS, Web, Desktop) |
| 7.3 | Zustandsverwaltung | Paket `provider`, wie in der Studie vorgesehen (Kapitel 4.2.2) |
| 7.4 | Umsetzung des Repository beim Start | `lib/app_config.dart`, Konstante `repositoryMode` (`mock` oder `supabase`), im Moment `supabase`. Nach dem Umschalten Hot Restart (`R`). Die Tests benutzen immer das Mock. |
| 7.5 | Verbindung zu Supabase | URL und publishableKey nur in `lib/app_config.dart` (`SupabaseConfig`). Der publishableKey ist öffentlich, was er darf, bestimmen die RLS-Regeln. Der service_role-Schlüssel ist nicht in der App. |
| 7.6 | Zusätzliche Pakete | `supabase_flutter` (Backend), `http` (um «keine Verbindung» sicher zu erkennen), `image_picker` (Fotos zum Angebot aus Kamera oder Galerie, F-09) |
| 7.7 | Android-Berechtigung | `INTERNET` im `AndroidManifest.xml`, nötig für die fertige App (Release) |
| 7.8 | Datenbankschema | SQL-Export in `supabase/01` bis `04`, Testdaten und vorläufige Ortschaften in `supabase/05_testdaten.sql`, CHECK-Regeln in `supabase/07_check_regeln.sql`, Funktion «Angebot annehmen» in `supabase/08_angebot_annehmen.sql`, Funktion «Angebote gesehen» und Regeln für Angebote in `supabase/09_angebote.sql` (am 20.11.2026 ausgeführt, siehe 9.4), Funktion «Feed» in `supabase/10_feed.sql` (siehe 10.2), Funktionen für Pausieren, Aktivieren und Nochmal aufhängen in `supabase/11_gesuch_status.sql` (11.3), stündlicher Auftrag «abgelaufen» in `supabase/12_ablauf.sql` (11.5), Buckets und Storage-Regeln für Fotos in `supabase/13_speicher.sql` (9.12), Chat (CHECK, Trigger, Echtzeit, `close_deal`) in `supabase/14_chat.sql` (12.5, 12.9). `10_feed.sql` hiess zuerst `09_feed.sql` und wurde am 19.11.2026 umbenannt, weil das Team gleichzeitig `09_angebote.sql` angelegt hatte. |
| 7.9 | Buckets für Fotos | `SupabaseConfig.offerPhotoBucket = 'offer-photos'` und `chatPhotoBucket = 'chat-photos'` in `lib/app_config.dart`, eingerichtet mit `supabase/13_speicher.sql` (siehe 9.3, 9.12) |

## 8. Supabase (SupabaseRefindRepository, KW 46)

Die Detailplanung sah `SupabaseRefindRepository` als Heimarbeit vor. Umgesetzt
sind die Methoden für UC1 (`signUp`, `signIn`, `resendConfirmation`,
`signOut`, `getMyProfile`) und UC3 (`createWant`, `getMyWants`,
`searchPlaces`, `getPlace`). Am 12.11.2026 auf dem Handy getestet:
registrieren, Konto bestätigen, anmelden, Gesuch erfassen. Das Gesuch steht
in der Tabelle `want`.

| Nr. | Konzept / Erwartung | Umsetzung oder Befund | Grund / nächster Schritt | Status |
|---|---|---|---|---|
| 8.1 | Fehler als `RepositoryException` (Kapitel 4.3.2) | `mapSupabaseError` übersetzt Fehler von Supabase Auth und der Datenbank in die fünf Arten, mit denselben Meldungen wie beim Mock. Die technische Meldung des Servers erscheint nur beim Entwickeln in der Konsole. Programmierfehler werden nicht versteckt. | Factsheet: verständliche Meldungen, keine Details vom Server | umgesetzt |
| 8.2 | Prüfung auf dem Server (Factsheet Inputvalidierung) | Das Repository prüft vor dem Senden dieselben Regeln wie das Mock (`input_checks.dart`). In der Datenbank gibt es aber **keine CHECK-Regeln**: Wer die App umgeht, kann z.B. einen Titel mit 500 Zeichen, ein negatives Budget, einen unbekannten Zustand oder einen Anzeigenamen mit 200 Zeichen speichern. | CHECK-Regeln mit den Werten aus Abschnitt 3 und 4 in `want` und `profile` ergänzen | umgesetzt (19.11.2026) |
| 8.3 | UC3: Laufzeit 7, 14 oder 30 Tage | Die App rechnet `expires_at` aus und schickt es mit. Die Datenbank prüft den Wert nicht, man könnte also ein Gesuch eintragen, das erst in Jahren abläuft. | In der Datenbank prüfen, z.B. `expires_at <= created_at + 30 Tage` | umgesetzt (19.11.2026) |
| 8.4 | UC1: Anmeldeversuche begrenzt | Supabase begrenzt die Anfragen pro IP-Adresse, nicht «5 Fehlversuche pro Konto» wie im Mock. Die App meldet dann «Zu viele Versuche. Bitte warte ein paar Minuten.» | Grenzwerte im Dashboard prüfen (Authentication → Rate Limits), TC02 mit Supabase durchspielen | offen |
| 8.5 | UC1 Ausnahme «Mailadresse bereits registriert» | Bei eingeschalteter Mailbestätigung meldet Supabase keinen Fehler, die App zeigt dieselbe Erfolgsmeldung wie bei einem neuen Konto. Das Mock zeigt «Die Registrierung ist mit diesen Angaben nicht möglich.» | Beides verrät nichts über das bestehende Konto (UC1) | umgesetzt |
| 8.6 | UC1: nach dem Registrieren anmelden | Ist die Mailbestätigung im Projekt ausgeschaltet, meldet Supabase sofort an. Die App meldet dann gleich wieder ab, damit der Ablauf wie beim Mock bleibt. | Gleicher Ablauf in beiden Umsetzungen | umgesetzt |
| 8.7 | Status «abgelaufen» (Abbildung 2) | Kein Auftrag in der Datenbank setzt Gesuche auf «abgelaufen». Die App zeigt ein aktives Gesuch mit vergangenem `expires_at` als «abgelaufen» an. Die RLS-Regel `want_select` blendet es im Feed schon richtig aus. | Seit 20.11.2026: stündlicher Auftrag über pg_cron in `12_ablauf.sql`, siehe 11.5 | umgesetzt (20.11.2026), Datei ausführen |
| 8.8 | Ortssuche (Wohnort, Region) | `searchPlaces` sucht bei Ziffern nach dem Beginn der PLZ («30» findet 3000–3099), sonst im Ortsnamen. Höchstens 20 Treffer. `%` und `_` aus der Eingabe gelten nicht als Platzhalter. | Schnelle Antwort, keine Platzhalter von aussen | umgesetzt |
| 8.9 | Beschreibung freiwillig (3.5) | Leere Beschreibung wird in der Datenbank als `NULL` gespeichert, die App zeigt sie als leeren Text. | Spalte `description` darf leer sein | umgesetzt |
| 8.10 | UC1 Schritt 5: Bestätigungsmail | Der eingebaute Mailversand von Supabase schickt **nur an Mailadressen von Mitgliedern des Supabase-Teams** und nur wenige Mails pro Stunde. Die Testkonten `…@refind.test` lassen sich darum nicht über die App bestätigen. Getestet mit einer echten Mailadresse. | Eigenen Mailserver (SMTP) in Supabase eintragen. Bis dahin Testkonten im Dashboard von Hand bestätigen (Authentication → Users) | offen |
| 8.11 | UC1 Schritt 5: Link in der Mail bestätigt das Konto | Der Link führt nach der Bestätigung auf `localhost:3000` («Seite nicht erreichbar»). Die Bestätigung selbst klappt. Grund: Die «Site URL» im Projekt steht noch auf dem Standardwert. | Site URL und Redirect URLs einstellen (Authentication → URL Configuration), z.B. eine einfache Seite «Konto bestätigt, zurück zur App» oder einen Link direkt in die App | offen |
| 8.12 | Ortschaftenverzeichnis von swisstopo (Konzept 2.1) | Die Tabelle `place` war leer, darum liess sich keine Region wählen. Übergang: 8 Orte (Bern, Zürich, Winterthur, Basel, Luzern, St. Gallen, Lausanne, Genève) in `supabase/05_testdaten.sql`. Das Mock hat seit 19.11.2026 dieselben 8 Orte (siehe 10.8). | Ganzes Ortschaftenverzeichnis mit LV95-Koordinaten importieren | Übergang mit 05_testdaten.sql |
| 8.13 | Pushtoken beim Abmelden entfernen (Kapitel 4.3.2) | `signOut` löscht die Zeilen in `push_token` und meldet dann ab. Darum braucht das Abmelden mit Supabase eine Verbindung. | Nach dem Abmelden keine Mitteilungen mehr | umgesetzt |
| 8.14 | F-12 / UC7: Angebot annehmen, übrige Angebote absagen, Chat anlegen | Datenbank-Funktion `accept_offer(p_offer_id)` in `supabase/08_angebot_annehmen.sql`, Aufruf aus der App über `rpc`. Sie prüft Besitzer, Status und Ablauf des Gesuchs, nimmt das Angebot an, sagt die übrigen offenen Angebote ab und legt den Chat an, alles in einer Transaktion. Eigene Fehler mit den Codes P0001 und P0002. `acceptOffer` im SupabaseRefindRepository ruft sie auf, `mapSupabaseError` übersetzt P0001 in «konflikt» und P0002 in «ungültige Eingabe» (siehe 9.6). | Der Käufer darf den Status eines Angebots wegen RLS nicht direkt ändern. | umgesetzt (19.11.2026) |

## 9. Angebote (UC6, UC7, KW 47)

Umgesetzt von Nick am 19.11.2026: Maske «Angebot senden» (UC6, F-09),
Maske «Gesuch Detail · Angebote» mit Kennzeichnung «über Budget»,
Sortierung und «Annehmen» (UC7, F-10 bis F-12). Im Mock und im
SupabaseRefindRepository (`getFeed` zuerst vorläufig, seit 19.11.2026 durch UC5 ersetzt, siehe Abschnitt 10; `createOffer`, `getOffers`,
`markOffersSeen`, `acceptOffer`). Unittests: `test/offer_rules_test.dart`,
`test/mock_refind_repository_test.dart`, `test/supabase_mapping_test.dart`,
`test/offer_screens_test.dart`.

| Nr. | Konzept / Erwartung | Umsetzung oder Befund | Grund / nächster Schritt | Status |
|---|---|---|---|---|
| 9.1 | UC6 beginnt in «Entdecken» (UC5) mit Karten, Suche und Filter | «Entdecken» zeigt **vorläufig** eine einfache Liste der aktiven Gesuche anderer Personen, jede Karte mit «Angebot senden». Das vorläufige `getFeed` im SupabaseRefindRepository (höchstens 50 Gesuche, Suche auch in der Beschreibung) ist seit dem Merge vom 19.11.2026 durch das `getFeed` aus UC5 ersetzt, die vorläufige Maske ebenfalls am 19.11.2026 (Abschnitt 10). `OfferService.getFeed` wird seither nicht mehr benutzt. | Ohne Liste liess sich UC6 auf dem Handy nicht testen. | ersetzt (19.11.2026), `OfferService.getFeed` kann weg |
| 9.2 | Feed zeigt keine Gesuche mit angenommenem Angebot | Gelöst mit der Funktion `get_feed` in `supabase/10_feed.sql` (siehe 10.2). Zusätzlich lehnt die RLS-Regel `offer_insert` ein Angebot auf ein solches Gesuch ab («Auf dieses Gesuch kannst du kein Angebot (mehr) senden.»). | — | umgesetzt (19.11.2026) |
| 9.3 | F-09: Fotos in der Dateiablage (Konzept 2.1) | Seit 20.11.2026 eingerichtet: privater Bucket `offer-photos` mit Regeln in `supabase/13_speicher.sql` (9.12, 9.13). Ablauf: Angebot speichern, Fotos nach Supabase Storage, Pfad in `photo.url`. Der Pfad ist neu **`<uid>/<offer_id>/<n>.jpg`** (vorher `<offer_id>/<n>.jpg`), damit die Regel «nur in den eigenen Ordner» greift. Ursprünglich wollte Etienne die Dateiablage bis 26.11.2026 einrichten. | `13_speicher.sql` ausführen, dann TC16 mit ben@refind.test auf dem Handy | umgesetzt (20.11.2026), Datei ausführen |
| 9.4 | UC7: Angebote werden beim Ansehen «gesehen» (Abbildung 2) | Der Käufer darf den Status wegen RLS nicht ändern. Neue Funktion `mark_offers_seen(p_want_id)` in `supabase/09_angebote.sql`. Klappt der Aufruf nicht (z.B. Funktion noch nicht in der Datenbank), zeigt die App keinen Fehler, die Angebote bleiben «neu». | `09_angebote.sql` am 20.11.2026 ausgeführt | umgesetzt (20.11.2026) |
| 9.5 | Prüfung auf dem Server für Angebote (Factsheet Inputvalidierung) | In der Datenbank gilt nur `price > 0` (07). `09_angebote.sql` ergänzt: Preis höchstens CHF 10'000, Nachricht höchstens 500 Zeichen, höchstens 3 Fotos pro Angebot (RLS `photo_insert`). | `09_angebote.sql` am 20.11.2026 ausgeführt. Die Werte 3.10 und 3.11 sind noch als Vorschlag markiert. | umgesetzt (20.11.2026) |
| 9.6 | Fehler beim Annehmen | P0001 (Gesuch nicht mehr aktiv, schon ein Angebot angenommen, Angebot abgesagt) → «Dieses Angebot lässt sich nicht mehr annehmen. Bitte lade die Angebote neu.», die Liste lädt sich neu. P0002 → «Das Angebot wurde nicht gefunden.» 42501 → «Dafür fehlt dir die Berechtigung.» Das Mock wirft dieselben Meldungen. Fehler von Storage (Foto zu gross usw.) sind ebenfalls übersetzt. | Gleiche Meldungen in Mock und Supabase | umgesetzt |
| 9.7 | Scheitern die Fotos nach dem Speichern des Angebots | Das Angebot bleibt gespeichert (ohne die Fotos), die App meldet «Angebot gesendet. Die Fotos konnten noch nicht gespeichert werden.» Nicht als Fehler, sonst sendet die Person nochmals und es gibt zwei Angebote. | Angebot und Fotos lassen sich nicht in einer Transaktion speichern (Storage ist keine Tabelle). Später: Fotos nachträglich hinzufügen | umgesetzt |
| 9.8 | F-12: «Danach öffnet sich der Chat» | Nach «Annehmen» (mit Rückfrage) ersetzt der Chat die Maske «Gesuch Detail». `ChatScreen` bekommt den neuen Chat (`thread`), der Platzhalter zeigt ihn noch nicht an. | Chat selbst folgt mit UC8 | erledigt, siehe 12.8 |
| 9.9 | Mock-Testdaten | Zuerst ein zusätzliches Angebot `offer-4` von Mia zu Annas «Omega Seamaster 300», damit «über Budget» im Mock zu sehen ist. Seit 19.11.2026 ersetzt: Die Mock-Daten entsprechen `05_testdaten.sql` (siehe 10.8), «über Budget» zeigt dort Bens Angebot von CHF 2'100 zur Eames (Budget CHF 2'000). | F-11 testbar machen | ersetzt durch 10.8 (19.11.2026) |
| 9.10 | Hinweis «über der Preisobergrenze» (F-11) beim Eintippen | Beim Merge am 19.11.2026 gefunden: Nach einem Senden mit leerem Preis blieb «Bitte gib einen Preis ein.» stehen und verdeckte den Hinweis. Das Sheet prüft jetzt nach dem ersten Fehlversuch bei jeder Eingabe neu, wie Anmelden und Registrieren. | Gleiches Verhalten in allen Formularen | umgesetzt (19.11.2026) |
| 9.11 | Widget-Tests in `test/offer_screens_test.dart` | Drei Tests blieben hängen (auch ohne Merge): In `testWidgets` steht die Uhr still, das `Future.delayed` im Mock wurde nie fertig. Aufrufe ans Mock ausserhalb der Maske laufen jetzt in `tester.runAsync`. | Tests müssen in jeder Version durchlaufen | umgesetzt (19.11.2026) |
| 9.12 | Dateiablage: Zugriff (F-19, N-04) | Zwei **private** Buckets in `supabase/13_speicher.sql`: `offer-photos` und `chat-photos` (für UC8 vorbereitet). Regeln auf `storage.objects`: Angebotsfotos hochladen nur in den eigenen Ordner (`<uid>/…`), nur zu einem eigenen Angebot mit Status «neu» und höchstens 3 pro Angebot; lesen nur, wer das Angebot sehen darf (`private.can_read_offer`: Verkäufer und Besitzer des Gesuchs); löschen nur eigene, solange «neu»; ändern nie. Chatfotos: hochladen und lesen nur Mitglieder des Chats (`private.is_thread_member`), hochladen nur in den eigenen Unterordner. | Fotos sind persönliche Daten. Öffentliche Links könnte jeder weitergeben. | umgesetzt, Datei im SQL Editor ausführen |
| 9.13 | Fotos: Grösse und Dateityp (Factsheet Inputvalidierung) | Höchstens **5 MB**, nur **JPEG, PNG, WebP**: am Bucket (`file_size_limit`, `allowed_mime_types`), im Repository (`checkOfferPhotoSizes`, vor dem Speichern des Angebots) und in der Maske (zu grosses Foto wird gar nicht erst aufgenommen). Meldung: «Ein Foto ist zu gross (höchstens 5 MB). Bitte wähle ein kleineres.» Falscher Typ: «Nur Fotos im Format JPEG, PNG oder WebP.» | Prüfung in App und Server. Die App verkleinert Fotos auf 1600 px (meist unter 1 MB), die Grenze greift also nur bei Ausnahmen. | umgesetzt |
| 9.14 | F-09: Käufer sieht die Fotos | Links eine Stunde gültig über `createSignedUrlsResult` (ersetzt das veraltete `createSignedUrls`). Pro Foto Erfolg oder Fehler: Fehlt eines, zeigt die App an seiner Stelle ein Symbol, die anderen erscheinen trotzdem. Ein Tipp auf ein Foto in «Gesuch Detail» öffnet es gross, mit zwei Fingern vergrösserbar. | Der Käufer soll den Gegenstand prüfen können (UC7). Die grosse Ansicht ist eine Ergänzung. | umgesetzt |

## 10. Entdecken (UC5, KW 47)

Stand 19.11.2026: FilterLogic, `getFeed` in Mock und Supabase, FeedService,
Funktion `get_feed`, Masken «Entdecken» und «Suchen und filtern». Am
19.11.2026 auf dem Handy mit ben@refind.test und Supabase getestet: TC12 und
TC13 bestanden (Feed zeigt Leica Q2, Leica M6, Eames und Rolex, «Leica» nur
die zwei Leicas). Zwei Anzeigefehler aus dem Test sind behoben (10.13,
10.14). Tests: `test/filter_logic_test.dart`, `test/feed_service_test.dart`,
`test/time_logic_test.dart`, `test/discover_screen_test.dart`,
`test/mock_refind_repository_test.dart` (Gruppe UC5),
`test/supabase_mapping_test.dart`.

| Nr. | Konzept / Erwartung | Umsetzung oder Befund | Grund / nächster Schritt | Status |
|---|---|---|---|---|
| 10.1 | Abbildung 13: FilterLogic im Paket `logic`, «Suchbegriff, Kategorie und Distanz» | Klasse `FilterLogic` in `application/logic/filter_logic.dart` mit statischen Methoden (`matchesQuery`, `matchesCategory`, `isWithinRadius`, `isVisibleInFeed`, `apply`, `hasActiveFilter`). Zusätzlich ein neuer `FeedService` in `application/services`, der die FilterLogic auf die Liste des Repositorys anwendet. | Die Datenzugriffsschicht (Mock, Supabase) darf die Anwendungsschicht nicht kennen. Darum ruft nicht das Repository die FilterLogic auf, sondern der Service. So gelten mit Mock und Supabase dieselben Regeln. | umgesetzt |
| 10.2 | F-06: Feed nur aktive Gesuche, ohne angenommenes Angebot | Funktion `public.get_feed()` (security invoker, RLS `want_select` gilt zusätzlich) und `private.has_accepted_offer(want_id)` (gibt nur ja/nein zurück) in `supabase/10_feed.sql`. Das Mock verhält sich gleich. | Die App darf fremde Angebote wegen RLS `offer_select` nicht lesen und kann «angenommen» deshalb nicht selbst prüfen (siehe 9.2) | umgesetzt, in Supabase ausgeführt (Handytest 19.11.2026) |
| 10.3 | F-07, UC5 Schritt 5: Suchbegriff im **Titel** | Mock und Supabase suchen nur im Titel. Vorher suchten das Mock und das vorläufige `getFeed` auch in der Beschreibung. `%` und `_` gelten nicht als Platzhalter. | Wie im Konzept (TC13) | umgesetzt |
| 10.4 | TC15: Liste mit 100 Einträgen | `getFeed` liefert höchstens **100** Gesuche (`maxFeedItems`), das neueste zuerst. Kein Nachladen weiterer Gesuche. | Mengengerüst. Nachladen erst, wenn es mehr aktive Gesuche gibt. | umgesetzt |
| 10.5 | F-08: Umkreis um eine Ortschaft | Kategorie und Suchbegriff filtert die Datenbank, den Umkreis rechnet die App (FilterLogic, Pythagoras mit LV95). In der Maske kommt der Umkreis erst, «wenn Zeit bleibt». | Für höchstens 100 Gesuche reicht die Rechnung in der App | Logik umgesetzt, Maske offen |
| 10.6 | Prüfung der Filter (Factsheet Inputvalidierung) | Mock und Supabase weisen ab (`checkFeedFilter`): Suchbegriff mit mehr als **80** Zeichen (länger als jeder Titel), unbekannte Kategorie, Umkreis ausserhalb 1–200 km. | Gleiche Regeln wie bei den Gesuchen (Abschnitt 3) | umgesetzt |
| 10.7 | Grenzfälle (nicht im Konzept festgelegt) | Gross- und Kleinschreibung spielt keine Rolle, Leerzeichen am Rand und doppelte Leerzeichen werden ignoriert. Umlaute werden **nicht** vereinheitlicht («mobel» findet «Möbel» nicht). Ein Gesuch, das genau jetzt abläuft, ist weg (wie `expires_at > now()`). Eine Distanz genau gleich dem Umkreis zählt dazu («höchstens», UC5 Schritt 5). | Mit Unittests festgehalten | umgesetzt |
| 10.8 | Testdaten für TC09 bis TC14 | Die Mock-Testdaten entsprechen seit 19.11.2026 `supabase/05_testdaten.sql`: dieselben Konten (Anna, Ben, Cara), Orte, 10 Gesuche, Angebote, Chats, Nachrichten und Bewertungen. Vorher hatte das Mock eigene Daten (Luca, Mia, andere Orte). Lesbare IDs wie `want-leica-m6` oder `offer-eames-ben-2`. Mock und Supabase zeigen jetzt dasselbe, der Handytest mit ben@refind.test läuft auch mit dem Mock. Die Tests sind angepasst, TC14 (Winterthur 20 km) ist jetzt mit echten Testdaten geprüft. | Bei Änderungen an den Testdaten beide Stellen nachführen (`_seed` im Mock und `05_testdaten.sql`) | umgesetzt (19.11.2026) |
| 10.9 | Abbildung 9: «Entdecken» mit Suchfeld, Kategorie-Leiste und Karten | Wie Abbildung 9. Die Leiste zeigt «Alle» und **alle sechs** Kategorien (Abbildung 9 zeigt nur vier) und lässt sich seitlich wischen, weil auf schmalen Handys nicht alle Platz haben. Die gewählte Kategorie gilt sofort (UC5 Schritt 2) und ist mit dem Sheet abgeglichen. | F-06 verlangt alle Kategorien | umgesetzt |
| 10.10 | Abbildung 9: Suchfeld «Wer sucht was?» | Das Feld nimmt keine Eingabe an, ein Tipp öffnet «Suchen und filtern» (UC5 Schritt 3). Ist ein Suchbegriff gesetzt, zeigt das Feld ihn an. | So steht es in UC5. Ohne Anzeige wüsste man nicht, dass ein Filter aktiv ist. | umgesetzt |
| 10.11 | Abbildung 9: «Suchen und filtern» mit Suchbegriff («löschen»), Kategorie, Region & Umkreis | Suchbegriff mit «löschen», Kategorie und «Gesuche anzeigen». **Ohne** «Region & Umkreis» (siehe 10.5). Vorbelegt mit den aktuellen Filtern, Wischen nach unten ändert nichts. Suchbegriff mit mehr als 80 Zeichen: «Der Suchbegriff darf höchstens 80 Zeichen lang sein (jetzt N).» | F-08 laut Auftrag erst, wenn Zeit bleibt | umgesetzt ohne F-08 |
| 10.12 | UC5 Schritt 1: «Zeit seit der Erfassung», Ladezustand | `formatSince` in `application/logic/time_logic.dart`: «gerade eben», «vor N Min», «vor N Std», «vor 1 Tag», «vor N Tagen». Liegt die Zeit wegen einer falschen Handy-Uhr in der Zukunft: «gerade eben». Ladekreis beim ersten Laden, dünner Balken beim Neuladen, «Nochmals versuchen» bei Fehlern, Neuladen durch Ziehen. Eine ältere Antwort überschreibt beim schnellen Wechseln der Kategorie nie eine neuere. | Abbildung 9 zeigt «VOR 20 MIN», «VOR 2 STD», Tage sind nicht gezeichnet | umgesetzt |
| 10.13 | Abbildung 9: Karte mit «bis CHF 4'500» und «Angebot senden» in einer Zeile | Preis und Region stehen in **zwei Zeilen** links vom Knopf. Die Region darf umbrechen und wird nie abgeschnitten. | Handytest 19.11.2026: «bis CHF 3'800 · Be…» war abgeschnitten | umgesetzt (19.11.2026) |
| 10.14 | Abbildung 9: Navigation mit Kreis bei ENTDECKEN | Kompass-Icon (`Icons.explore`), Umriss wenn inaktiv, gefüllt wenn aktiv, wie bei GESUCHE, CHAT und PROFIL | Handytest 19.11.2026: Der gefüllte Kreis wirkte wie ein brauner Punkt, nicht wie ein Icon | umgesetzt (19.11.2026) |

## 11. Gesuche verwalten (UC4, F-05, KW 47)

Stand 20.11.2026: StatusLogic, Pausieren, Aktivieren und Nochmal aufhängen
in Mock und Supabase, Knöpfe in «Gesuch Detail», verbleibende Laufzeit und
eigene Karte für abgelaufene Gesuche in «Meine Gesuche», stündlicher Auftrag
für «abgelaufen». Tests: `test/status_logic_test.dart`,
`test/want_status_screen_test.dart`, `test/my_wants_screen_test.dart`,
`test/time_logic_test.dart`, `test/mock_refind_repository_test.dart` (Gruppe
UC4). Handytest am 20.11.2026 mit Supabase: TC10 und TC11 bestanden. Danach in
«Gesuch Detail» die dritte Sortierung «Teuerste» (F-10, TC18) ergänzt und die
Anzeige verbessert (11.13, 11.14).

| Nr. | Konzept / Erwartung | Umsetzung oder Befund | Grund / nächster Schritt | Status |
|---|---|---|---|---|
| 11.1 | Abbildung 13: StatusLogic «erlaubte Statuswechsel von Gesuch und Angebot nach Abbildung 2» | Klasse `StatusLogic` in `application/logic/status_logic.dart`: die 6 Übergänge beim Gesuch und 4 beim Angebot aus Abbildung 2, «abgelaufen» ab dem Ablaufdatum (auch pausierte, nicht mit angenommenem Angebot), erlaubte Knöpfe je Status, Ablaufdatum beim Nochmal aufhängen, verbleibende Laufzeit. | Wie im Konzept | umgesetzt |
| 11.2 | Abbildung 2, Angebot: «angenommen» nur aus «gesehen» | `StatusLogic` bildet die Abbildung genau ab. `canAcceptOffer` (Team) und `accept_offer` erlauben das Annehmen auch aus «neu». | Das Team hat am 20.11.2026 entschieden: «Annehmen» bleibt aus «neu» und «gesehen» erlaubt. So lässt sich ein Angebot auch annehmen, wenn «gesehen» nicht gespeichert werden konnte (z.B. ohne Verbindung beim Öffnen). | Team-Entscheid 20.11.2026 |
| 11.3 | UC4 Schritt 3 und 6 als Änderung in `want` (RLS want_update) | Datenbank-Funktionen `set_want_status` und `republish_want` in `supabase/11_gesuch_status.sql` (Konzept 4.3 nennt `republish_want`). Sie prüfen Besitzer, erlaubten Wechsel, Ablaufdatum und angenommenes Angebot. Das Recht, `status` und `expires_at` direkt zu ändern, wird zurückgenommen. | RLS `want_update` prüft weder die Übergänge noch angenommene Angebote (UC4, Ausnahme, F-19) | umgesetzt, `11_gesuch_status.sql` am 20.11.2026 ausgeführt |
| 11.4 | UC4 Schritt 6: «Ablaufdatum auf 14 Tage ab heute» | `republish_want` setzt zusätzlich `created_at` auf jetzt: Das Gesuch gilt als neu aufgehängt und steht im Feed und in «Meine Gesuche» zuoberst. | Die CHECK-Regel `want_laufzeit_check` (07) verlangt `expires_at = created_at + 7, 14 oder 30 Tage`. Mit altem `created_at` würde sie die 14 Tage ab heute ablehnen. | umgesetzt |
| 11.5 | UC4 Schritt 5: «Eine zeitgesteuerte Datenbankfunktion setzt den Status stündlich auf abgelaufen» | `private.expire_wants()` und stündlicher Auftrag über pg_cron in `supabase/12_ablauf.sql` (Variante B, vom Nutzer am 20.11.2026 gewählt). Bis der Auftrag läuft, zeigt die App das Gesuch schon ab dem Ablaufdatum als abgelaufen (StatusLogic), `get_feed` blendet es sofort aus. | TC11: «fehlt sofort im Feed» und «spätestens nach einer Stunde abgelaufen» | umgesetzt, pg_cron einschalten und Datei ausführen |
| 11.6 | Status in `wantFromRow` | `wantFromRow` gibt den Status jetzt wie in der Datenbank zurück. Vorher machte es aus einem aktiven Gesuch nach dem Ablaufdatum selbst «abgelaufen», auch bei angenommenem Angebot. Das entscheidet jetzt die StatusLogic. `WantSummary` hat dafür neu `hasAcceptedOffer`. | Eine Stelle für die Regel, und Gesuche mit angenommenem Angebot laufen nicht ab (Kapitel 2.1) | umgesetzt |
| 11.7 | Abbildung 8: oben rechts «● LIVE» oder «2 TAGE» | Beides zusammen: «● LIVE · 5 TAGE», «PAUSIERT · 7 TAGE», «ANGEBOT ANGENOMMEN», «ERLEDIGT». Angefangene Tage werden aufgerundet (13 Tage 23 Std → «14 TAGE», geändert nach dem Handytest vom 20.11.2026: ein frisch aufgehängtes Gesuch zeigte «13 TAGE»), unter einem Tag «N STD» bzw. «N MIN». Auch oben rechts in «Gesuch Detail». | Abbildung 8 zeigt beide Varianten, ohne Regel, wann welche | umgesetzt |
| 11.8 | Abbildung 8: abgelaufene Gesuche als eigene Karte «… – abgelaufen. Nochmal aufhängen?» | Eigene Karte mit Rahmen unter den offenen Gesuchen, erledigte zuletzt. «Nochmal aufhängen?» hängt das Gesuch direkt aus der Liste wieder auf, ein Tipp auf die Karte öffnet das Detail. | Wie Abbildung 8 | umgesetzt |
| 11.9 | Abbildung 8: «Bearbeiten» und «Pausieren» unten in «Gesuch Detail» | Pausieren, Aktivieren oder Nochmal aufhängen stehen oben unter dem Titel, je nach Status. **«Bearbeiten» (UC4 Schritt 4) fehlt noch**, ebenso `updateWant` in Supabase. | Bearbeiten gehört nicht zu F-05 | Bearbeiten offen |
| 11.10 | Meldungen | Ist ein Wechsel nicht mehr erlaubt (z.B. inzwischen ein Angebot angenommen): «Das geht bei diesem Gesuch gerade nicht. Bitte lade es neu.» in Mock und Supabase. Die Status-Funktionen werfen P0001 wie `accept_offer`, `SupabaseRefindRepository` fängt das darum separat ab. | `mapSupabaseError` übersetzt P0001 sonst in die Meldung zu «Angebot annehmen» | umgesetzt |
| 11.11 | Darstellung auf 360 dp (Abbildung 8) | Beim Testen auf 360 dp gefunden und behoben: Zeile «ANGEBOTE (3)» mit Sortier-Chips und Preis mit «ÜBER BUDGET +CHF 100» liefen über (Code aus UC7), beide brechen jetzt um. Auf den Karten gibt die Kategorie nach, wenn der Status lang ist. | Das Testgerät (Samsung SM-S931B) hat 360 dp | umgesetzt (20.11.2026) |
| 11.12 | Mock | `setWantStatus` und `republishWant` im Mock prüfen dieselben Regeln wie die Datenbank-Funktionen. `republishWant` setzt neu 14 Tage ab jetzt (vorher: dieselbe Laufzeit wie zuvor). | Gleiches Verhalten in Mock und Supabase | umgesetzt |
| 11.13 | Abbildung 8: «4 ANGEBOTE» und «Preis ↑» in einer Zeile | Nach dem Handytest vom 20.11.2026 geändert: «ANGEBOTE (n)» steht in einer eigenen Zeile, die Sortier-Chips darunter (vorher klebte «ANGEBOTE (0)» am Chip «Günstigste»). Die Chips erscheinen erst ab **zwei** Angeboten. | Drei Chips passen auf 360 dp nicht neben die Überschrift. Mit 0 oder 1 Angebot gibt es nichts zu sortieren. | umgesetzt (20.11.2026) |
| 11.14 | UC7: Hinweis, wenn noch keine Angebote da sind | Je nach Status: abgelaufen → «Dieses Gesuch ist abgelaufen. Häng es nochmal auf, um Angebote zu bekommen.», pausiert → «Dieses Gesuch ist pausiert. Aktiviere es, um Angebote zu bekommen.» (Ergänzung), sonst wie bisher «Noch keine Angebote. Wir sagen dir Bescheid, sobald eines kommt.» | Handytest 20.11.2026: Bei einem abgelaufenen Gesuch passte «Wir sagen dir Bescheid» nicht | umgesetzt (20.11.2026) |

## 12. Chat und Abschluss (UC8, F-13, F-05, KW 47)

Stand 20.11.2026: Chatliste, «Chat · Verhandlung» mit Text und Fotos in
Echtzeit, nach «Annehmen» direkt in den Chat, «Deal» mit «Deal bestätigt».
Mock und SupabaseRefindRepository (`getChats`, `watchMessages`, `sendText`,
`sendPhoto`, `closeDeal`). Datenbank: `supabase/14_chat.sql`. Tests:
`test/chat_screens_test.dart`, `test/chat_rules_test.dart`,
`test/time_logic_test.dart`, `test/supabase_mapping_test.dart` (Gruppe Chat),
`test/offer_screens_test.dart` (TC19). Auf dem Handy noch nicht getestet.

| Nr. | Konzept / Erwartung | Umsetzung oder Befund | Grund / nächster Schritt | Status |
|---|---|---|---|---|
| 12.1 | UC8 Schritt 1: «Chats» mit Gegenüber, letzter Nachricht, Gesuchstitel, Angebotspreis und **Anzahl ungelesener Nachrichten** | Alles ausser den ungelesenen Nachrichten. Zeit wie Abbildung 10: heute «12:04», «gestern», Wochentag «Mo», älter «19.11.» (`formatChatTime`, Kalendertage in UTC wegen der Zeitumstellung). Abgeschlossene Chats mit «· ERLEDIGT». Die Liste lädt bei jedem Wechsel zu CHAT neu. | Ungelesen braucht die Lesezeit `read_at`, die nur `mark_read` setzt (F-14). Ohne sie würde der Zähler bei Supabase nur wachsen. `ChatSummary` hat dafür neu `offerPriceRappen`. | umgesetzt, ungelesen offen (mit F-14) |
| 12.2 | UC8 Schritt 2: Kopfzeile «Gegenüber mit Bewertung, Gesuchstitel, Angebotspreis» | Gegenüber, Gesuchstitel und Angebotspreis, darunter «ANGEBOT AUF «…»». **Ohne Bewertung** des Gegenübers. | Bewertungen anzeigen ist F-18 (UC9) | Bewertung offen (F-18) |
| 12.3 | Textnachricht: Länge (Factsheet Inputvalidierung) | Höchstens **1000 Zeichen**, nicht leer: in der Maske («Höchstens 1000 Zeichen (jetzt N).», «Senden» nicht aktiv), im Repository (`checkMessageText`) und als CHECK `message_body_check` in der Datenbank. `MessageLimits` in `model/message.dart`. | Wert im Konzept offen (Vorschlag) | Vorschlag, vom Team zu bestätigen |
| 12.4 | UC8 Ausnahme: «markiert sie als nicht gesendet und bietet an, sie erneut zu senden» | Wie im Konzept: Die Nachricht bleibt sichtbar mit «Nicht gesendet · Nochmal versuchen». Bei einem Foto: Meldung mit «Nochmal». | – | umgesetzt |
| 12.5 | UC8 Schritt 3 und Konzept S4: Echtzeit, RLS gilt auch dort (TC20, TC27) | `watchMessages` mit dem Echtzeit-Stream von Supabase auf `message`, Filter `thread_id`. `14_chat.sql` nimmt `message` in die Publication `supabase_realtime` auf. Realtime prüft die RLS-Regel `message_select`: Ein fremder Chat liefert nichts. | Wie im Konzept | umgesetzt, Datei ausführen |
| 12.6 | Zeit und Reihenfolge der Nachrichten | Trigger in `14_chat.sql`: Bei Nachrichten aus der App setzt der Server `created_at` (nicht das Handy) und führt `chat_thread.last_activity` nach. Für Einfügungen im SQL Editor (`05_testdaten.sql`) gilt das nicht, damit die Testdaten ihre Zeiten behalten. | Sonst liesse sich eine Nachricht zurückdatieren. `last_activity` darf die App nicht direkt ändern (03_rechte.sql). | umgesetzt |
| 12.7 | Fotos im Chat (UC8 Schritt 3, Konzept S3) | Bucket `chat-photos` (13_speicher.sql), Pfad `<thread_id>/<uid>/<zeit>.<typ>`, Nachricht vom Typ «foto» mit dem Pfad (CHECK prüft den Ordner). Links eine Stunde gültig, einmal pro Pfad signiert. Höchstens 5 MB, JPEG/PNG/WebP. Ein Tipp öffnet das Foto gross. Die Buckets heissen `offer-photos` und `chat-photos` (Konzept: `offer_photos`, `chat_photos`), `avatars` fehlt noch (UC2). | Bindestrich ist bei Supabase üblich, die Namen stehen nur in `app_config.dart` und 13 | umgesetzt |
| 12.8 | UC7 Schritt 6 / TC19: nach «Annehmen» «Chat · Verhandlung» | Der Chat öffnet sich mit Gegenüber, Gesuchstitel und Preis (lädt die Kopfzeile selbst nach) und man kann gleich schreiben. Ersetzt den Platzhalter aus 9.8. | – | umgesetzt (9.8 erledigt) |
| 12.9 | UC8 Schritt 7: «Deal», vorbelegter Preis, bestätigen, Gesuch «erledigt» (F-05, TC24) | Sheet «Deal abschliessen» mit dem Angebotspreis vorbelegt (gleiche Prüfung wie beim Angebot: grösser als CHF 0, höchstens CHF 10'000) und dem Hinweis, dass es nicht rückgängig geht. Danach «Deal bestätigt» («Gefunden.», Abschluss mit Preis, Titel, Gegenüber) und im Chat «DEAL ABGESCHLOSSEN · CHF …». In Supabase über die Funktion `close_deal` (Konzept 4.3) in `14_chat.sql`: nur der Käufer, nur einmal, Gesuch muss aktiv sein, CHECK auf den Preis. | Wie im Konzept | umgesetzt, Datei ausführen |
| 12.10 | UC8 Ausnahme: «Beim Verkäufer erscheint die Schaltfläche Deal nicht» | Wie im Konzept, zusätzlich auch nicht mehr nach dem Abschluss (`canCloseDeal`). | – | umgesetzt |
| 12.11 | Abbildung 11: «Marc bewerten» in «Deal bestätigt» | Nur «Fertig». | Bewerten ist F-17 (UC9) | offen (F-17) |
| 12.12 | F-14 Lesebestätigung, F-15 Übergabe festhalten, F-16 Pushmitteilungen | Noch nicht umgesetzt (auf Wunsch zurückgestellt). Im Mock gibt es `markRead` und `setHandover` schon, in Supabase nicht. Die Platzhalter `handover_sheet.dart` und `rating_sheet.dart` sind noch da, aber nicht mehr verlinkt. | Zurückgestellt am 20.11.2026 | offen |
