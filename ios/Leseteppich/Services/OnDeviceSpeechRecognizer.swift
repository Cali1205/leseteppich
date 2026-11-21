import AVFoundation
import Foundation
import Speech

@MainActor
public final class OnDeviceSpeechRecognizer: SpeechRecognizing, ObservableObject {
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var audioLevel: Double = 0.0

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var stopTimer: Task<Void, Never>?

    public init(localeIdentifier: String = "de-DE") {
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    public func startListening(
        contextualWords: [String],
        preferOnDevice: Bool,
        onHypotheses: @escaping @MainActor ([String], Bool) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async {
        stopListening()

        let speechAuth = await requestSpeechAuthorization()
        guard speechAuth == .authorized else {
            onError("Bitte erlaube die Spracherkennung in den iOS-Einstellungen.")
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            onError("Bitte erlaube den Mikrofonzugriff in den iOS-Einstellungen.")
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            onError("Die deutsche Spracherkennung ist gerade nicht verfügbar.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.contextualStrings = contextualWords
            request.taskHint = .dictation

            if preferOnDevice && recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

            self.recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                stopListening()
                onError("Kein aktives Mikrofon gefunden. Du kannst trotzdem alle Wörter anhören und abhaken.")
                return
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
                request?.append(buffer)
                let level = Self.calculateNormalizedRMS(buffer: buffer)
                Task { @MainActor [weak self] in
                    self?.audioLevel = level
                    onAudioLevel(level)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.isListening else { return }

                    if let result {
                        let hypotheses = result.transcriptions.map(\.formattedString)
                        onHypotheses(hypotheses, result.isFinal)
                        if result.isFinal {
                            self.stopListening()
                        }
                    }

                    if let error {
                        // Ignore benign cancellation errors when we stopped intentionally
                        let nsError = error as NSError
                        if nsError.code != 216 && nsError.code != 203 {
                            onError("Ich konnte das nicht ganz verstehen. Probier es noch einmal!")
                        }
                        self.stopListening()
                    }
                }
            }

            // Safety auto-stop after 6 seconds so microphone never stays open indefinitely
            stopTimer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled, let self, self.isListening else { return }
                self.recognitionRequest?.endAudio()
                try? await Task.sleep(for: .milliseconds(600))
                if self.isListening {
                    self.stopListening()
                    onHypotheses([], true)
                }
            }
        } catch {
            stopListening()
            onError("Mikrofon konnte nicht gestartet werden (\(error.localizedDescription)).")
        }
    }

    public func stopListening() {
        stopTimer?.cancel()
        stopTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0.0
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated static func calculateNormalizedRMS(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.0 }

        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        // Map typical voice RMS (~0.005..0.15) to 0..1
        let normalized = min(max(Double(rms) * 8.0, 0.0), 1.0)
        return normalized
    }
}
