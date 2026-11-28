import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class DiceReadingViewModel: ObservableObject {
    @Published var engine: DiceGameEngine
    @Published var isRolling: Bool = false
    @Published var displayedDiceFace: Int = 1
    @Published var recognitionStatus: SpeechRecognitionStatus = .idle
    @Published var audioLevel: Double = 0.0
    @Published var showWinnerCelebration: Bool = false

    private let store: AppStore
    /// Roll animation or the one pending step of the read-aloud loop (ready delay, outcome hold).
    private var pendingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    @Published private(set) var failedAttemptsOnCurrentCell: Int = 0
    private var evaluatingSince: Date?
    /// Latest non-empty hypotheses of the current attempt; the final result can arrive empty after a timeout.
    private var heardInAttempt: [String] = []
    /// Cell recognized but still inside the `.matched` hold; completed even if the hold is interrupted.
    private var matchedCellID: String?
    private var backgroundObserver: AnyCancellable?

    init(board: DiceBoard, store: AppStore) {
        self.engine = DiceGameEngine(board: board, twoPlayerMode: false)
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

    var board: DiceBoard { engine.board }
    var settings: AppSettings { store.settings }
    var allowAudioHelp: Bool { store.settings.allowAudioHelp }
    var activeCell: DiceCell? { engine.activeCell }
    var isMicrophoneFlowActive: Bool { recognitionStatus.isAutoLoopRunning }

    /// Manual "Richtig gelesen" is offered if enabled in settings, or as a rescue after two failed attempts.
    var showsRescueConfirm: Bool {
        settings.allowManualConfirm || failedAttemptsOnCurrentCell >= ReadAloudFlow.failedAttemptsBeforeHelp
    }

    func onAppear() {
        Task {
            await prepareBoardVocabulary()
        }
    }

    func setTwoPlayerMode(_ enabled: Bool) {
        matchedCellID = nil // the game restarts: don't commit (and maybe record a win for) a read in its success hold
        stopAudioAndSpeech()
        engine.reset(twoPlayerMode: enabled)
        failedAttemptsOnCurrentCell = 0
        showWinnerCelebration = false
    }

    func rollDice() {
        guard !isRolling, engine.winner == nil else { return }
        stopAudioAndSpeech()
        // Stopping may have completed a just-recognized cell, and that one can win the game.
        guard engine.winner == nil else { return }
        failedAttemptsOnCurrentCell = 0
        isRolling = true

        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<7 {
                self.displayedDiceFace = Int.random(in: 1...6)
                try? await Task.sleep(for: .milliseconds(65))
                if Task.isCancelled { return }
            }
            if let coord = self.engine.roll() {
                self.displayedDiceFace = coord.diceValue
            }
            self.isRolling = false

            if self.settings.autoListenNextTile, self.engine.activeCell != nil {
                self.beginTurn()
            }
        }
    }

    func selectColumn(_ diceValue: Int) {
        stopAudioAndSpeech()
        let previousCellID = engine.activeCell?.id
        engine.selectNextFreeCell(in: diceValue)
        if engine.activeCell?.id != previousCellID {
            failedAttemptsOnCurrentCell = 0
        }
        displayedDiceFace = diceValue
    }

    func speakActiveCell() {
        guard allowAudioHelp, let cell = engine.activeCell else { return }
        stopLoopForSpeech()
        store.synthesizer.speak(
            tile: cell.asReadingTile,
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    /// Reads the game rules aloud; offered even when audio help for the words is off.
    func speakRules() {
        stopLoopForSpeech()
        store.synthesizer.speakText(
            "Wer erreicht zuerst den Schatz? Würfle und lies das unterste freie Kästchen der Spalte vor.",
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    func toggleListening() {
        // Also covers the permission-prompt phase (status already .listening, recognizer not yet).
        if store.speechRecognizer.isListening || isMicrophoneFlowActive {
            stopAudioAndSpeech()
            return
        }
        beginTurn()
    }

    /// From `.needsHelp`: try the same cell again. The failed-attempt counter keeps counting.
    func retryAfterHelp() {
        guard recognitionStatus == .needsHelp else { return }
        beginTurn()
    }

    /// From `.needsHelp`: mark the cell as done, like a manual confirm.
    func skipActiveCell() {
        guard recognitionStatus == .needsHelp else { return }
        confirmActiveCell()
    }

    func confirmActiveCell() {
        stopAudioAndSpeech()
        // No-op if stopping already completed a just-recognized cell (the engine clears the active cell).
        completeActiveCell()
    }

    func restartGame() {
        matchedCellID = nil // explicit restart: discard a read still inside its success hold
        stopAudioAndSpeech()
        engine.reset()
        failedAttemptsOnCurrentCell = 0
        showWinnerCelebration = false
    }

    func stopAudioAndSpeech() {
        pendingTask?.cancel()
        pendingTask = nil
        // Cancel first: a start that hasn't passed its permission prompt yet must not open the mic after Stop.
        listenTask?.cancel()
        listenTask = nil
        store.speechRecognizer.stopListening()
        store.synthesizer.stop()
        isRolling = false // a cancelled mid-roll task never resets it, which would lock the dice button
        audioLevel = 0.0
        evaluatingSince = nil
        // Interrupting the success hold (Stop, rolling, backgrounding) must not lose a correct read.
        if let matchedCellID, matchedCellID == engine.activeCell?.id {
            completeActiveCell()
        }
        matchedCellID = nil
        recognitionStatus = .idle
    }

    /// Before "Hör mal": in `.needsHelp` the loop is already paused, and the help choices must stay visible.
    private func stopLoopForSpeech() {
        guard recognitionStatus != .needsHelp else { return }
        stopAudioAndSpeech()
    }

    private func completeActiveCell() {
        matchedCellID = nil
        let won = engine.completeActiveCell()
        failedAttemptsOnCurrentCell = 0
        recognitionStatus = .idle
        if won {
            store.recordDiceWin()
            showWinnerCelebration = true
        }
    }

    /// `.ready` + "your turn" chime; the mic opens once the chime is over, after at least `ReadAloudFlow.readyDelay`.
    private func beginTurn() {
        guard let cell = engine.activeCell else { return }
        pendingTask?.cancel()
        store.synthesizer.stop()
        recognitionStatus = .ready
        let soundsEnabled = settings.feedbackSounds

        pendingTask = Task { @MainActor [weak self] in
            let readyUntil = ContinuousClock.now + .seconds(ReadAloudFlow.readyDelay)
            await FeedbackSounds.playAndWait(.yourTurn, enabled: soundsEnabled)
            try? await Task.sleep(for: .seconds(ReadAloudFlow.chimeToMicGap))
            try? await Task.sleep(until: readyUntil, clock: .continuous)
            guard !Task.isCancelled, let self, self.engine.activeCell?.id == cell.id else { return }
            self.startListening(for: cell)
        }
    }

    private func startListening(for cell: DiceCell) {
        recognitionStatus = .listening
        evaluatingSince = nil
        heardInAttempt = []

        let tile = cell.asReadingTile
        let contextualWords = Array(Set([cell.spokenText, cell.display] + cell.acceptedTranscriptions))
        let isMultiWord = cell.spokenText.contains(" ")
        let silenceCutoff = OnDeviceSpeechRecognizer.silenceCutoff(
            syllableCount: cell.syllables.count,
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
                    self?.recognitionStatus = .unavailable(message: message)
                },
                onEndOfSpeech: { [weak self] in
                    guard let self, self.engine.activeCell?.id == tile.id, self.recognitionStatus == .listening else { return }
                    self.evaluatingSince = Date()
                    self.audioLevel = 0.0
                    self.recognitionStatus = .evaluating
                }
            )
        }
    }

    private func handleHypotheses(_ hypotheses: [String], isFinal: Bool, for tile: ReadingTile) {
        guard engine.activeCell?.id == tile.id else { return }

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
            matchedCellID = tile.id
            showOutcome(.matched(transcript: tile.display), sound: .success, hold: ReadAloudFlow.matchedHold) { [weak self] in
                self?.completeActiveCell()
            }
            return
        }

        guard isFinal else { return }
        audioLevel = 0.0
        failedAttemptsOnCurrentCell += 1
        let needsHelp = failedAttemptsOnCurrentCell >= ReadAloudFlow.failedAttemptsBeforeHelp
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
        pendingTask?.cancel()
        pendingTask = Task { @MainActor [weak self] in
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

    private func prepareBoardVocabulary() async {
        var phrases: [String] = []
        for column in board.columns {
            for cell in column.cells {
                phrases.append(cell.spokenText)
                phrases.append(contentsOf: cell.acceptedTranscriptions)
            }
        }
        await store.speechRecognizer.prepareCustomVocabulary(phrases: phrases)
    }
}
