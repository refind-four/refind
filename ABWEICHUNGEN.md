# Abweichungen vom Konzeptbericht

Bezug: *2_1_Konzeptbericht_refind*, Speicherdatum 29.10.2026.
Stand: 12.11.2026 (KW 46), nach Anmelden/Registrieren (UC1), Gesuch erfassen (UC3)
und SupabaseRefindRepository für UC1 und UC3 (Abschnitt 8).
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
| 1.4 | `getOffers(String wantId, OfferSort sort)`, Werte von `OfferSort` nicht festgelegt | `OfferSort { neueste, guenstigste }` | Kapitel 3.3 verlangt die Sortierung nach Preis (`guenstigste`). `neueste` (nach Datum) ist eine Ergänzung, die noch keine Maske nutzt. | vom Team bestätigt (12.11.2026) |

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
| 3.1 | Passwort | mindestens **8**, höchstens **72** Zeichen. 72, weil bcrypt (N-04) nur 72 Bytes berücksichtigt. | `model/account_limits.dart` | vom Team bestätigt (12.11.2026) |
| 3.2 | Anzeigename | Pflicht, höchstens **40** Zeichen | `model/account_limits.dart` | vom Team bestätigt (12.11.2026) |
| 3.3 | Mailadresse | Format `name@domain.tld` | `application/logic/account_rules.dart` | umgesetzt |
| 3.4 | Titel des Gesuchs | Pflicht, höchstens **80** Zeichen (Vorschlag aus dem Factsheet) | `WantLimits.maxTitleLength` | umgesetzt |
| 3.5 | Beschreibung | **freiwillig**, höchstens **1000** Zeichen. F-03 nennt die Beschreibung, die Ausnahmen in UC3 verlangen aber nur Titel, Kategorie und Preisobergrenze. | `WantLimits.maxDescriptionLength` | vom Team bestätigt (12.11.2026) |
| 3.6 | Preisobergrenze | grösser als **CHF 0**, höchstens **CHF 10'000**, Regler in Schritten von **CHF 50**. Abbildung 7 zeigt einen Regler bis CHF 3'200. Das reicht für Möbel nicht (Testdaten: Eames CHF 4'500). | `WantLimits.maxBudgetRappen`, `budgetStepRappen` | vom Team bestätigt (12.11.2026) |
| 3.7 | Kategorie | nur die sechs Kategorien aus Kapitel 2.1 (Whitelist) | `kategorien` in `model/want.dart` | umgesetzt |
| 3.8 | Umkreis | Auswahl 10/20/30/50/100 km plus Wert aus dem Profil, erlaubt 1–200 km | `WantLimits.radiusOptions`, `maxRadiusKm` | vom Team bestätigt (12.11.2026) |
| 3.9 | Laufzeit | Auswahl **7, 14 oder 30 Tage**, vorbelegt 14 (UC3) | `WantLimits.durationOptions` | vom Team bestätigt (12.11.2026) |

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
| 6.3 | UC4 in «Meine Gesuche»: Pausieren, Bearbeiten, eigene Karte für abgelaufene Gesuche, verbleibende Laufzeit | Die Liste zeigt bereits Kategorie, Status, Titel, Preisobergrenze, Region und Angebote. Der Rest folgt mit UC4. |
| 6.4 | Alle übrigen Masken aus Abbildung 4 | Platzhalter mit den Wegen aus Abbildung 4 |
| 6.5 | `SupabaseRefindRepository` für UC2 und UC4 bis UC9 | Folgt mit den Use Cases. Diese Methoden werfen im Moment `UnimplementedError` («folgt mit UCx»). Die App ruft sie noch nirgends auf. |

## 7. Projekt-Einstellungen (nicht im Konzept festgelegt)

| Nr. | Einstellung | Wert |
|---|---|---|
| 7.1 | Paket-ID der Android-App | `ch.refind.refind` |
| 7.2 | Plattformen | nur Android (kein iOS, Web, Desktop) |
| 7.3 | Zustandsverwaltung | Paket `provider`, wie in der Studie vorgesehen (Kapitel 4.2.2) |
| 7.4 | Umsetzung des Repository beim Start | `lib/app_config.dart`, Konstante `repositoryMode` (`mock` oder `supabase`), im Moment `supabase`. Nach dem Umschalten Hot Restart (`R`). Die Tests benutzen immer das Mock. |
| 7.5 | Verbindung zu Supabase | URL und publishableKey nur in `lib/app_config.dart` (`SupabaseConfig`). Der publishableKey ist öffentlich, was er darf, bestimmen die RLS-Regeln. Der service_role-Schlüssel ist nicht in der App. |
| 7.6 | Zusätzliche Pakete | `supabase_flutter` (Backend), `http` (um «keine Verbindung» sicher zu erkennen) |
| 7.7 | Android-Berechtigung | `INTERNET` im `AndroidManifest.xml`, nötig für die fertige App (Release) |
| 7.8 | Datenbankschema | SQL-Export in `supabase/01` bis `04`, vorläufige Ortschaften in `supabase/05_orte_vorlaeufig.sql` |

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
| 8.7 | Status «abgelaufen» (Abbildung 2) | Kein Auftrag in der Datenbank setzt Gesuche auf «abgelaufen». Die App zeigt ein aktives Gesuch mit vergangenem `expires_at` als «abgelaufen» an. Die RLS-Regel `want_select` blendet es im Feed schon richtig aus. | Später ein geplanter Auftrag in Supabase (z.B. pg_cron), der den Status setzt | offen |
| 8.8 | Ortssuche (Wohnort, Region) | `searchPlaces` sucht bei Ziffern nach dem Beginn der PLZ («30» findet 3000–3099), sonst im Ortsnamen. Höchstens 20 Treffer. `%` und `_` aus der Eingabe gelten nicht als Platzhalter. | Schnelle Antwort, keine Platzhalter von aussen | umgesetzt |
| 8.9 | Beschreibung freiwillig (3.5) | Leere Beschreibung wird in der Datenbank als `NULL` gespeichert, die App zeigt sie als leeren Text. | Spalte `description` darf leer sein | umgesetzt |
| 8.10 | UC1 Schritt 5: Bestätigungsmail | Der eingebaute Mailversand von Supabase schickt **nur an Mailadressen von Mitgliedern des Supabase-Teams** und nur wenige Mails pro Stunde. Die Testkonten `…@refind.test` lassen sich darum nicht über die App bestätigen. Getestet mit einer echten Mailadresse. | Eigenen Mailserver (SMTP) in Supabase eintragen. Bis dahin Testkonten im Dashboard von Hand bestätigen (Authentication → Users) | offen |
| 8.11 | UC1 Schritt 5: Link in der Mail bestätigt das Konto | Der Link führt nach der Bestätigung auf `localhost:3000` («Seite nicht erreichbar»). Die Bestätigung selbst klappt. Grund: Die «Site URL» im Projekt steht noch auf dem Standardwert. | Site URL und Redirect URLs einstellen (Authentication → URL Configuration), z.B. eine einfache Seite «Konto bestätigt, zurück zur App» oder einen Link direkt in die App | offen |
| 8.12 | Ortschaftenverzeichnis von swisstopo (Konzept 2.1) | Die Tabelle `place` war leer, darum liess sich keine Region wählen. Übergang: 8 Orte (Bern, Zürich, Winterthur, Basel, Luzern, St. Gallen, Lausanne, Genève) in `supabase/05_orte_vorlaeufig.sql`. Das Mock hat andere Beispielorte (u.a. Thun, Biel, Burgdorf). | Ganzes Ortschaftenverzeichnis mit LV95-Koordinaten importieren | Übergang mit 05_testdaten.sql |
| 8.13 | Pushtoken beim Abmelden entfernen (Kapitel 4.3.2) | `signOut` löscht die Zeilen in `push_token` und meldet dann ab. Darum braucht das Abmelden mit Supabase eine Verbindung. | Nach dem Abmelden keine Mitteilungen mehr | umgesetzt |
