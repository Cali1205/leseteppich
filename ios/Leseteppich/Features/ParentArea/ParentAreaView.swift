import SwiftUI
import UniformTypeIdentifiers

struct ParentAreaView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomEditor = false
    @State private var showJSONImporter = false
    @State private var importStatusMessage: String?
    @State private var selectedStudioCarpetID: String = ""
    @State private var recordingError: String?

    var body: some View {
        NavigationStack {
            Form {
                readingDisplaySection
                speechAndRecognitionSection
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
            .onAppear {
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
                isOn: Binding(
                    get: { store.settings.showSyllableColors },
                    set: { value in store.updateSettings { $0.showSyllableColors = value } }
                )
            )
            Toggle(
                "Silbenbögen anzeigen",
                isOn: Binding(
                    get: { store.settings.showSyllableArcs },
                    set: { value in store.updateSettings { $0.showSyllableArcs = value } }
                )
            )
        }
    }

    private var speechAndRecognitionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Vorlese-Tempo")
                    Spacer()
                    Text(speedLabel(store.settings.speechRate))
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { store.settings.speechRate },
                        set: { value in store.updateSettings { $0.speechRate = value } }
                    ),
                    in: 0.30...0.55,
                    step: 0.03
                )
            }

            Picker(
                "Erkennungs-Genauigkeit",
                selection: Binding(
                    get: { store.settings.strictness },
                    set: { value in store.updateSettings { $0.strictness = value } }
                )
            ) {
                ForEach(MatchingStrictness.allCases) { level in
                    Text(level.label).tag(level)
                }
            }

            Text(store.settings.strictness.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(
                "On-Device Spracherkennung bevorzugen",
                isOn: Binding(
                    get: { store.settings.preferOnDeviceRecognition },
                    set: { value in store.updateSettings { $0.preferOnDeviceRecognition = value } }
                )
            )

            Toggle(
                "„Richtig gelesen ✓“-Hilfe anzeigen",
                isOn: Binding(
                    get: { store.settings.allowManualConfirm },
                    set: { value in store.updateSettings { $0.allowManualConfirm = value } }
                )
            )
        } header: {
            Text("Sprache & Erkennung")
        } footer: {
            Text("Hinweis: Bei Einzellauten (z. B. „n“ oder „t“) ist die On-Device-Spracherkennung naturgemäß eingeschränkt. Die manuelle Bestätigung verhindert Frust beim Üben.")
        }
    }

    private var voiceStudioSection: some View {
        Section {
            Picker("Leseteppich", selection: $selectedStudioCarpetID) {
                ForEach(store.allCarpets) { carpet in
                    Text("\(carpet.motifEmoji) \(carpet.title)").tag(carpet.id)
                }
            }

            if let carpet = store.allCarpets.first(where: { $0.id == selectedStudioCarpetID }) {
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
        } header: {
            Text("Eltern-Stimm-Studio (Eigene Laute aufnehmen)")
        } footer: {
            Text("Sprich Laute wie „nnn“, „mmm“ oder „sss“ selbst ein. Wenn eine eigene Aufnahme existiert, spielt die App immer deine Stimme statt der Computerstimme ab.")
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
                    for idx in offsets {
                        let id = store.persistedData.customCarpets[idx].id
                        store.deleteCustomCarpet(id: id)
                    }
                }
            }
        } header: {
            Text("Eigene Leseteppiche (z. B. aus der Schule)")
        } footer: {
            Text("Nutzt dasselbe plattformübergreifende JSON-Schema (shared/schema/leseteppich.schema.json) für iOS und Android.")
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
                            store.resetProgress(for: carpet.id)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func speedLabel(_ rate: Double) -> String {
        if rate < 0.37 { return "Sehr langsam" }
        if rate < 0.46 { return "Langsam" }
        return "Normal"
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
                store.synthesizer.speak(tile: tile, rate: store.settings.speechRate)
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Button {
                toggleRecording(isRecordingThis: isRecordingThis)
            } label: {
                Image(systemName: isRecordingThis ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isRecordingThis ? .red : .orange)
            }
            .buttonStyle(.plain)

            if hasCustomAudio {
                Button(role: .destructive) {
                    try? recorder.deleteRecording(for: tile.id)
                    refreshTrigger.toggle()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
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
