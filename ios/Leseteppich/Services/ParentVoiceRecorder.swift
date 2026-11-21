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
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            throw VoiceRecorderError.microphonePermissionDenied
        }

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

        let newRecorder = try AVAudioRecorder(url: url, settings: settings)
        guard newRecorder.record() else {
            throw VoiceRecorderError.failedToStart
        }

        self.recorder = newRecorder
        self.recordingTileID = tileID
        self.isRecording = true
    }

    public func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        recordingTileID = nil
    }

    public func deleteRecording(for tileID: String) throws {
        let url = recordingURL(for: tileID)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
