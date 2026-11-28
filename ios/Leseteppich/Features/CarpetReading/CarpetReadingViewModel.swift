import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class CarpetReadingViewModel: ObservableObject {
    @Published var engine: ReadingSessionEngine
    @Published var mode: ReadingMode = .read
    @Published var recognitionStatus: SpeechRecognitionStatus = .idle
    @Published var audioLevel: Double = 0.0
    @Published var showCelebration: Bool = false
    /// After a match, go straight on to the next tile (settings.autoListenNextTile, started via the mic button).
    @Published var isContinuousReadingActive: Bool = false
    /// Set when a run finishes, before `showCelebration` turns true.
    @Published private(set) var lastRunResult: RunResult?

    private let store: AppStore
    /// The one pending step of the read-aloud loop (ready delay, outcome hold).
    private var autoContinueTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var evaluatingSince: Date?
    /// Latest non-empty hypotheses of the current attempt; the final result can arrive empty after a timeout.
    private var heardInAttempt: [String] = []
    /// Tile recognized but still inside the `.matched` hold; completed even if the hold is interrupted.
    private var matchedTileID: String?
    private var backgroundObserver: AnyCancellable?

    init(carpet: Carpet, store: AppStore) {
        self.engine = ReadingSessionEngine(carpet: carpet)
        self.store = store
        // The app-level stop only halts the services; this also kills the pending sleep tasks that would reopen the mic.
        backgroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                // Posted on the main thread: stop synchronously, before the app suspends with a task still pending.
                MainActor.assumeIsolated {
                    self?.stopAudioAndSpeech()
                }
            }
    }

    var carpet: Carpet { engine.carpet }
    var activeTile: ReadingTile? { engine.activeTile }
    var settings: AppSettings { store.settings }
    var allowAudioHelp: Bool { store.settings.allowAudioHelp }
    var completedRuns: Int { store.progress(for: carpet.id).completedRuns }
    var ratings: [String: TileRating] { engine.ratings }

    /// Manual "Richtig gelesen" is offered if enabled in settings, or as a rescue after two failed attempts.
    var showsRescueConfirm: Bool {
        settings.allowManualConfirm || engine.failedAttemptsOnCurrentTile >= ReadAloudFlow.failedAttemptsBeforeHelp
    }

    var isMicrophoneFlowActive: Bool { recognitionStatus.isAutoLoopRunning }

    func onAppear() {
        if !allowAudioHelp {
            mode = .read
        }
        Task {
            await prepareCarpetVocabulary()
        }
    }

    func selectTile(at index: Int) {
        stopContinuousReading()
        engine.selectTile(at: index)
        recognitionStatus = .idle

        if allowAudioHelp && mode == .learn && engine.activeTile != nil {
            speakCurrentTile()
        }
    }

    func speakCurrentTile() {
        guard allowAudioHelp, let tile = engine.activeTile else { return }
        stopLoopForSpeech()
        store.synthesizer.speak(
            tile: tile,
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    func speakSyllable(_ syllable: String) {
        guard allowAudioHelp else { return }
        stopLoopForSpeech()
        store.synthesizer.speakSyllable(
            syllable,
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    func toggleListening() {
        if isMicrophoneFlowActive || store.speechRecognizer.isListening {
            stopContinuousReading()
            recognitionStatus = .idle
            return
        }

        guard engine.activeTile != nil else { return }
        isContinuousReadingActive = settings.autoListenNextTile
        beginTurn()
    }

    /// From `.needsHelp`: try the same tile again. The failed-attempt counter keeps counting.
    func retryAfterHelp() {
        guard recognitionStatus == .needsHelp else { return }
        beginTurn()
    }

    /// From `.needsHelp`: move on, rating the tile as practised.
    func skipCurrentTile() {
        guard recognitionStatus == .needsHelp else { return }
        finishActiveTileManually(rating: .practiced)
    }

    func confirmCurrentTileManually() {
        finishActiveTileManually(rating: nil)
    }

    func restartCarpet() {
        // An explicit restart discards a read still inside its success hold instead of committing it.
        matchedTileID = nil
        stopAudioAndSpeech()
        engine.reset()
        lastRunResult = nil
        showCelebration = false
    }

    func stopAudioAndSpeech() {
        stopContinuousReading()
        store.synthesizer.stop()
        recognitionStatus = .idle
    }

    /// Before "Hör mal": in `.needsHelp` the loop is already paused, and the help choices must stay visible.
    private func stopLoopForSpeech() {
        guard recognitionStatus != .needsHelp else { return }
        stopContinuousReading()
        recognitionStatus = .idle
    }

    private func finishActiveTileManually(rating: TileRating?) {
        guard engine.activeTile != nil else { return }
        let shouldKeepContinuous = isContinuousReadingActive && settings.autoListenNextTile
        cancelPendingAutoContinue()
        listenTask?.cancel()
        listenTask = nil
        store.speechRecognizer.stopListening()
        store.synthesizer.stop()
        audioLevel = 0.0
        completeActiveTile(continueListening: shouldKeepContinuous, rating: rating)
    }

    private func stopContinuousReading() {
        cancelPendingAutoContinue()
        isContinuousReadingActive = false
        // Cancel first: a start that hasn't passed its permission prompt yet must not open the mic after Stop.
        listenTask?.cancel()
        listenTask = nil
        store.speechRecognizer.stopListening()
        audioLevel = 0.0
        evaluatingSince = nil
        // Interrupting the success hold (Stop, tapping another tile, backgrounding) must not lose a correct read.
        if let matchedTileID, matchedTileID == engine.activeTile?.id {
            completeActiveTile(continueListening: false)
        }
        matchedTileID = nil
    }

    private func cancelPendingAutoContinue() {
        autoContinueTask?.cancel()
        autoContinueTask = nil
    }

    /// `.ready` + "your turn" chime; the mic opens once the chime is over, after at least `ReadAloudFlow.readyDelay`.
    private func beginTurn() {
        guard let tile = engine.activeTile else {
            isContinuousReadingActive = false
            recognitionStatus = .idle
            return
        }

        cancelPendingAutoContinue()
        store.synthesizer.stop()
        recognitionStatus = .ready
        let soundsEnabled = settings.feedbackSounds

        autoContinueTask = Task { @MainActor [weak self] in
            let readyUntil = ContinuousClock.now + .seconds(ReadAloudFlow.readyDelay)
            await FeedbackSounds.playAndWait(.yourTurn, enabled: soundsEnabled)
            try? await Task.sleep(for: .seconds(ReadAloudFlow.chimeToMicGap))
            try? await Task.sleep(until: readyUntil, clock: .continuous)
            guard !Task.isCancelled, let self, self.engine.activeTile?.id == tile.id else { return }
            self.startListening(for: tile)
        }
    }

    private func startListening(for tile: ReadingTile) {
        recognitionStatus = .listening
        evaluatingSince = nil
        heardInAttempt = []

        let contextualWords = buildFocusedContextualVocabulary(for: tile)
        let isMultiWord = tile.display.contains(" ")
        let silenceCutoff = OnDeviceSpeechRecognizer.silenceCutoff(
            syllableCount: tile.syllables.count,
            isMultiWord: isMultiWord
        )

        listenTask?.cancel()
        listenTask = Task {
            await store.speechRecognizer.startListening(
                contextualWords: contextualWords,
                preferOnDevice: settings.preferOnDeviceRecognition,
                shortUtterance: !isMultiWord,
                silenceCutoff: silenceCutoff,
                onHypotheses: { [weak self] hypotheses, isFinal in
                    self?.handleHypotheses(hypotheses, isFinal: isFinal, for: tile)
                },
                onAudioLevel: { [weak self] level in
                    self?.audioLevel = level
                },
                onError: { [weak self] message in
                    self?.isContinuousReadingActive = false
                    self?.recognitionStatus = .unavailable(message: message)
                },
                onEndOfSpeech: { [weak self] in
                    guard let self, self.engine.activeTile?.id == tile.id, self.recognitionStatus == .listening else { return }
                    self.evaluatingSince = Date()
                    self.audioLevel = 0.0
                    self.recognitionStatus = .evaluating
                }
            )
        }
    }

    private func handleHypotheses(_ hypotheses: [String], isFinal: Bool, for tile: ReadingTile) {
        guard engine.activeTile?.id == tile.id else { return }

        if !hypotheses.isEmpty {
            heardInAttempt = hypotheses
        }
        let result = store.phoneticMatcher.match(
            hypotheses: heardInAttempt,
            tile: tile,
            strictness: settings.strictness
        )

        if result.isMatch {
            store.speechRecognizer.stopListening()
            audioLevel = 0.0
            matchedTileID = tile.id
            let shouldContinue = isContinuousReadingActive && settings.autoListenNextTile
            showOutcome(.matched(transcript: tile.display), sound: .success, hold: ReadAloudFlow.matchedHold) { [weak self] in
                self?.completeActiveTile(continueListening: shouldContinue)
            }
            return
        }

        guard isFinal else { return }
        audioLevel = 0.0
        engine.recordFailedAttempt()
        let needsHelp = engine.failedAttemptsOnCurrentTile >= ReadAloudFlow.failedAttemptsBeforeHelp
        let reason = ReadAloudFlow.retryReason(hypotheses: heardInAttempt, confidence: result.confidence)
        showOutcome(.retryNeeded(reason: reason), sound: .tryAgain, hold: ReadAloudFlow.retryHold) { [weak self] in
            guard let self else { return }
            if needsHelp {
                self.recognitionStatus = .needsHelp
            } else {
                self.beginTurn()
            }
        }
    }

    /// Shows `status` (after `.evaluating` had its minimum time), plays `sound`, holds, then runs `next`.
    private func showOutcome(
        _ status: SpeechRecognitionStatus,
        sound: FeedbackSounds.Sound,
        hold: TimeInterval,
        then next: @escaping @MainActor () -> Void
    ) {
        let evaluatingLeft = evaluatingSince.map { ReadAloudFlow.minEvaluatingDuration - Date().timeIntervalSince($0) } ?? 0
        evaluatingSince = nil
        cancelPendingAutoContinue()
        autoContinueTask = Task { @MainActor [weak self] in
            if evaluatingLeft > 0 {
                try? await Task.sleep(for: .seconds(evaluatingLeft))
            }
            guard !Task.isCancelled, let self else { return }
            self.recognitionStatus = status
            FeedbackSounds.play(sound, enabled: self.settings.feedbackSounds)
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            next()
        }
    }

    private func completeActiveTile(continueListening: Bool, rating: TileRating? = nil) {
        matchedTileID = nil
        // The finished carpet keeps its last tile active; completing it again must not record a second run.
        guard !engine.isCompleted else {
            isContinuousReadingActive = false
            recognitionStatus = .idle
            return
        }
        let finishedCarpet = engine.markCurrentTileCompleted(autoAdvance: settings.autoAdvanceOnMatch, rating: rating)

        if finishedCarpet {
            isContinuousReadingActive = false
            recognitionStatus = .idle
            let run = RunResult(
                date: Date(),
                ratings: engine.ratings,
                stars: ReadingSessionEngine.stars(for: Array(engine.ratings.values))
            )
            lastRunResult = run
            store.recordCarpetCompletion(carpetID: carpet.id, run: run)
            showCelebration = true
            return
        }

        if continueListening && settings.autoListenNextTile && settings.autoAdvanceOnMatch {
            isContinuousReadingActive = true
            beginTurn()
        } else {
            // Freihand: stop on the (already selected) next tile; the child starts it with the mic button.
            isContinuousReadingActive = false
            recognitionStatus = .idle
        }
    }

    /// Keep contextualStrings tightly focused on the active tile so other carpet words
    /// (e.g. "an", "Ana") don't compete with isolated sounds like "a".
    private func buildFocusedContextualVocabulary(for activeTile: ReadingTile) -> [String] {
        var words: [String] = [activeTile.display, activeTile.spokenText]
        words.append(contentsOf: activeTile.acceptedTranscriptions)
        return Array(Set(words.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
    }

    private func prepareCarpetVocabulary() async {
        var phrases: [String] = []
        for tile in carpet.tiles {
            phrases.append(tile.display)
            phrases.append(tile.spokenText)
            phrases.append(contentsOf: tile.acceptedTranscriptions)
        }
        await store.speechRecognizer.prepareCustomVocabulary(phrases: phrases)
    }
}
