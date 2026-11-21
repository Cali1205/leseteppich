import Foundation
import SwiftUI

@MainActor
public final class AppStore: ObservableObject {
    @Published public private(set) var builtInCarpets: [Carpet] = []
    @Published public private(set) var diceBoards: [DiceBoard] = []
    @Published public private(set) var persistedData: PersistedAppData
    @Published public var loadError: String?

    public let contentLoader: ContentLoading
    public let progressStore: ProgressStoring
    public let voiceRecorder: ParentVoiceRecorder
    public let synthesizer: AudioSpeechSynthesizer
    public let speechRecognizer: OnDeviceSpeechRecognizer
    public let phoneticMatcher: PhoneticMatcher

    public init(
        contentLoader: ContentLoading = BundleContentLoader(),
        progressStore: ProgressStoring? = nil,
        voiceRecorder: ParentVoiceRecorder? = nil,
        speechRecognizer: OnDeviceSpeechRecognizer? = nil,
        phoneticMatcher: PhoneticMatcher = PhoneticMatcher()
    ) {
        let resolvedProgressStore = progressStore ?? LocalProgressStore()
        let resolvedVoiceRecorder = voiceRecorder ?? ParentVoiceRecorder()
        let resolvedSpeechRecognizer = speechRecognizer ?? OnDeviceSpeechRecognizer()

        self.contentLoader = contentLoader
        self.progressStore = resolvedProgressStore
        self.voiceRecorder = resolvedVoiceRecorder
        self.synthesizer = AudioSpeechSynthesizer(voiceRecorder: resolvedVoiceRecorder)
        self.speechRecognizer = resolvedSpeechRecognizer
        self.phoneticMatcher = phoneticMatcher
        self.persistedData = resolvedProgressStore.load()

        reloadBuiltInContent()
    }

    public var allCarpets: [Carpet] {
        (builtInCarpets + persistedData.customCarpets).sorted(by: { $0.order < $1.order })
    }

    public var settings: AppSettings {
        persistedData.settings
    }

    public func reloadBuiltInContent() {
        do {
            builtInCarpets = try contentLoader.loadBuiltInCarpets()
            diceBoards = try contentLoader.loadBuiltInDiceBoards()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    public func progress(for carpetID: String) -> CarpetProgress {
        persistedData.progressByCarpetID[carpetID] ?? CarpetProgress(carpetID: carpetID)
    }

    public func recordCarpetCompletion(carpetID: String) {
        var current = progress(for: carpetID)
        current.completedRuns += 1
        current.lastReadAt = Date()
        persistedData.progressByCarpetID[carpetID] = current
        persist()
    }

    public func resetProgress(for carpetID: String) {
        persistedData.progressByCarpetID[carpetID] = CarpetProgress(carpetID: carpetID)
        persist()
    }

    public func recordDiceWin() {
        persistedData.diceWinsCount += 1
        persist()
    }

    public func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        mutate(&persistedData.settings)
        persist()
    }

    public func addCustomCarpet(_ carpet: Carpet) {
        persistedData.customCarpets.removeAll(where: { $0.id == carpet.id })
        persistedData.customCarpets.append(carpet)
        persist()
    }

    public func deleteCustomCarpet(id: String) {
        persistedData.customCarpets.removeAll(where: { $0.id == id })
        persist()
    }

    public func importCarpetsJSON(_ data: Data) throws -> Int {
        let pack = try JSONDecoder().decode(CarpetPack.self, from: data)
        let baseOrder = (allCarpets.map(\.order).max() ?? 0) + 1
        for (offset, imported) in pack.carpets.enumerated() {
            let custom = Carpet(
                id: imported.id.hasPrefix("custom_") ? imported.id : "custom_\(imported.id)",
                order: baseOrder + offset,
                title: imported.title,
                subtitle: imported.subtitle,
                focusLetters: imported.focusLetters,
                motifEmoji: imported.motifEmoji,
                motifName: imported.motifName,
                accentHex: imported.accentHex,
                targetRepetitions: imported.targetRepetitions,
                columns: imported.columns,
                tiles: imported.tiles,
                isCustom: true
            )
            addCustomCarpet(custom)
        }
        return pack.carpets.count
    }

    public func exportCustomCarpetsJSON() throws -> Data {
        let pack = CarpetPack(carpets: persistedData.customCarpets.isEmpty ? allCarpets : persistedData.customCarpets)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(pack)
    }

    private func persist() {
        progressStore.save(persistedData)
    }
}
