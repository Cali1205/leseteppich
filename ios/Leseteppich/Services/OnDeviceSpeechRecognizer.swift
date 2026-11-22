import AVFoundation
import Foundation
import Speech

@MainActor
public final class OnDeviceSpeechRecognizer: ObservableObject {
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var audioLevel: Double = 0.0

    private let localeIdentifier: String
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var watcherTask: Task<Void, Never>?
    /// Identifies the current listening session. Callbacks of cancelled recognition tasks, taps and
    /// watchers capture their own token and bail out if it no longer matches, so they can't stop a newer session.
    private var activeSession: UUID?

    private var customLMConfig: SFSpeechLanguageModel.Configuration?
    private var preparedVocabularyKey: String?
    private var lmPrepareTask: Task<Void, Never>?

    // Voice Activity Detection (VAD) state for crisp auto-endpointing on short sounds like "a"
    private var listeningStartTime: Date?
    private var speechStartTime: Date?
    private var lastSpeechTime: Date?
    private var hasEndedAudio: Bool = false
    private var endAudioTime: Date?

    public init(localeIdentifier: String = "de-DE") {
        self.localeIdentifier = localeIdentifier
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }

    /// Prepares an iOS 17+ on-device custom language model in the background so short German
    /// sounds, syllables, and pseudo-words (e.g. "a", "ni", "Nani", "Onano") are recognized reliably.
    public func prepareCustomVocabulary(phrases: [String]) async {
        guard let recognizer, recognizer.supportsOnDeviceRecognition else { return }

        let cleaned = Array(Set(
            phrases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )).sorted()

        guard !cleaned.isEmpty else { return }
        let vocabKey = cleaned.joined(separator: "|")
        if preparedVocabularyKey == vocabKey, customLMConfig != nil {
            return
        }

        // Chain instead of cancel: cancelling wouldn't stop the detached export/compile, and two
        // overlapping runs would write the same cache files.
        let previous = lmPrepareTask
        let localeID = self.localeIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "io.github.cali1205.leseteppich"

        lmPrepareTask = Task { [weak self] in
            await previous?.value
            let compiledConfig: SFSpeechLanguageModel.Configuration? = await Task.detached(priority: .utility) {
                do {
                    let data = SFCustomLanguageModelData(
                        locale: Locale(identifier: localeID),
                        identifier: bundleID,
                        version: "2.0"
                    ) {
                        for phrase in cleaned {
                            SFCustomLanguageModelData.PhraseCount(phrase: phrase, count: 25)
                        }
                    }

                    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                    let trainingURL = cacheDir.appendingPathComponent("LeseteppichLMData.bin")
                    let modelURL = cacheDir.appendingPathComponent("LeseteppichCompiledLM.bin")
                    let vocabURL = cacheDir.appendingPathComponent("LeseteppichCompiledVocab.bin")

                    try await data.export(to: trainingURL)
                    let config = SFSpeechLanguageModel.Configuration(
                        languageModel: modelURL,
                        vocabulary: vocabURL
                    )

                    try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                        for: trainingURL,
                        configuration: config,
                        ignoresCache: true
                    )
                    return config
                } catch {
                    // Gracefully fall back to standard on-device recognition (e.g. on Simulator).
                    return nil
                }
            }.value

            guard let self, let compiledConfig else { return }
            self.customLMConfig = compiledConfig
            self.preparedVocabularyKey = vocabKey
        }
    }

    /// How long the child may stay silent before the utterance is considered finished.
    /// Slow beginner readers need more time for longer content.
    public nonisolated static func silenceCutoff(syllableCount: Int, isMultiWord: Bool) -> TimeInterval {
        if isMultiWord { return 1.9 }
        return syllableCount >= 2 ? 1.45 : 0.95
    }

    public func startListening(
        contextualWords: [String],
        preferOnDevice: Bool,
        shortUtterance: Bool = true,
        silenceCutoff: TimeInterval = 0.95,
        onHypotheses: @escaping @MainActor ([String], Bool) -> Void,
        onAudioLevel: @escaping @MainActor (Double) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async {
        guard !Task.isCancelled else { return }
        stopListening()
        let session = UUID()
        activeSession = session

        // A Stop (or a newer start) during a permission prompt invalidates the token: don't open the mic then.
        let speechAuth = await requestSpeechAuthorization()
        guard isCurrent(session) else { return }
        guard speechAuth == .authorized else {
            activeSession = nil
            onError("Bitte erlaube die Spracherkennung in den iOS-Einstellungen.")
            return
        }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard isCurrent(session) else { return }
        guard micGranted else {
            activeSession = nil
            onError("Bitte erlaube den Mikrofonzugriff in den iOS-Einstellungen.")
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            activeSession = nil
            onError("Die deutsche Spracherkennung ist gerade nicht verfügbar.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = false
            request.contextualStrings = contextualWords
            request.taskHint = shortUtterance ? .confirmation : .dictation

            if preferOnDevice && recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
                if let customLMConfig {
                    request.customizedLanguageModel = customLMConfig
                }
            }

            self.recognitionRequest = request
            self.listeningStartTime = Date()
            self.speechStartTime = nil
            self.lastSpeechTime = nil
            self.hasEndedAudio = false
            self.endAudioTime = nil

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                stopListening()
                onError("Kein aktives Mikrofon gefunden. Du kannst trotzdem alle Wörter abhaken.")
                return
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
                request?.append(buffer)
                let level = Self.calculateNormalizedRMS(buffer: buffer)
                Task { @MainActor [weak self] in
                    guard let self, self.activeSession == session else { return }
                    self.audioLevel = level
                    self.updateVoiceActivity(level: level)
                    onAudioLevel(level)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.activeSession == session else { return }

                    if let result {
                        let hypotheses = Self.extractAllHypotheses(from: result)
                        onHypotheses(hypotheses, result.isFinal)
                        if result.isFinal {
                            self.stopListening()
                        }
                    }

                    if let error {
                        let nsError = error as NSError
                        // Ignore benign cancellation (216/203) and no-speech-detected (1110) handled via retry
                        if nsError.code == 1110 {
                            self.stopListening()
                            onHypotheses([], true)
                        } else if nsError.code != 216 && nsError.code != 203 {
                            self.stopListening()
                            onError("Ich konnte das nicht ganz verstehen. Probier es noch einmal!")
                        } else {
                            self.stopListening()
                        }
                    }
                }
            }

            // Smart VAD auto-endpointing + safety max duration watcher
            let maxWaitWithoutSpeech: TimeInterval = 7.0
            let postEndAudioGrace: TimeInterval = 1.6

            watcherTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard let self, self.activeSession == session else { return }
                    let now = Date()

                    if self.hasEndedAudio {
                        if let endedAt = self.endAudioTime, now.timeIntervalSince(endedAt) >= postEndAudioGrace {
                            self.stopListening()
                            onHypotheses([], true)
                            return
                        }
                        continue
                    }

                    // Once the child spoke and went quiet for `silenceCutoff`, flush final hypotheses immediately!
                    if let startedSpeech = self.speechStartTime,
                       let lastSpeech = self.lastSpeechTime,
                       now.timeIntervalSince(startedSpeech) >= 0.22,
                       now.timeIntervalSince(lastSpeech) >= silenceCutoff {
                        self.triggerEndAudio()
                        continue
                    }

                    // Hard safety timeout so the mic never stays open forever
                    if let startedAt = self.listeningStartTime,
                       now.timeIntervalSince(startedAt) >= maxWaitWithoutSpeech {
                        self.triggerEndAudio()
                    }
                }
            }
        } catch {
            stopListening()
            onError("Mikrofon konnte nicht gestartet werden (\(error.localizedDescription)).")
        }
    }

    public func stopListening() {
        let wasActive = activeSession != nil
        activeSession = nil
        watcherTask?.cancel()
        watcherTask = nil

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
        listeningStartTime = nil
        speechStartTime = nil
        lastSpeechTime = nil
        hasEndedAudio = false
        endAudioTime = nil

        // Release the mic session so other audio (and TTS) can resume; fails harmlessly if TTS is already playing.
        if wasActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func isCurrent(_ session: UUID) -> Bool {
        activeSession == session && !Task.isCancelled
    }

    private func updateVoiceActivity(level: Double) {
        let now = Date()
        if speechStartTime == nil {
            if level >= 0.11 {
                speechStartTime = now
                lastSpeechTime = now
            }
        } else if level >= 0.08 {
            lastSpeechTime = now
        }
    }

    private func triggerEndAudio() {
        guard !hasEndedAudio else { return }
        hasEndedAudio = true
        endAudioTime = Date()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    /// Collects both full transcriptions and segment-level alternative substrings
    /// (crucial for short German vowels/syllables like "a", "i", "ni", "ma").
    private nonisolated static func extractAllHypotheses(from result: SFSpeechRecognitionResult) -> [String] {
        var ordered: [String] = []
        var seen: Set<String> = []

        func appendUnique(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                ordered.append(trimmed)
            }
        }

        appendUnique(result.bestTranscription.formattedString)
        for transcription in result.transcriptions {
            appendUnique(transcription.formattedString)
            for segment in transcription.segments {
                appendUnique(segment.substring)
                for alt in segment.alternativeSubstrings {
                    appendUnique(alt)
                }
            }
        }
        return ordered
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
        let normalized = min(max(Double(rms) * 8.0, 0.0), 1.0)
        return normalized
    }
}
