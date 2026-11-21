import AVFoundation
import Foundation

public struct GermanVoiceOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let language: String
    public let qualityRank: Int

    public var qualityBadge: String {
        switch qualityRank {
        case 3: return "Premium"
        case 2: return "Erweitert"
        default: return "Standard"
        }
    }

    public var displayLabel: String {
        "\(name) (\(qualityBadge))"
    }
}

public enum GermanVoiceSelector {
    /// Returns all natural German voices installed on the device, excluding retro
    /// formant-synthesis Eloquence and novelty voices, sorted Premium -> Enhanced -> Default.
    public static func availableGermanVoices(preferredLocale: String = "de-DE") -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { voice in
                let isGerman = voice.language.lowercased().hasPrefix("de")
                    || voice.identifier.lowercased().contains(".de-")
                guard isGerman else { return false }

                let lowerID = voice.identifier.lowercased()
                if lowerID.contains("eloquence") || lowerID.contains("synthesis.voice.") {
                    return false
                }

                if voice.voiceTraits.contains(.isNoveltyVoice) ||
                    voice.voiceTraits.contains(.isPersonalVoice) {
                    return false
                }

                return true
            }
            .sorted { lhs, rhs in
                let lhsRank = qualityRank(lhs.quality)
                let rhsRank = qualityRank(rhs.quality)
                if lhsRank != rhsRank {
                    return lhsRank > rhsRank
                }

                let lhsExact = lhs.language.caseInsensitiveCompare(preferredLocale) == .orderedSame
                let rhsExact = rhs.language.caseInsensitiveCompare(preferredLocale) == .orderedSame
                if lhsExact != rhsExact {
                    return lhsExact
                }

                return lhs.name < rhs.name
            }
    }

    public static func voiceOptions(preferredLocale: String = "de-DE") -> [GermanVoiceOption] {
        availableGermanVoices(preferredLocale: preferredLocale).map { voice in
            GermanVoiceOption(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                qualityRank: qualityRank(voice.quality)
            )
        }
    }

    public static func bestGermanVoice(
        savedIdentifier: String? = nil,
        preferredLocale: String = "de-DE"
    ) -> AVSpeechSynthesisVoice? {
        if let savedIdentifier,
           !savedIdentifier.isEmpty,
           let saved = AVSpeechSynthesisVoice(identifier: savedIdentifier) {
            return saved
        }
        return availableGermanVoices(preferredLocale: preferredLocale).first
            ?? AVSpeechSynthesisVoice(language: preferredLocale)
    }

    public static var hasHighQualityGermanVoice: Bool {
        availableGermanVoices().contains { qualityRank($0.quality) >= 2 }
    }

    public static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        if quality == .premium {
            return 3
        }
        switch quality {
        case .enhanced: return 2
        default: return 1
        }
    }
}

@MainActor
public final class AudioSpeechSynthesizer: NSObject, SpeechSynthesizing, ObservableObject {
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var availableVoices: [GermanVoiceOption] = []
    @Published public private(set) var hasHighQualityVoice: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let voiceRecorder: VoiceRecording?
    private let bundle: Bundle

    private static let naturalSingleVowels: [String: String] = [
        "a": "Ah",
        "e": "Eh",
        "i": "Ih",
        "o": "Oh",
        "u": "Uh"
    ]

    public init(voiceRecorder: VoiceRecording? = nil, bundle: Bundle = .main) {
        self.voiceRecorder = voiceRecorder
        self.bundle = bundle
        super.init()
        synthesizer.delegate = self
        refreshVoices()
    }

    /// Refreshes installed German voices (call on app foreground so newly downloaded iOS Premium voices appear immediately).
    public func refreshVoices() {
        availableVoices = GermanVoiceSelector.voiceOptions()
        hasHighQualityVoice = GermanVoiceSelector.hasHighQualityGermanVoice
    }

    public func speak(tile: ReadingTile, rate: Double, voiceIdentifier: String? = nil) {
        stop()
        configurePlaybackSession(active: true)

        // Tier 1: Prefer authentic parent/teacher recording if available!
        if let recorder = voiceRecorder, recorder.hasRecording(for: tile.id) {
            let url = recorder.recordingURL(for: tile.id)
            if playRecording(at: url) {
                return
            }
        }

        // Tier 2: Prefer bundled natural audio clip if present in app bundle (cross-platform shared audio pack).
        if let bundledURL = bundle.url(forResource: tile.id, withExtension: "m4a") {
            if playRecording(at: bundledURL) {
                return
            }
        }

        // Tier 3: Natural German neural AVSpeechSynthesizer.
        let utterance: AVSpeechUtterance
        let lowerDisplay = tile.display.lowercased(with: Locale(identifier: "de_DE"))

        if tile.isSinglePhoneme, let naturalVowel = Self.naturalSingleVowels[lowerDisplay] {
            // Speaking "Ah"/"Ih"/"Oh" with a neural voice avoids compact-voice IPA fallback artifacts.
            utterance = AVSpeechUtterance(string: naturalVowel)
        } else if tile.isSinglePhoneme, let ipa = tile.ipa, !ipa.isEmpty {
            // For isolated consonants like "n", IPA hints the pure sound ("nnn") instead of letter name ("Enn").
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

        applyGermanVoice(to: utterance, rate: rate, voiceIdentifier: voiceIdentifier)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    public func speakSyllable(_ syllable: String, rate: Double, voiceIdentifier: String? = nil) {
        let trimmed = syllable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased(with: Locale(identifier: "de_DE"))
        let text = Self.naturalSingleVowels[lower] ?? trimmed
        speakText(text, rate: max(0.40, rate - 0.03), voiceIdentifier: voiceIdentifier)
    }

    public func speakText(_ text: String, rate: Double, voiceIdentifier: String? = nil) {
        stop()
        configurePlaybackSession(active: true)

        let utterance = AVSpeechUtterance(string: text)
        applyGermanVoice(to: utterance, rate: rate, voiceIdentifier: voiceIdentifier)
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

    private func configurePlaybackSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                // Use .default mode (not .spokenAudio) so iOS preserves neural voice clarity on real devices.
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                try session.setActive(true)
            } else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            print("AudioSpeechSynthesizer session error: \(error)")
        }
    }

    private func applyGermanVoice(to utterance: AVSpeechUtterance, rate: Double, voiceIdentifier: String?) {
        utterance.voice = GermanVoiceSelector.bestGermanVoice(savedIdentifier: voiceIdentifier)
        let clamped = min(max(Float(rate), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.rate = clamped
        // Keep neutral pitch (1.0) so Enhanced/Premium neural voices sound natural without metallic distortion.
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.04
        utterance.postUtteranceDelay = 0.04
    }
}

extension AudioSpeechSynthesizer: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking, self.audioPlayer == nil else { return }
            self.isSpeaking = false
            self.configurePlaybackSession(active: false)
        }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking, self.audioPlayer == nil else { return }
            self.isSpeaking = false
            self.configurePlaybackSession(active: false)
        }
    }
}

extension AudioSpeechSynthesizer: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.audioPlayer = nil
            self.isSpeaking = false
            self.configurePlaybackSession(active: false)
        }
    }
}
