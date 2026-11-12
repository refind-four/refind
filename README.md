# refind

Android-App in Flutter mit Backend Supabase. Schulprojekt gibb, Modul 306/183.

Käuferinnen und Käufer hängen ein **Gesuch** auf, Verkäuferinnen und Verkäufer
geben ein **Angebot** ab, danach geht es im **Chat** weiter bis zum Abschluss
und zur Bewertung.

## Starten

```bash
flutter pub get
flutter run
```

Voraussetzung: Flutter (stable), Android SDK, ein Android-Gerät ab Version 10
mit USB-Debugging oder ein Emulator.

## Aufbau (Konzeptbericht Kapitel 4)

| Ordner | Schicht | Inhalt |
|---|---|---|
| `lib/presentation/` | Präsentationsschicht | Masken: `account`, `wants`, `discover`, `chat` |
| `lib/application/` | Anwendungsschicht | `state` (Provider), `services`, `logic` |
| `lib/data/` | Datenzugriffsschicht | Interface `RefindRepository`, `MockRefindRepository` |
| `lib/model/` | – | Entitätstypen, von allen Schichten verwendet |

Welche Umsetzung des Repository aktiv ist, steht in `lib/app_config.dart`.

## Testkonten im MockRefindRepository

Passwort jeweils `refind123`: `anna@refind.test`, `luca@refind.test`,
`mia@refind.test`. Die Testdaten liegen nur im Speicher und sind nach jedem
Neustart der App wieder im Ausgangszustand.

## Tests

```bash
flutter test
```
