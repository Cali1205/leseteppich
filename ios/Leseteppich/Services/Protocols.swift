import Foundation

public protocol ContentLoading: Sendable {
    func loadBuiltInCarpets() throws -> [Carpet]
    func loadBuiltInDiceBoards() throws -> [DiceBoard]
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
