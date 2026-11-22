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
    private var pendingTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    @Published private(set) var failedAttemptsOnCurrentCell: Int = 0
    private var backgroundObserver: AnyCancellable?

    init(board: DiceBoard, store: AppStore) {
        self.engine = DiceGameEngine(board: board, twoPlayerMode: false)
        self.store = store
        // The app-level stop only halts the services; this also kills the pending sleep tasks that would reopen the mic.
        backgroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.stopAudioAndSpeech()
                    self?.recognitionStatus = .idle
                }
            }
    }

    var board: DiceBoard { engine.board }
    var settings: AppSettings { store.settings }
    var allowAudioHelp: Bool { store.settings.allowAudioHelp }
    var activeCell: DiceCell? { engine.activeCell }

    /// Manual "Richtig gelesen" is offered if enabled in settings, or as a rescue after two failed attempts.
    var showsRescueConfirm: Bool {
        settings.allowManualConfirm || failedAttemptsOnCurrentCell >= 2
    }

    func onAppear() {
        Task {
            await prepareBoardVocabulary()
        }
    }

    func setTwoPlayerMode(_ enabled: Bool) {
        stopAudioAndSpeech()
        engine.reset(twoPlayerMode: enabled)
        failedAttemptsOnCurrentCell = 0
        recognitionStatus = .idle
        showWinnerCelebration = false
    }

    func rollDice() {
        guard !isRolling, engine.winner == nil else { return }
        stopAudioAndSpeech()
        recognitionStatus = .idle
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
                self.recognitionStatus = .preparingNext
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
                self.startListeningForActiveCell()
            }
        }
    }

    func selectColumn(_ diceValue: Int) {
        stopAudioAndSpeech()
        recognitionStatus = .idle
        let previousCellID = engine.activeCell?.id
        engine.selectNextFreeCell(in: diceValue)
        if engine.activeCell?.id != previousCellID {
            failedAttemptsOnCurrentCell = 0
        }
        displayedDiceFace = diceValue
    }

    func speakActiveCell() {
        guard allowAudioHelp, let cell = engine.activeCell else { return }
        stopAudioAndSpeech()
        recognitionStatus = .idle
        store.synthesizer.speak(
            tile: cell.asReadingTile,
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    func toggleListening() {
        // Also covers the permission-prompt phase (status already .listening, recognizer not yet).
        if store.speechRecognizer.isListening || recognitionStatus == .listening || recognitionStatus == .preparingNext {
            stopAudioAndSpeech()
            recognitionStatus = .idle
            return
        }
        startListeningForActiveCell()
    }

    func confirmActiveCell() {
        stopAudioAndSpeech()
        let won = engine.completeActiveCell()
        failedAttemptsOnCurrentCell = 0
        recognitionStatus = .idle
        if won {
            store.recordDiceWin()
            showWinnerCelebration = true
        }
    }

    func restartGame() {
        stopAudioAndSpeech()
        engine.reset()
        failedAttemptsOnCurrentCell = 0
        recognitionStatus = .idle
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
    }

    private func startListeningForActiveCell() {
        guard let cell = engine.activeCell else { return }
        store.synthesizer.stop()
        recognitionStatus = .listening

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
                }
            )
        }
    }

    private func handleHypotheses(_ hypotheses: [String], isFinal: Bool, for tile: ReadingTile) {
        guard engine.activeCell?.id == tile.id else { return }

        let result = store.phoneticMatcher.match(
            hypotheses: hypotheses,
            tile: tile,
            strictness: settings.strictness
        )

        if result.isMatch {
            store.speechRecognizer.stopListening()
            audioLevel = 0.0
            recognitionStatus = .matched(transcript: result.matchedHypothesis ?? tile.spokenText)

            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)

            pendingTask?.cancel()
            pendingTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                self?.confirmActiveCell()
            }
            return
        }

        if isFinal {
            failedAttemptsOnCurrentCell += 1
            recognitionStatus = .retryNeeded(heard: hypotheses.first)
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
