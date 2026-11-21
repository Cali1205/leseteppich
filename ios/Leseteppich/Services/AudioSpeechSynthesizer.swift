import AVFoundation
import Foundation

@MainActor
public final class AudioSpeechSynthesizer: NSObject, SpeechSynthesizing, ObservableObject {
    @Published public private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let voiceRecorder: VoiceRecording?

    public init(voiceRecorder: VoiceRecording? = nil) {
        self.voiceRecorder = voiceRecorder
        super.init()
        synthesizer.delegate = self
    }

    public func speak(tile: ReadingTile, rate: Double) {
        stop()
        configurePlaybackSession()

        // Tier 1: Prefer authentic parent/teacher recording if available!
        if let recorder = voiceRecorder, recorder.hasRecording(for: tile.id) {
            let url = recorder.recordingURL(for: tile.id)
            if playRecording(at: url) {
                return
            }
        }

        // Tier 2: IPA-annotated utterance for isolated single phonemes so "n" sounds like "nnn", not "Enn".
        let utterance: AVSpeechUtterance
        if tile.isSinglePhoneme, let ipa = tile.ipa, !ipa.isEmpty {
            let attributed = NSAttributedString(
                string: tile.spokenText,
                attributes: [
                    NSAttributedString.Key(rawValue: AVSpeechSynthesisIPANotationAttribute): ipa
                ]
            )
            utterance = AVSpeechUtterance(attributedString: attributed)
        } else {
            utterance = AVSpeechUtterance(string: tile.spokenText)
        }

        applyGermanVoice(to: utterance, rate: rate)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func speakSyllable(_ syllable: String, rate: Double) {
        let trimmed = syllable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        speakText(trimmed, rate: max(0.32, rate - 0.05))
    }

    public func speakText(_ text: String, rate: Double) {
        stop()
        configurePlaybackSession()

        let utterance = AVSpeechUtterance(string: text)
        applyGermanVoice(to: utterance, rate: rate)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    private func playRecording(at url: URL) -> Bool {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            if player.play() {
                audioPlayer = player
                isSpeaking = true
                return true
            }
        } catch {
            print("AudioSpeechSynthesizer playback error: \(error)")
        }
        return false
    }

    private func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func applyGermanVoice(to utterance: AVSpeechUtterance, rate: Double) {
        let germanVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "de-DE" }
        let preferredVoice = germanVoices
            .sorted(by: { $0.quality.rawValue > $1.quality.rawValue })
            .first ?? AVSpeechSynthesisVoice(language: "de-DE")

        utterance.voice = preferredVoice
        let clamped = min(max(Float(rate), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.rate = clamped
        utterance.pitchMultiplier = 1.04
        utterance.preUtteranceDelay = 0.05
    }
}

extension AudioSpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

extension AudioSpeechSynthesizer: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.audioPlayer = nil
            self.isSpeaking = false
        }
    }
}
