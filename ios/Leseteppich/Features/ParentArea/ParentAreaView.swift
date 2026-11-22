import SwiftUI
import UniformTypeIdentifiers

struct ParentAreaView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomEditor = false
    @State private var showJSONImporter = false
    @State private var importStatusMessage: String?
    @State private var selectedStudioCarpetID: String = ""
    @State private var carpetToReset: Carpet?

    var body: some View {
        NavigationStack {
            Form {
                readingDisplaySection
                audioHelpAndVoiceSection
                speechRecognitionSection
                voiceStudioSection
                customCarpetsSection
                progressSection
            }
            .navigationTitle("Elternbereich")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustomEditor) {
                CustomCarpetEditorView()
                    .environmentObject(store)
            }
            .fileImporter(
                isPresented: $showJSONImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleJSONImport(result)
            }
            .confirmationDialog(
                "Fortschritt zurücksetzen?",
                isPresented: Binding(
                    get: { carpetToReset != nil },
                    set: { if !$0 { carpetToReset = nil } }
                ),
                titleVisibility: .visible,
                presenting: carpetToReset
            ) { carpet in
                Button("Fortschritt zurücksetzen", role: .destructive) {
                    store.resetProgress(for: carpet.id)
                    carpetToReset = nil
                }
                Button("Abbrechen", role: .cancel) {
                    carpetToReset = nil
                }
            } message: { carpet in
                Text("Alle gesammelten Sterne für „\(carpet.title)“ werden gelöscht.")
            }
            .onAppear {
                store.synthesizer.refreshVoices()
                if selectedStudioCarpetID.isEmpty, let first = store.allCarpets.first {
                    selectedStudioCarpetID = first.id
                }
            }
            .onDisappear {
                store.voiceRecorder.stopRecording()
                store.synthesizer.stop()
            }
        }
    }

    private var readingDisplaySection: some View {
        Section("Darstellung (Silbenmethode)") {
            Toggle(
                "Zweifarbige Silbenschrift",
                isOn: store.settingBinding(\.showSyllableColors)
            )
            Toggle(
                "Silbenbögen anzeigen",
                isOn: store.settingBinding(\.showSyllableArcs)
            )
        }
    }

    private var audioHelpAndVoiceSection: some View {
        AudioHelpSettingsSection(store: store, synthesizer: store.synthesizer)
    }

    private var speechRecognitionSection: some View {
        Section {
            Toggle(
                "Automatisch weiterhören (Freihand-Lesen)",
                isOn: store.settingBinding(\.autoListenNextTile)
            )

            Picker(
                "Erkennungs-Genauigkeit",
                selection: store.settingBinding(\.strictness)
            ) {
                ForEach(MatchingStrictness.allCases) { level in
                    Text(level.label).tag(level)
                }
            }

            Text(store.settings.strictness.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "Offline-Spracherkennung (auf dem Gerät) bevorzugen",
                isOn: store.settingBinding(\.preferOnDeviceRecognition)
            )

            Toggle(
                "„Richtig gelesen ✓“-Hilfe anzeigen",
                isOn: store.settingBinding(\.allowManualConfirm)
            )
        } header: {
            Text("Spracherkennung & Lesefluss")
        } footer: {
            Text("Mit „Automatisch weiterhören“ startet das Mikrofon nach jedem erkannten Laut nach einer kurzen Pause automatisch für das nächste Feld – ohne erneut auf den Button drücken zu müssen.")
        }
    }

    private var voiceStudioSection: some View {
        Section {
            NavigationLink("Eigene Stimme aufnehmen") {
                VoiceStudioView(store: store, selectedCarpetID: $selectedStudioCarpetID)
            }
        } header: {
            Text("Eltern-Stimm-Studio (Natürlichste Laute)")
        } footer: {
            Text("Sprich Laute wie „aaa“, „iii“, „nnn“ oder ganze Wörter selbst ein. Wenn eine eigene Aufnahme existiert, spielt die App immer deine Stimme statt der Computerstimme ab.")
        }
    }

    private var customCarpetsSection: some View {
        Section {
            Button {
                showCustomEditor = true
            } label: {
                Label("Eigenen Leseteppich erstellen", systemImage: "plus.circle.fill")
            }

            Button {
                showJSONImporter = true
            } label: {
                Label("Leseteppich aus JSON importieren", systemImage: "square.and.arrow.down")
            }

            if let importStatusMessage {
                Text(importStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !store.persistedData.customCarpets.isEmpty {
                ForEach(store.persistedData.customCarpets) { carpet in
                    HStack {
                        Text("\(carpet.motifEmoji) \(carpet.title)")
                        Spacer()
                        Text("\(carpet.tiles.count) Felder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    let carpets = store.persistedData.customCarpets
                    let ids = offsets.map { carpets[$0].id }
                    for id in ids {
                        store.deleteCustomCarpet(id: id)
                    }
                }
            }
        } header: {
            Text("Eigene Leseteppiche (z. B. aus der Schule)")
        } footer: {
            Text("Nutzt eine JSON-Datei zum Teilen zwischen Geräten (iOS und Android).")
        }
    }

    private var progressSection: some View {
        Section("Fortschritt verwalten") {
            ForEach(store.allCarpets) { carpet in
                let runs = store.progress(for: carpet.id).completedRuns
                HStack {
                    Text("\(carpet.motifEmoji) \(carpet.title)")
                    Spacer()
                    Text("\(runs)/\(carpet.targetRepetitions)x")
                        .foregroundStyle(.secondary)
                    if runs > 0 {
                        Button("Zurücksetzen", role: .destructive) {
                            carpetToReset = carpet
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func handleJSONImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url)
                let count = try store.importCarpetsJSON(data)
                importStatusMessage = "\(count) Leseteppich(e) erfolgreich importiert!"
            } catch {
                importStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
        case .failure(let error):
            importStatusMessage = "Dateiauswahl abgebrochen: \(error.localizedDescription)"
        }
    }
}

private struct AudioHelpSettingsSection: View {
    @ObservedObject var store: AppStore
    @ObservedObject var synthesizer: AudioSpeechSynthesizer

    var body: some View {
        Section {
            Toggle(
                "Vorlesehilfe für Kinder anzeigen (Anhören)",
                isOn: store.settingBinding(\.allowAudioHelp)
            )

            Picker(
                "Vorlese-Stimme",
                selection: Binding(
                    get: { store.settings.selectedVoiceIdentifier ?? "" },
                    set: { value in
                        store.updateSettings { $0.selectedVoiceIdentifier = value.isEmpty ? nil : value }
                    }
                )
            ) {
                Text("Automatisch (beste installierte)").tag("")
                ForEach(synthesizer.availableVoices) { voice in
                    Text(voice.displayLabel).tag(voice.id)
                }
            }

            Button {
                synthesizer.speakText(
                    "Hallo! Lass uns zusammen den Leseteppich lesen. Nina, Oma, Tomate.",
                    rate: store.settings.speechRate,
                    voiceIdentifier: store.settings.selectedVoiceIdentifier
                )
            } label: {
                Label("Ausgewählte Stimme testen", systemImage: "speaker.wave.2.fill")
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Vorlese-Tempo")
                    Spacer()
                    Text(speedLabel(store.settings.speechRate))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: store.settingBinding(\.speechRate),
                    in: 0.38...0.56,
                    step: 0.02
                )
            }

            if !synthesizer.hasHighQualityVoice {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Tipp für eine viel natürlichere Stimme", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Auf diesem Gerät ist bisher nur die Standard-Stimme installiert. Öffne in iOS: Einstellungen → Bedienungshilfen → Gesprochene Inhalte (oder Lesen & Sprechen) → Stimmen → Deutsch und lade z. B. „Anna (Premium)“ oder „Petra (Premium)“ herunter. Danach nutzt die App sie automatisch – oder sprich Laute unten im Stimm-Studio selbst ein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Vorlesehilfe (App liest vor)")
        } footer: {
            Text("Standardmäßig ist die Vorlesehilfe für Kinder ausgeblendet, damit sie Laute und Wörter selbst erlesen. Aktiviere sie nur bei Bedarf zum Lernen neuer Laute.")
        }
    }

    private func speedLabel(_ rate: Double) -> String {
        if rate < 0.43 { return "Langsam" }
        if rate < 0.51 { return "Natürlich" }
        return "Flott"
    }
}

private struct VoiceStudioView: View {
    @ObservedObject var store: AppStore
    @Binding var selectedCarpetID: String
    @State private var recordingError: String?

    var body: some View {
        Form {
            if !store.settings.allowAudioHelp {
                Section {
                    Label(
                        "Aufnahmen werden nur abgespielt, wenn die Vorlesehilfe an ist.",
                        systemImage: "info.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                Picker("Leseteppich", selection: $selectedCarpetID) {
                    ForEach(store.allCarpets) { carpet in
                        Text("\(carpet.motifEmoji) \(carpet.title)").tag(carpet.id)
                    }
                }

                if let carpet = store.allCarpets.first(where: { $0.id == selectedCarpetID }) {
                    ForEach(carpet.tiles) { tile in
                        VoiceStudioRow(
                            tile: tile,
                            store: store,
                            recorder: store.voiceRecorder,
                            onError: { recordingError = $0 }
                        )
                    }
                }

                if let recordingError {
                    Text(recordingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Sprich Laute wie „aaa“, „iii“, „nnn“ oder ganze Wörter selbst ein. Wenn eine eigene Aufnahme existiert, spielt die App immer deine Stimme statt der Computerstimme ab.")
            }
        }
        .navigationTitle("Eigene Stimme aufnehmen")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            store.voiceRecorder.stopRecording()
            store.synthesizer.stop()
        }
    }
}

private struct VoiceStudioRow: View {
    let tile: ReadingTile
    @ObservedObject var store: AppStore
    @ObservedObject var recorder: ParentVoiceRecorder
    let onError: (String) -> Void

    @State private var refreshTrigger = false

    var body: some View {
        let isRecordingThis = recorder.isRecording && recorder.recordingTileID == tile.id
        let hasCustomAudio = recorder.hasRecording(for: tile.id)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tile.display)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(hasCustomAudio ? "Eigene Stimme aktiv" : "Standard-Stimme")
                    .font(.caption2)
                    .foregroundStyle(hasCustomAudio ? .green : .secondary)
            }

            Spacer()

            Button {
                store.synthesizer.speak(
                    tile: tile,
                    rate: store.settings.speechRate,
                    voiceIdentifier: store.settings.selectedVoiceIdentifier
                )
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Abspielen")

            Button {
                toggleRecording(isRecordingThis: isRecordingThis)
            } label: {
                Image(systemName: isRecordingThis ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isRecordingThis ? .red : .orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecordingThis ? "Aufnahme stoppen" : "Aufnehmen")

            if hasCustomAudio {
                Button(role: .destructive) {
                    try? recorder.deleteRecording(for: tile.id)
                    refreshTrigger.toggle()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Löschen")
            }
        }
        .id(refreshTrigger)
    }

    private func toggleRecording(isRecordingThis: Bool) {
        if isRecordingThis {
            recorder.stopRecording()
            refreshTrigger.toggle()
        } else {
            store.synthesizer.stop()
            Task {
                do {
                    try await recorder.startRecording(for: tile.id)
                } catch {
                    onError(error.localizedDescription)
                }
            }
        }
    }
}

private extension AppStore {
    func settingBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { value in self.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
