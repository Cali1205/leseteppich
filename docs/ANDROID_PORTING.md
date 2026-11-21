# Android Porting Guide (SwiftUI → Kotlin / Jetpack Compose)

Dieses Projekt ist von Grund auf so strukturiert, dass eine **native Android-App** (`android/`) direkt neben `ios/` ergänzt werden kann und sich **Inhalte, JSON-Schema, Phonetik-Logik und Test-Vektoren** zu 100 % teilt.

## 1. Gemeinsame Assets (ohne Duplikation)

In `android/app/build.gradle.kts` wird `shared/content/` direkt als Asset-Ordner eingebunden und `shared/test-vectors/` als Unit-Test-Ressource:

```kotlin
android {
    sourceSets {
        getByName("main") {
            assets.srcDirs("../shared/content")
        }
        getByName("test") {
            resources.srcDirs("../shared/test-vectors")
        }
    }
}
```

Damit laden iOS (`Bundle.main`) und Android (`context.assets`) exakt dieselben Dateien:
- `leseteppiche.json`
- `wuerfellesen.json`
- `phonetic_matching.json` (in JUnit5-Tests gegen `PhoneticMatcher.kt`)

---

## 2. 1:1 Architektur-Mapping

| Schicht | iOS (Swift / SwiftUI) | Android (Kotlin / Compose) |
|---|---|---|
| **Domain Models** | `CarpetModels.swift`, `DiceBoardModels.swift`, `ProgressModels.swift` (`Codable`) | `@Serializable data class` mit `kotlinx.serialization` |
| **Phonetik-Engine** | `PhoneticMatcher.swift` | `PhoneticMatcher.kt` (identische Regeln, verifiziert durch `shared/test-vectors/phonetic_matching.json`) |
| **Leseteppich-Logik** | `ReadingSessionEngine.swift` | `ReadingSessionEngine.kt` (immutable `data class` State) |
| **Würfellesen-Logik** | `DiceGameEngine.swift` | `DiceGameEngine.kt` |
| **Zustandsverwaltung** | `ObservableObject` / `@Published` | `ViewModel` + `StateFlow<UiState>` |
| **TTS (Vorlesen)** | `AVSpeechSynthesizer` (+ `AVSpeechSynthesisIPANotationAttribute`) | `android.speech.tts.TextToSpeech` (`Locale.GERMANY`, SSML `<phoneme>` / `setSpeechRate`) |
| **Eltern-Aufnahmen** | `AVAudioRecorder` + `AVAudioPlayer` (`.m4a` in `Documents/VoiceRecordings/`) | `MediaRecorder` / `AudioRecord` + `MediaPlayer` (`.m4a` in `filesDir/VoiceRecordings/`) |
| **Spracherkennung (ASR)** | `SFSpeechRecognizer` (`de-DE`, `requiresOnDeviceRecognition`) | `android.speech.SpeechRecognizer` (`EXTRA_PREFER_OFFLINE = true`, `EXTRA_LANGUAGE = "de-DE"`, `RESULTS_RECOGNITION`) oder **Sherpa-ONNX / Vosk** für 100 % Offline-Erkennung |
| **Persistenz** | `LocalProgressStore` (JSON-Datei) | `DataStore` oder JSON-Datei in `filesDir` |
| **UI: Silbenschrift** | `SyllableTextView.swift` (`HStack` + `SyllableArcShape`) | `@Composable fun SyllableText(...)` (`Row` + `Canvas`-Bogen unter jeder Silbe) |
| **UI: Navigation** | `NavigationStack` | `Navigation Compose` (`NavHost`) |
| **UI: JSON-Import** | `.fileImporter(allowedContentTypes: [.json])` | `ActivityResultContracts.OpenDocument()` (`application/json`) |

---

## 3. Wichtige Android-Besonderheiten bei Kindersprache & ASR

1. **Audio-Fokus**: Vor dem Start von `SpeechRecognizer` immer `TextToSpeech.stop()` aufrufen, damit sich TTS und Mikrofon nicht gegenseitig hören.
2. **Offline-Sprachpaket**: Androids `SpeechRecognizer` unterstützt `RecognizerIntent.EXTRA_PREFER_OFFLINE = true` (ab API 23) bzw. `SpeechRecognizer.createOnDeviceSpeechRecognizer(context)` (ab Android 12 / API 31). Wenn das Offline-Paket `de-DE` fehlt, sollte die App genauso wie unter iOS freundlich auf die manuelle Bestätigung (`Richtig gelesen ✓`) hinweisen.
3. **Nächster Ausbauschritt (Cross-Platform Phoneme ASR)**:
   Für echte Einzellaut-Erkennung (`n`, `m`, `s`, `l`, `t`) kann später **Sherpa-ONNX** (C++/Swift/Kotlin Bindings) mit einem kompakten deutschen Phonemmodell hinter demselben `SpeechRecognizing`-Interface auf beiden Plattformen eingebunden werden – ohne Änderungen an UI oder Domain-Logik.

---

## 4. CI/CD auf GitHub Actions für Android

Sobald `android/` angelegt wird, genügt ein zusätzlicher Workflow `.github/workflows/android.yml` auf `ubuntu-latest`:
1. `python3 scripts/validate_shared.py`
2. `./gradlew testDebugUnitTest` (inkl. `PhoneticMatcherTest` mit den gemeinsamen Test-Vektoren!)
3. `./gradlew assembleRelease` (Signierung über GitHub Secrets `ANDROID_KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) → APK/AAB als Release-Artifact.
