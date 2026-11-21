# refind – Fakten für das Installationshandbuch

Stand: 20.11.2026. Alle Werte am Projekt geprüft (Befehle, Dateien, Build).

---

## 1. Werkzeuge und Versionen

| Werkzeug | Version | Prüfen mit |
|---|---|---|
| Flutter | 3.47.5, Kanal stable (Framework 6a19cca564 vom 17.09.2026) | `flutter --version` |
| Dart | 3.13.4 (in Flutter enthalten) | `flutter --version` |
| DevTools | 2.60.0 | `flutter --version` |
| Dart-SDK im Projekt | `^3.13.4` | `pubspec.yaml`, `environment.sdk` |
| Java für Android | 17 (`JavaVersion.VERSION_17`, `jvmTarget` 17) | `android/app/build.gradle.kts` |
| Android-Werkzeuge | Android SDK mit platform-tools (`adb`), Lizenzen akzeptiert | `flutter doctor` |

Wichtige Pakete (`pubspec.yaml`): `supabase_flutter` ^2.18.3, `provider`
^6.1.5+1, `http` ^1.6.0, `image_picker` ^1.1.2.

---

## 2. Android-Einstellungen

| Einstellung | Wert | Wo |
|---|---|---|
| Paket-ID (applicationId, namespace) | `ch.refind.refind` | `android/app/build.gradle.kts` |
| App-Name | `refind` | `AndroidManifest.xml`, `android:label` |
| Version | `1.0.0+1` (versionName 1.0.0, versionCode 1) | `pubspec.yaml`, `version` |
| minSdk | **24** (Android 7.0) | Standard von Flutter 3.47.5 (`flutter.minSdkVersion`) |
| targetSdk | **36** | Standard von Flutter (`flutter.targetSdkVersion`) |
| compileSdk | **36** | Standard von Flutter (`flutter.compileSdkVersion`) |
| Berechtigung | `android.permission.INTERNET` | `AndroidManifest.xml` |
| Deep Link | Schema `ch.refind.app`, Host `login-callback` | `AndroidManifest.xml`, Intent-Filter |
| Signatur Release | Debug-Schlüssel (`signingConfigs.debug`, Vorgabe von Flutter) | `build.gradle.kts` |
| Testgerät | Samsung SM-S931B, Android 17 | `adb shell getprop ro.build.version.release` |

Hinweis N-01 («Android ab Version 10»): Die App läuft technisch ab Android 7
(minSdk 24), getestet ist sie auf Android 17. Für den Store bräuchte es einen
eigenen Signaturschlüssel statt des Debug-Schlüssels.

---

## 3. APK bauen

| Schritt | Befehl / Ergebnis |
|---|---|
| Abhängigkeiten holen | `flutter pub get` |
| Release-APK bauen | `flutter build apk --release` |
| Ergebnis | `build/app/outputs/flutter-apk/app-release.apk` |
| Grösse (Build vom 20.11.2026) | 53.3 MB (55'930'546 Bytes), Bauzeit rund 3 Minuten |
| Vorher prüfen | `flutter analyze` (keine Hinweise), `flutter test` (254 Tests) |

Die App verbindet sich mit dem Backend, das in `lib/app_config.dart`
eingestellt ist (Abschnitt 5). Für eine APK ohne Internet und ohne Supabase
`repositoryMode` auf `RepositoryMode.mock` stellen.

### 3.1 Build-Ergebnis vom 20.11.2026

```
Running Gradle task 'assembleRelease'...    171.9s
√ Built build\app\outputs\flutter-apk\app-release.apk (53.3MB)
```

Die APK enthält Code für alle Prozessoren (arm64, arm, x86_64). Kleinere,
gerätespezifische Dateien: `flutter build apk --release --split-per-abi`
(Ergebnis z.B. `app-arm64-v8a-release.apk` für heutige Handys).

---

## 4. APK aufs Handy bringen

**Variante A – per USB (Entwickler):**

1. Auf dem Handy: Einstellungen → Telefoninfo → Softwareinformationen →
   7× auf «Buildnummer» tippen (Entwickleroptionen an), dann
   Einstellungen → Entwickleroptionen → «USB-Debugging» einschalten.
2. Handy mit einem **Datenkabel** anschliessen, «USB-Debugging zulassen» bestätigen.
3. Prüfen: `adb devices` zeigt das Gerät (z.B. `RZCY31F5W2H device`).
   `adb` liegt unter `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
4. Installieren: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
   oder `flutter install -d <Geräte-ID>`.
   (`-r` ersetzt eine vorhandene Version und behält die Anmeldung.)

**Variante B – ohne Kabel (Testpersonen):**

1. `app-release.apk` per Mail, Teams oder Cloud aufs Handy kopieren.
2. Datei antippen; Android fragt nach «Unbekannte Apps installieren» für die
   App, mit der die Datei geöffnet wurde (z.B. «Eigene Dateien»): erlauben.
3. «Installieren» antippen. Play Protect warnt eventuell (unbekannter
   Entwickler): «Trotzdem installieren».

**Zum Entwickeln** (mit Hot Reload): `flutter run -d <Geräte-ID>`.

---

## 5. `lib/app_config.dart` für ein neues Supabase-Projekt

| Wert | Bedeutung | Ändern? |
|---|---|---|
| `repositoryMode` | `RepositoryMode.supabase` (Betrieb) oder `.mock` (ohne Backend) | ja, je nach Zweck |
| `SupabaseConfig.url` | Project URL, z.B. `https://<projekt-ref>.supabase.co` | **ja** |
| `SupabaseConfig.publishableKey` | Publishable key (`sb_publishable_…`), öffentlich | **ja** |
| `SupabaseConfig.offerPhotoBucket` | `'offer-photos'` | nein, solange `13_speicher.sql` benutzt wird |
| `SupabaseConfig.chatPhotoBucket` | `'chat-photos'` | nein, wie oben |
| `SupabaseConfig.authRedirectUrl` | `'ch.refind.app://login-callback'` | nein; wenn doch, auch Intent-Filter und Dashboard ändern |

URL und publishableKey stehen im Dashboard unter **Project Settings → API
Keys** (publishable key) bzw. **Project Settings → Data API** (Project URL),
oder über den Knopf **«Connect»** oben im Dashboard. Den **service_role / secret
key nie** in die App eintragen.

Nach einer Änderung: App neu starten (`R`) bzw. APK neu bauen.

---

## 6. Datenbank einrichten: Reihenfolge der SQL-Dateien

Alle Dateien im Dashboard unter **SQL Editor** ausführen (Rolle `postgres`).

| Schritt | Datei | Hinweis |
|---|---|---|
| 1 | `01_tabellen.sql` | **Export, laut Kopfzeile nicht direkt ausführbar** («for context only»). Für ein neues Projekt die Struktur aus einem Backup (`schema.sql`, Abschnitt 8) einspielen; das ersetzt 01–04 und 07–11, 14 (Teile in public/private). |
| 2 | `02_rls_regeln.sql` | RLS auf allen Tabellen |
| 3 | `03_rechte.sql` | Tabellen- und Spaltenrechte |
| 4 | `04_funktionen.sql` | Hilfsfunktionen und Trigger `on_auth_user_created` |
| 5 | `07_check_regeln.sql` | erst **Teil A** allein (muss 0 Zeilen liefern), dann **Teil B** |
| 6 | `08_angebot_annehmen.sql` | `accept_offer` |
| 7 | `09_angebote.sql` | `mark_offers_seen`, CHECK Angebot, max. 3 Fotos |
| 8 | `10_feed.sql` | `get_feed` |
| 9 | `11_gesuch_status.sql` | Pausieren, Aktivieren, Nochmal aufhängen |
| 10 | `12_ablauf.sql` | **vorher pg_cron einschalten** (Abschnitt 7) |
| 11 | `13_speicher.sql` | Buckets und Storage-Regeln |
| 12 | `14_chat.sql` | erst **Teil A**, dann **Teil B** |
| 13 | `15_konto_loeschen.sql` | Konto löschen, Löschregeln eigener Ordner |
| 14 | Testkonten anlegen | Abschnitt 7 |
| 15 | `05_testdaten.sql` | braucht die drei Testkonten; mehrmals ausführbar (setzt die Testdaten zurück) |

`06_…` gibt es nicht. `tests_datenzugriff.sql` sind Prüfungen (T1–T8), keine
Einrichtung.

---

## 7. Einstellungen im Supabase-Dashboard

| Wo | Einstellung | Wert |
|---|---|---|
| Database → Extensions | `pg_cron` | eingeschaltet (vor `12_ablauf.sql`) |
| Authentication → URL Configuration | Site URL | `ch.refind.app://login-callback` |
| Authentication → URL Configuration | Redirect URLs | `ch.refind.app://login-callback` hinzufügen |
| Authentication → Sign In / Providers → Email | Confirm email | eingeschaltet |
| Authentication → Sign In / Providers → Email | Minimum password length | 8 (wie `minPasswordLength` in `lib/model/account_limits.dart`) |
| Authentication → Users → **Add user → Create new user** | Testkonten | `anna@refind.test`, `ben@refind.test`, `cara@refind.test`, Passwort `refind123`, **«Auto Confirm User» ankreuzen** (die Mail kommt bei `…@refind.test` nie an) |

Kontrollen nach der Einrichtung (SQL Editor):

- pg_cron: `select jobid, jobname, schedule from cron.job;` → `expire_wants`, `0 * * * *`
- Buckets: `select id, public, file_size_limit from storage.buckets;` → 2 Zeilen, `public = false`
- Echtzeit: `select * from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'message';` → 1 Zeile
- Konto löschen: `select proname from pg_proc where proname in ('account_photo_paths', 'delete_own_account');` → 2 Zeilen

Mailversand: eingebauter Versand von Supabase (nur an Mitglieder des
Supabase-Teams, wenige Mails pro Stunde); kein eigenes SMTP (ABWEICHUNGEN 8.10).

---

## 8. Datensicherung (Konzept 4.4)

### 8.1 Ablauf

`.github/workflows/backup.yml` (GitHub Actions):

| Punkt | Wert |
|---|---|
| Zeitplan | täglich 02:30 UTC (03:30 MEZ) und von Hand: Actions → «Datenbank-Backup» → «Run workflow» (vor jeder Abgabe) |
| Werkzeug | `pg_dump` 17 (offizielles Paketarchiv von PostgreSQL) |
| Inhalt | `schema.sql` (public, private: Tabellen, RLS, Rechte, Funktionen), `data_public.sql`, `data_auth.sql` (auth.users, auth.identities) |
| Schutz | verschlüsselt mit AES-256 (gpg), Passwort im Secret `BACKUP_PASSPHRASE` |
| Ablage | Artifact `refind-backup-<datum>` mit `refind-backup.tar.gz.gpg`, **30 Tage** |
| Nicht enthalten | Fotos (Storage-Dateien), Buckets, Storage-Regeln, pg_cron-Auftrag, Publication, Trigger auf auth.users |

### 8.2 Secrets in GitHub

Repository `refind-four/refind` → **Settings → Secrets and variables →
Actions → New repository secret**:

| Name | Wert |
|---|---|
| `SUPABASE_DB_URL` | Verbindungsadresse «Session pooler» (unten), mit eingesetztem Datenbank-Passwort |
| `BACKUP_PASSPHRASE` | langes, zufälliges Passwort für die Verschlüsselung; zusätzlich im Team sicher aufbewahren (ohne es lässt sich kein Backup öffnen) |

**Verbindungsadresse in Supabase:** Dashboard → Knopf **«Connect»** oben →
Abschnitt **«Connection String»** → Typ **URI** → **«Session pooler»**:

```
postgresql://postgres.<projekt-ref>:[YOUR-PASSWORD]@aws-0-<region>.pooler.supabase.com:5432/postgres
```

`[YOUR-PASSWORD]` durch das Datenbank-Passwort ersetzen (gesetzt beim Anlegen
des Projekts; neu setzen unter Project Settings → Database → «Reset database
password»). Nicht die «Direct connection» (`db.<ref>.supabase.co`) nehmen: Sie
ist nur über IPv6 erreichbar, die Server von GitHub Actions haben kein IPv6.
Enthält das Passwort Sonderzeichen wie `@ : / ?`, müssen sie in der URL
kodiert werden (z.B. `@` → `%40`).

### 8.3 Backup wiederherstellen

Voraussetzungen: PostgreSQL-Client 17 (`psql`), `gpg`, `tar`; ein **leeres
neues** Supabase-Projekt (in ein bestehendes Projekt einspielen gibt Konflikte
mit vorhandenen Tabellen und Konten).

1. Auf GitHub: Actions → Lauf auswählen → Artifact `refind-backup-<datum>`
   herunterladen und entpacken (ZIP).
2. Entschlüsseln und auspacken:
   ```
   gpg --decrypt --output refind-backup.tar.gz refind-backup.tar.gz.gpg
   tar -xzf refind-backup.tar.gz
   ```
   (fragt nach dem Passwort aus `BACKUP_PASSPHRASE`)
3. Verbindungsadresse des **neuen** Projekts (Session pooler) in eine Variable:
   `export DB_URL='postgresql://postgres.<ref>:<passwort>@…:5432/postgres'`
4. Einspielen, **in dieser Reihenfolge**:
   ```
   psql "$DB_URL" -v ON_ERROR_STOP=1 -f backup/schema.sql
   psql "$DB_URL" -v ON_ERROR_STOP=1 -f backup/data_auth.sql
   psql "$DB_URL" -v ON_ERROR_STOP=1 -f backup/data_public.sql
   ```
   Zuerst die Struktur, dann die Konten (profile verweist auf auth.users),
   dann die Daten. Der Trigger `on_auth_user_created` darf erst danach
   kommen, sonst legt er beim Einspielen der Konten doppelte Profile an.
5. Im SQL Editor ergänzen, was nicht im Backup ist:
   - letzte Anweisung aus `04_funktionen.sql`: `create trigger on_auth_user_created …`
   - pg_cron einschalten, dann `12_ablauf.sql`
   - `13_speicher.sql` (Buckets und Storage-Regeln)
   - aus `14_chat.sql` den Teil 3 (Publication `supabase_realtime`)
   - aus `15_konto_loeschen.sql` den Teil 3 (Löschregeln Storage)
6. Dashboard-Einstellungen aus Abschnitt 7 setzen (URL Configuration usw.).
7. In `lib/app_config.dart` URL und publishableKey des neuen Projekts eintragen
   (Abschnitt 5), App neu bauen.
8. Prüfen: mit einem Testkonto anmelden, «Meine Gesuche» und «Entdecken»
   zeigen die Daten. Fotos fehlen (Dateien sind nicht im Backup).

Einspielen nur zum Ansehen (ohne neues Projekt): Die `.sql`-Dateien sind
Text und lassen sich mit einem Editor öffnen.
