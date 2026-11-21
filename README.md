# 🪄 Leseteppich – Lese-App für die 1. Klasse (iOS / SwiftUI)

Eine kindgerechte, werbefreie iOS-App (iPhone & iPad) zum Üben von **Leseteppichen** und **Würfellesen** nach der Silbenmethode der 1. Klasse – mit **Vorlesefunktion (Lautsprache & eigene Eltern-Aufnahmen)**, **On-Device-Spracherkennung** und einer **plattformübergreifenden Architektur**, die sich direkt auf natives Android (Kotlin / Jetpack Compose) übertragen lässt.

## ✨ Funktionen

- **Meine Leseteppiche (Übersichtskarte)**: 8 startklare, kumulative 4×4-Leseteppiche (`N/I/A`, `+O`, `+T`, `+M`, `+L`, `+S`, `+E`, `+P`) mit kindgerechten Motiven und 5-Sterne-Wiederholungszähler (*„So oft habe ich gelesen“*).
- **Silbenmethode**: Zweifarbige Silbenschrift (Blau/Korallrot) und zuschaltbare **Silbenbögen**; Antippen einzelner Silben liest jede Silbe langsam einzeln vor.
- **Lern- & Vorlese-Modus**:
  - **Anhören**: Antippen beliebiger Felder zum Vorsprechen (IPA-gestützte Lautsprache für Einzellaute).
  - **Vorlesen**: On-Device deutsche Spracherkennung (`SFSpeechRecognizer`, `de-DE`) mit fehlertolerantem `PhoneticMatcher` für 6-jährige Leseanfänger und frustfreier Bestätigungs-Hilfe.
- **🎲 Würfellesen – Schatzsuche**: Interaktives 6-Spalten-Würfelspiel (1 oder 2 Spieler) mit Bildsätzen/Rebus (`Tim ❤️ Salat.`, `Oli ist im 🛏️`) bis zur Schatztruhe.
- **🔒 Elternbereich (mit Rechen-Sperre)**:
  - **Eltern-Stimm-Studio**: Eigene Stimme für beliebige Laute (`nnn`, `mmm`, `sss`, …) aufnehmen – die App spielt dann immer Mama/Papa statt der Computerstimme ab.
  - **Eigener Leseteppich-Editor & JSON-Import**: Schuleigene Arbeitsblätter lokal auf dem Gerät anlegen (Silbentrennung einfach mit `|`, z. B. `To|ma|te`) oder als JSON importieren.
  - Feineinstellung für Sprechtempo, Erkennungs-Strenge (*Sanft / Normal / Genau*) und Silbendarstellung.

## 📚 Dokumentation

- **[Pädagogisches & Technisches Konzept](docs/KONZEPT.md)** – Lautsprache vs. Buchstabennamen, Kindersprache-ASR, Datenschutz & Roadmap.
- **[Android Porting Guide](docs/ANDROID_PORTING.md)** – 1:1-Mapping von Swift/SwiftUI zu Kotlin/Jetpack Compose inkl. geteiltem JSON-Format & Test-Vektoren.

## 🏗️ Projektstruktur

```text
├── .github/workflows/ios.yml     # CI: JSON-Validierung, macOS Build/Tests & TestFlight-Upload
├── docs/                         # Gesamtkonzept & Android-Portierungsleitfaden
├── shared/                       # Plattformunabhängig (iOS & künftig Android)
│   ├── schema/                   # JSON-Schema (leseteppich.schema.json)
│   ├── content/                  # leseteppiche.json & wuerfellesen.json
│   └── test-vectors/             # phonetic_matching.json (gemeinsame Matcher-Tests)
├── scripts/                      # Shared-Validator & CI-Log-Redaktion
└── ios/                          # Native iOS App (SwiftUI, iOS 17+, iPhone & iPad)
    ├── project.yml               # XcodeGen-Projektdefinition (kein .xcodeproj im Repo nötig)
    ├── ExportOptions.plist       # App Store Connect Cloud-Signing
    ├── Leseteppich/
    │   ├── Domain/               # Reines Swift (ohne UIKit/SwiftUI) -> 1:1 nach Kotlin portierbar
    │   ├── Services/             # AVSpeech, SFSpeech, AVAudioRecorder, JSON-Persistenz
    │   └── Features/             # SwiftUI-Screens (CarpetMap, CarpetReading, DiceReading, ParentArea)
    └── Tests/                    # XCTest Unit-Tests (inkl. shared test-vectors)
```

## ☁️ Bauen & auf iPhone/iPad installieren – ganz ohne Mac

Die App wird komplett über **GitHub Actions** gebaut und per **Apple Cloud-Signing** direkt zu **TestFlight** hochgeladen (du brauchst keinen macOS-Rechner, nur dein Apple Developer Konto):

### 1. App ID & App in App Store Connect anlegen (einmalig im Browser)
1. Im [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) eine neue App ID registrieren, z. B. `io.github.cali1205.leseteppich` (oder eine eigene über die Repository-Variable `BUNDLE_ID`).
2. In [App Store Connect](https://appstoreconnect.apple.com) unter **Apps → + Neue App** eine iOS-App mit genau dieser Bundle ID anlegen.
3. Unter **Benutzer und Zugriffe → Integrationen → App Store Connect API** einen API-Schlüssel mit Rolle *App-Manager* erstellen (oder deinen bestehenden Schlüssel wiederverwenden).

### 2. GitHub Repository Secrets hinterlegen
Unter **Settings → Secrets and variables → Actions** folgende Secrets anlegen:

| Secret | Inhalt |
|---|---|
| `ASC_KEY_ID` | Key ID des App Store Connect API-Schlüssels (z. B. `ABC123XYZ`) |
| `ASC_ISSUER_ID` | Issuer ID (UUID aus App Store Connect) |
| `ASC_KEY_P8` | Kompletter Inhalt der heruntergeladenen `AuthKey_*.p8`-Datei |
| `APPLE_TEAM_ID` | Deine 10-stellige Apple Developer Team ID |

*(Optional: Repository-Variable `BUNDLE_ID`, falls du eine andere Bundle ID verwenden möchtest.)*

### 3. Build & TestFlight-Upload starten
- Jeder **Push auf `main`** baut das Projekt automatisch per XcodeGen auf einem macOS-Runner und führt alle Unit-Tests aus.
- Für einen **TestFlight-Upload** gehe auf **Actions → iOS Build & TestFlight → Run workflow**, lasse *„Signiert bauen und zu TestFlight hochladen“* aktiviert und starte den Lauf. Nach wenigen Minuten erscheint der Build in der **TestFlight-App** auf iPhone & iPad!

## 📝 Hinweis zu eigenen Schul-Leseteppichen

Da gedruckte Leseteppiche aus der Schule häufig urheberrechtlich geschützt sind, enthält dieses öffentliche Repository eigene, frei lizenzierte (MIT) Leseteppiche mit demselben 1.-Klasse-Aufbau. Im **Elternbereich** kannst du die exakten Arbeitsblätter deiner Tochter in wenigen Minuten direkt eintippen oder als JSON-Datei importieren – sie bleiben ausschließlich lokal auf eurem Gerät.

## Lizenz

MIT – siehe [LICENSE](LICENSE).
