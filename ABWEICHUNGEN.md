# Abweichungen vom Konzeptbericht

Bezug: *2_1_Konzeptbericht_refind*, Speicherdatum 29.10.2026.
Stand: 12.11.2026 (KW 46), nach Anmelden/Registrieren (UC1) und Gesuch erfassen (UC3).

Diese Liste ist die Grundlage für den Realisierungsbericht. Jede Abweichung
hat einen Status:

- **umgesetzt**: so im Code, Begründung reicht für den Bericht
- **Team entscheiden**: Annahme im Code, das Team muss sie bestätigen oder ändern
- **offen**: im Konzept verlangt, aber noch nicht umgesetzt

---

## 1. Schnittstelle RefindRepository (Kapitel 4.3.2)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 1.1 | Methoden von `signUp` bis `getProfileStats` | Neue Methode `Future<void> resendConfirmation(String email)` | UC1, Ausnahme «Mailadresse noch nicht bestätigt»: Die App soll anbieten, die Mail erneut zu senden. Ohne diese Methode geht das nicht. Die Methode verrät nicht, ob es das Konto gibt. | umgesetzt |
| 1.2 | Methoden von `signUp` bis `getProfileStats` | Neue Methode `Future<Place> getPlace(int placeId)` | UC3 Schritt 4: Die Region ist mit dem Wohnort vorbelegt. Das Profil kennt nur `cityId`. Um «Bern» anzuzeigen, muss die Ortschaft gelesen werden. | umgesetzt |
| 1.3 | `RepositoryException` mit vier Arten: keine Verbindung, nicht berechtigt, ungültige Eingabe, Konflikt | Fünfte Art `mailNichtBestaetigt` | Die Maske muss «nicht bestätigt» von «falsches Passwort» unterscheiden, damit sie «Mail erneut senden» nur im richtigen Fall zeigt. | umgesetzt |
| 1.4 | `getOffers(String wantId, OfferSort sort)`, Werte von `OfferSort` nicht festgelegt | `OfferSort { neueste, guenstigste }` | Kapitel 3.3 verlangt die Sortierung nach Preis (`guenstigste`). `neueste` (nach Datum) ist eine Ergänzung, die noch keine Maske nutzt. | Team entscheiden |

## 2. Fachliche Entitätstypen und Hilfsklassen (Kapitel 2.1, 4.3.2)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 2.1 | `User.cityID : int` (Pflicht) | `int? cityId` (darf leer sein) | Die Maske «Registrieren» (UC1) fragt keinen Wohnort ab. Ein neues Konto hat also zuerst keinen Wohnort. Er wird in «Profil bearbeiten» (UC2) ergänzt. Bis dahin muss die Region in UC3 von Hand gewählt werden. | umgesetzt |
| 2.2 | `WantSummary` ergänzt `Want` um Zähler | Zusätzlich das Feld `region : Place` | «Meine Gesuche» zeigt je Gesuch die Region (Kapitel 3.3). Ohne das Feld bräuchte jede Karte einen eigenen Datenzugriff. | umgesetzt |
| 2.3 | `Photo` ist eine eigene Entität mit `offerID` | `Offer` trägt zusätzlich die Liste `photos` | Bequemer für die Anzeige der Angebotsliste. In der Datenbank bleibt `photo` eine eigene Tabelle. | umgesetzt |
| 2.4 | Paket `model` enthält die Klassen der Entitätstypen | Zusätzlich Grenzwerte (`account_limits.dart`, `WantLimits` in `want.dart`) und die Zustandsliste | Maske (Anwendungsschicht) und Repository (Datenzugriffsschicht) brauchen dieselben Werte. Im Paket `model` dürfen beide Schichten sie verwenden, ohne die Schichtrichtung zu verletzen. | umgesetzt |

## 3. Eingaberegeln und Grenzwerte (Inputvalidierung, Modul 183)

Das Konzept und das Factsheet Inputvalidierung lassen diese Werte offen
(«Noch offen: Längen, Maximalpreis …»). Die Werte stehen je an einer Stelle
im Code und gelten in der Maske **und** im Repository. Bei Supabase müssen
dieselben Werte als CHECK-Regeln bzw. in den Auth-Einstellungen stehen.

| Nr. | Feld | Regel im Code | Stelle im Code | Status |
|---|---|---|---|---|
| 3.1 | Passwort | mindestens **8**, höchstens **72** Zeichen. 72, weil bcrypt (N-04) nur 72 Bytes berücksichtigt. | `model/account_limits.dart` | Team entscheiden |
| 3.2 | Anzeigename | Pflicht, höchstens **40** Zeichen | `model/account_limits.dart` | Team entscheiden |
| 3.3 | Mailadresse | Format `name@domain.tld` | `application/logic/account_rules.dart` | umgesetzt |
| 3.4 | Titel des Gesuchs | Pflicht, höchstens **80** Zeichen (Vorschlag aus dem Factsheet) | `WantLimits.maxTitleLength` | umgesetzt |
| 3.5 | Beschreibung | **freiwillig**, höchstens **1000** Zeichen. F-03 nennt die Beschreibung, die Ausnahmen in UC3 verlangen aber nur Titel, Kategorie und Preisobergrenze. | `WantLimits.maxDescriptionLength` | Team entscheiden |
| 3.6 | Preisobergrenze | grösser als **CHF 0**, höchstens **CHF 10'000**, Regler in Schritten von **CHF 50**. Abbildung 7 zeigt einen Regler bis CHF 3'200. Das reicht für Möbel nicht (Testdaten: Eames CHF 4'500). | `WantLimits.maxBudgetRappen`, `budgetStepRappen` | Team entscheiden |
| 3.7 | Kategorie | nur die sechs Kategorien aus Kapitel 2.1 (Whitelist) | `kategorien` in `model/want.dart` | umgesetzt |
| 3.8 | Umkreis | Auswahl 10/20/30/50/100 km plus Wert aus dem Profil, erlaubt 1–200 km | `WantLimits.radiusOptions`, `maxRadiusKm` | Team entscheiden |
| 3.9 | Laufzeit | Auswahl **7, 14 oder 30 Tage**, vorbelegt 14 (UC3) | `WantLimits.durationOptions` | Team entscheiden |

## 4. Zustände je Kategorie (Kapitel 2.1)

Das Konzept legt nur die Uhren fest («Original», «Serviciert», «Egal»).
Die übrigen Kategorien soll das Team «zu Beginn der Realisierung» festlegen.
Im Code steht ein **Vorschlag** (`zustaende` in `model/want.dart`). Der letzte
Wert ist jeweils «Egal» und vorausgewählt.

| Kategorie | Zustände | Status |
|---|---|---|
| Uhren | Original, Serviciert, Egal | aus dem Konzept |
| Möbel | Wie neu, Gebraucht, Egal | Team entscheiden |
| Velo | Fahrbereit, Revisionsbedürftig, Egal | Team entscheiden |
| Vinyl | Neuwertig, Sehr gut, Egal | Team entscheiden |
| Kameras | Voll funktionsfähig, Mit Mängeln, Egal | Team entscheiden |
| Werkzeug | Neu, Gebraucht, Egal | Team entscheiden |

## 5. Masken und Abläufe (Kapitel 3, UC1, UC3)

| Nr. | Konzept | Umsetzung | Grund | Status |
|---|---|---|---|---|
| 5.1 | UC1: «Die Zahl der Anmeldeversuche ist begrenzt» (ohne Zahl) | Im Mock: nach **5** Fehlversuchen **1 Minute** gesperrt. Bei Supabase legt der Anmeldedienst die Grenze fest. | TC02 testbar machen | umgesetzt (Mock) |
| 5.2 | UC1 Schritt 5: Bestätigung über den Link in der Mail | Im Mock bestätigt «Mail erneut senden» das Konto sofort | Der Mock verschickt keine Mails. So lässt sich TC01 ohne Supabase durchspielen. | umgesetzt (Mock) |
| 5.3 | UC1 Ausnahme «Mailadresse bereits registriert» | Meldung «Die Registrierung ist mit diesen Angaben nicht möglich.» | Verrät nichts über das bestehende Konto, wie UC1 verlangt (siehe auch Factsheet, «Was kann schiefgehen?», Punkt 3: zu genaue Fehlermeldungen) | umgesetzt |
| 5.4 | Kapitel 2.3: Fehlende Verbindung → Meldung, Eingaben behalten, wiederholen | Wie im Konzept. Zusätzlich zeigt ein **unerwarteter Fehler** «Etwas ist schiefgelaufen. Bitte versuche es nochmals.» | Kein stiller Absturz | umgesetzt |
| 5.5 | Abbildung 4: «ändern» bei Region, Umkreis und Laufzeit, ohne eigene Maske | Zwei zusätzliche Sheets: «Region & Umkreis» (Ortssuche und Umkreis) und «Wie lange sichtbar?» | Irgendwo müssen die neuen Werte eingegeben werden. Die Sheets folgen dem Muster aus Kapitel 3.1. | umgesetzt |
| 5.6 | Abbildung 13, Paket `logic`: PriceLogic, StatusLogic, FilterLogic | Zusätzlich `account_rules.dart` und `want_rules.dart` | Die Eingaberegeln sind Fachlogik ohne Netz und lassen sich mit Unittests prüfen (N-08). | umgesetzt |
| 5.7 | Abbildung 13: Masken je Paket | Zusätzlich `SessionGate` (wählt nach der Sitzung «Anmelden» oder «Meine Gesuche», UC1 Schritt 1) und `HomeShell` (Navigationsleiste) | Technische Bausteine, keine eigenen Masken | umgesetzt |
| 5.8 | Darstellung für iPhone gezeichnet | Android: Systemleiste, Tastatur und Zurück-Taste von Android. Die Zurück-Taste geht im Assistenten einen Schritt zurück. | refind ist eine Android-App (Kapitel 3) | umgesetzt |

## 6. Noch nicht umgesetzt (offen)

| Nr. | Konzept | Stand |
|---|---|---|
| 6.1 | UC1 Schritt 8: Erlaubnis für Mitteilungen und Pushtoken anmelden | folgt mit Firebase Cloud Messaging |
| 6.2 | UC1 Kurzbeschreibung: «Die Sitzung bleibt bestehen, bis sie sich abmeldet» | Mit dem Mock ist die Sitzung nach einem Neustart der App weg. Mit Supabase speichert `supabase_flutter` die Sitzung. |
| 6.3 | UC4 in «Meine Gesuche»: Pausieren, Bearbeiten, eigene Karte für abgelaufene Gesuche, verbleibende Laufzeit | Die Liste zeigt bereits Kategorie, Status, Titel, Preisobergrenze, Region und Angebote. Der Rest folgt mit UC4. |
| 6.4 | Alle übrigen Masken aus Abbildung 4 | Platzhalter mit den Wegen aus Abbildung 4 |
| 6.5 | `SupabaseRefindRepository` und CHECK-Regeln in der Datenbank | KW 47 laut Detailplanung. Die Grenzwerte aus Abschnitt 3 dort gleich übernehmen. |

## 7. Projekt-Einstellungen (nicht im Konzept festgelegt)

| Nr. | Einstellung | Wert |
|---|---|---|
| 7.1 | Paket-ID der Android-App | `ch.refind.refind` |
| 7.2 | Plattformen | nur Android (kein iOS, Web, Desktop) |
| 7.3 | Zustandsverwaltung | Paket `provider`, wie in der Studie vorgesehen (Kapitel 4.2.2) |
| 7.4 | Umsetzung des Repository beim Start | `lib/app_config.dart`, im Moment `RepositoryMode.mock` |
