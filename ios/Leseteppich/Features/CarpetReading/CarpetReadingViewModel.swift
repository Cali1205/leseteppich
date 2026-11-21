import Foundation
import SwiftUI

@MainActor
final class CarpetReadingViewModel: ObservableObject {
    @Published var engine: ReadingSessionEngine
    @Published var mode: ReadingMode = .read
    @Published var recognitionStatus: SpeechRecognitionStatus = .idle
    @Published var audioLevel: Double = 0.0
    @Published var showCelebration: Bool = false

    private let store: AppStore

    init(carpet: Carpet, store: AppStore) {
        self.engine = ReadingSessionEngine(carpet: carpet)
        self.store = store
    }

    var carpet: Carpet { engine.carpet }
    var activeTile: ReadingTile? { engine.activeTile }
    var settings: AppSettings { store.settings }
    var completedRuns: Int { store.progress(for: carpet.id).completedRuns }

    func selectTile(at index: Int) {
        stopAudioAndSpeech()
        engine.selectTile(at: index)
        recognitionStatus = .idle

        if mode == .learn, engine.activeTile != nil {
            speakCurrentTile()
        }
    }

    func speakCurrentTile() {
        guard let tile = engine.activeTile else { return }
        store.speechRecognizer.stopListening()
        recognitionStatus = .idle
        store.synthesizer.speak(tile: tile, rate: settings.speechRate)
    }

    func speakSyllable(_ syllable: String) {
        store.speechRecognizer.stopListening()
        recognitionStatus = .idle
        store.synthesizer.speakSyllable(syllable, rate: settings.speechRate)
    }

    func toggleListening() {
        if store.speechRecognizer.isListening {
            store.speechRecognizer.stopListening()
            recognitionStatus = .idle
            return
        }

        guard let tile = engine.activeTile else { return }
        store.synthesizer.stop()
        recognitionStatus = .listening

        let contextualWords = buildContextualVocabulary(for: tile)

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

    func confirmCurrentTileManually() {
        stopAudioAndSpeech()
        completeActiveTile()
    }

    func restartCarpet() {
        stopAudioAndSpeech()
        engine.reset()
        recognitionStatus = .idle
        showCelebration = false
    }

    func stopAudioAndSpeech() {
        store.speechRecognizer.stopListening()
        store.synthesizer.stop()
        audioLevel = 0.0
    }

    private func handleHypotheses(_ hypotheses: [String], isFinal: Bool, for tile: ReadingTile) {
        guard engine.activeTile?.id == tile.id else { return }

        let result = store.phoneticMatcher.match(
            hypotheses: hypotheses,
            tile: tile,
            strictness: settings.strictness
        )

        if result.isMatch {
            store.speechRecognizer.stopListening()
            recognitionStatus = .matched(transcript: result.matchedHypothesis ?? tile.display)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(550))
                self?.completeActiveTile()
            }
            return
        }

        if isFinal {
            engine.recordFailedAttempt()
            recognitionStatus = .retryNeeded(heard: hypotheses.first)
        }
    }

    private func completeActiveTile() {
        let finishedCarpet = engine.markCurrentTileCompleted(autoAdvance: settings.autoAdvanceOnMatch)
        recognitionStatus = .idle

        if finishedCarpet {
            store.recordCarpetCompletion(carpetID: carpet.id)
            showCelebration = true
        }
    }

    private func buildContextualVocabulary(for activeTile: ReadingTile) -> [String] {
        var words: [String] = [activeTile.display, activeTile.spokenText]
        words.append(contentsOf: activeTile.acceptedTranscriptions)
        for tile in carpet.tiles {
            words.append(tile.display)
            words.append(tile.spokenText)
        }
        return Array(Set(words))
    }
}
