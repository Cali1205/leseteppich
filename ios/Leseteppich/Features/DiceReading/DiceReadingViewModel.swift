import Foundation
import SwiftUI

@MainActor
final class DiceReadingViewModel: ObservableObject {
    @Published var engine: DiceGameEngine
    @Published var isRolling: Bool = false
    @Published var displayedDiceFace: Int = 1
    @Published var recognitionStatus: SpeechRecognitionStatus = .idle
    @Published var audioLevel: Double = 0.0
    @Published var showWinnerCelebration: Bool = false

    private let store: AppStore

    init(board: DiceBoard, store: AppStore) {
        self.engine = DiceGameEngine(board: board, twoPlayerMode: false)
        self.store = store
    }

    var board: DiceBoard { engine.board }
    var settings: AppSettings { store.settings }
    var activeCell: DiceCell? { engine.activeCell }

    func setTwoPlayerMode(_ enabled: Bool) {
        stopAudioAndSpeech()
        engine.reset(twoPlayerMode: enabled)
        recognitionStatus = .idle
        showWinnerCelebration = false
    }

    func rollDice() {
        guard !isRolling, engine.winner == nil else { return }
        stopAudioAndSpeech()
        recognitionStatus = .idle
        isRolling = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<7 {
                self.displayedDiceFace = Int.random(in: 1...6)
                try? await Task.sleep(for: .milliseconds(65))
            }
            if let coord = self.engine.roll() {
                self.displayedDiceFace = coord.diceValue
            }
            self.isRolling = false
        }
    }

    func selectColumn(_ diceValue: Int) {
        stopAudioAndSpeech()
        recognitionStatus = .idle
        engine.selectNextFreeCell(in: diceValue)
        displayedDiceFace = diceValue
    }

    func speakActiveCell() {
        guard let cell = engine.activeCell else { return }
        store.speechRecognizer.stopListening()
        recognitionStatus = .idle
        store.synthesizer.speak(tile: cell.asReadingTile, rate: settings.speechRate)
    }

    func toggleListening() {
        if store.speechRecognizer.isListening {
            store.speechRecognizer.stopListening()
            recognitionStatus = .idle
            return
        }

        guard let cell = engine.activeCell else { return }
        store.synthesizer.stop()
        recognitionStatus = .listening

        let tile = cell.asReadingTile
        let contextualWords = Array(Set([cell.spokenText, cell.display] + cell.acceptedTranscriptions))

        Task {
            await store.speechRecognizer.startListening(
                contextualWords: contextualWords,
                preferOnDevice: settings.preferOnDeviceRecognition,
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

    func confirmActiveCell() {
        stopAudioAndSpeech()
        let won = engine.completeActiveCell()
        recognitionStatus = .idle
        if won {
            store.recordDiceWin()
            showWinnerCelebration = true
        }
    }

    func restartGame() {
        stopAudioAndSpeech()
        engine.reset()
        recognitionStatus = .idle
        showWinnerCelebration = false
    }

    func stopAudioAndSpeech() {
        store.speechRecognizer.stopListening()
        store.synthesizer.stop()
        audioLevel = 0.0
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
            recognitionStatus = .matched(transcript: result.matchedHypothesis ?? tile.spokenText)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(550))
                self?.confirmActiveCell()
            }
            return
        }

        if isFinal {
            recognitionStatus = .retryNeeded(heard: hypotheses.first)
        }
    }
}
