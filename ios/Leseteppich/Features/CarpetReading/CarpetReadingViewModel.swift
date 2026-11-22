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
    @Published var isContinuousReadingActive: Bool = false

    private let store: AppStore
    private var autoContinueTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?
    private var consecutiveAutoRetries: Int = 0
    private let maxAutoRetriesPerTile: Int = 2
    private var backgroundObserver: AnyCancellable?

    init(carpet: Carpet, store: AppStore) {
        self.engine = ReadingSessionEngine(carpet: carpet)
        self.store = store
        // The app-level stop only halts the services; this also kills the pending sleep tasks that would reopen the mic.
        backgroundObserver = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.stopContinuousReading()
                    self?.recognitionStatus = .idle
                }
            }
    }

    var carpet: Carpet { engine.carpet }
    var activeTile: ReadingTile? { engine.activeTile }
    var settings: AppSettings { store.settings }
    var allowAudioHelp: Bool { store.settings.allowAudioHelp }
    var completedRuns: Int { store.progress(for: carpet.id).completedRuns }

    /// Manual "Richtig gelesen" is offered if enabled in settings, or as a rescue after two failed attempts.
    var showsRescueConfirm: Bool {
        settings.allowManualConfirm || engine.failedAttemptsOnCurrentTile >= 2
    }

    var isMicrophoneFlowActive: Bool {
        recognitionStatus == .listening || recognitionStatus == .preparingNext || isContinuousReadingActive
    }

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
        stopContinuousReading()
        recognitionStatus = .idle
        store.synthesizer.speak(
            tile: tile,
            rate: settings.speechRate,
            voiceIdentifier: settings.selectedVoiceIdentifier
        )
    }

    func speakSyllable(_ syllable: String) {
        guard allowAudioHelp else { return }
        stopContinuousReading()
        recognitionStatus = .idle
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
        consecutiveAutoRetries = 0
        isContinuousReadingActive = settings.autoListenNextTile
        beginListeningForActiveTile()
    }

    func confirmCurrentTileManually() {
        let shouldKeepContinuous = isContinuousReadingActive && settings.autoListenNextTile
        cancelPendingAutoContinue()
        listenTask?.cancel()
        listenTask = nil
        store.speechRecognizer.stopListening()
        store.synthesizer.stop()
        audioLevel = 0.0
        consecutiveAutoRetries = 0
        completeActiveTile(continueListening: shouldKeepContinuous)
    }

    func restartCarpet() {
        stopContinuousReading()
        engine.reset()
        recognitionStatus = .idle
        showCelebration = false
    }

    func stopAudioAndSpeech() {
        stopContinuousReading()
        store.synthesizer.stop()
    }

    private func stopContinuousReading() {
        cancelPendingAutoContinue()
        isContinuousReadingActive = false
        consecutiveAutoRetries = 0
        // Cancel first: a start that hasn't passed its permission prompt yet must not open the mic after Stop.
        listenTask?.cancel()
        listenTask = nil
        store.speechRecognizer.stopListening()
        audioLevel = 0.0
    }

    private func cancelPendingAutoContinue() {
        autoContinueTask?.cancel()
        autoContinueTask = nil
    }

    private func beginListeningForActiveTile() {
        guard let tile = engine.activeTile else {
            isContinuousReadingActive = false
            recognitionStatus = .idle
            return
        }

        cancelPendingAutoContinue()
        store.synthesizer.stop()
        recognitionStatus = .listening

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
                }
            )
        }
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
            audioLevel = 0.0
            consecutiveAutoRetries = 0
            recognitionStatus = .matched(transcript: result.matchedHypothesis ?? tile.display)

            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)

            let shouldContinue = isContinuousReadingActive && settings.autoListenNextTile
            cancelPendingAutoContinue()
            autoContinueTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled, let self else { return }
                self.completeActiveTile(continueListening: shouldContinue)
            }
            return
        }

        if isFinal {
            engine.recordFailedAttempt()
            recognitionStatus = .retryNeeded(heard: hypotheses.first)

            if isContinuousReadingActive && settings.autoListenNextTile && consecutiveAutoRetries < maxAutoRetriesPerTile {
                consecutiveAutoRetries += 1
                cancelPendingAutoContinue()
                autoContinueTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(1200))
                    guard !Task.isCancelled, let self, self.isContinuousReadingActive else { return }
                    self.beginListeningForActiveTile()
                }
            } else {
                isContinuousReadingActive = false
            }
        }
    }

    private func completeActiveTile(continueListening: Bool) {
        let finishedCarpet = engine.markCurrentTileCompleted(autoAdvance: settings.autoAdvanceOnMatch)

        if finishedCarpet {
            isContinuousReadingActive = false
            recognitionStatus = .idle
            store.recordCarpetCompletion(carpetID: carpet.id)
            showCelebration = true
            return
        }

        if continueListening && settings.autoListenNextTile && settings.autoAdvanceOnMatch {
            isContinuousReadingActive = true
            recognitionStatus = .preparingNext
            cancelPendingAutoContinue()
            autoContinueTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(750))
                guard !Task.isCancelled, let self, self.isContinuousReadingActive else { return }
                self.beginListeningForActiveTile()
            }
        } else {
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
