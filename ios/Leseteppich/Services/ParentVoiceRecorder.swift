import AVFoundation
import Foundation

public enum VoiceRecorderError: LocalizedError {
    case microphonePermissionDenied
    case failedToStart

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Bitte erlaube den Mikrofonzugriff in den iOS-Einstellungen, um eigene Laute aufzunehmen."
        case .failedToStart:
            return "Die Aufnahme konnte nicht gestartet werden."
        }
    }
}

@MainActor
public final class ParentVoiceRecorder: NSObject, VoiceRecording, ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var recordingTileID: String?

    private let recordingsDirectory: URL
    private var recorder: AVAudioRecorder?
    /// Bumped by every start/stop so a start awaiting the permission prompt can tell it was stopped meanwhile.
    private var generation = 0

    public init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.recordingsDirectory = root.appendingPathComponent("VoiceRecordings", isDirectory: true)
        super.init()
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
    }

    public func recordingURL(for tileID: String) -> URL {
        let safeName = tileID.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        return recordingsDirectory.appendingPathComponent("\(safeName).m4a")
    }

    public func hasRecording(for tileID: String) -> Bool {
        FileManager.default.fileExists(atPath: recordingURL(for: tileID).path)
    }

    public func startRecording(for tileID: String) async throws {
        generation += 1
        let startGeneration = generation
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            throw VoiceRecorderError.microphonePermissionDenied
        }
        // Stop/background (or a newer start) during the prompt: don't open the mic now.
        guard startGeneration == generation else { return }

        stopRecording()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = recordingURL(for: tileID)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let newRecorder: AVAudioRecorder
        do {
            newRecorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            deactivateSession()
            throw error
        }
        guard newRecorder.record() else {
            try? FileManager.default.removeItem(at: url)
            deactivateSession()
            throw VoiceRecorderError.failedToStart
        }

        self.recorder = newRecorder
        self.recordingTileID = tileID
        self.isRecording = true
    }

    public func stopRecording() {
        generation += 1
        let wasRecording = recorder != nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        recordingTileID = nil
        if wasRecording { deactivateSession() }
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func deleteRecording(for tileID: String) throws {
        let url = recordingURL(for: tileID)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
