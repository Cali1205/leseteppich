import Foundation

public protocol ContentLoading: Sendable {
    func loadBuiltInCarpets() throws -> [Carpet]
    func loadBuiltInDiceBoards() throws -> [DiceBoard]
}

@MainActor
public protocol SpeechSynthesizing: AnyObject {
    var isSpeaking: Bool { get }
    func speak(tile: ReadingTile, rate: Double)
    func speakSyllable(_ syllable: String, rate: Double)
    func speakText(_ text: String, rate: Double)
    func stop()
}

@MainActor
public protocol SpeechRecognizing: AnyObject {
    var isListening: Bool { get }
    var audioLevel: Double { get }
    func startListening(
        contextualWords: [String],
        preferOnDevice: Bool,
        onHypotheses: @escaping @MainActor ([String], Bool) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async
    func stopListening()
}

@MainActor
public protocol VoiceRecording: AnyObject {
    var isRecording: Bool { get }
    var recordingTileID: String? { get }
    func recordingURL(for tileID: String) -> URL
    func hasRecording(for tileID: String) -> Bool
    func startRecording(for tileID: String) async throws
    func stopRecording()
    func deleteRecording(for tileID: String) throws
}

@MainActor
public protocol ProgressStoring: AnyObject {
    func load() -> PersistedAppData
    func save(_ data: PersistedAppData)
}
