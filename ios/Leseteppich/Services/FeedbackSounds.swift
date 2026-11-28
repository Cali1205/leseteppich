import AudioToolbox
import Foundation
import UIKit

/// Short built-in system chimes for the read-aloud loop (no bundled assets).
/// shortcut: system sounds obey the mute switch, so a muted iPhone plays no chime (the haptic still fires);
/// bundled tones via AVAudioPlayer would be the upgrade if children miss the cue.
@MainActor
enum FeedbackSounds {
    enum Sound {
        case yourTurn
        case success
        case tryAgain

        /// Short, soft iOS system sounds from the Siri family, so all three feel like one set (each well under 1 s).
        var systemSoundID: SystemSoundID {
            switch self {
            case .yourTurn: return 1113 // "begin_record": the familiar "I'm listening" tone
            case .success: return 1111  // "jbl_confirm": short and positive, no long fanfare
            case .tryAgain: return 1115 // "jbl_ambiguous": soft, not a harsh error buzz
            }
        }
    }

    /// The success haptic always fires; `enabled` (settings.feedbackSounds) only gates the sound.
    static func play(_ sound: Sound, enabled: Bool) {
        if sound == .success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        guard enabled else { return }
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }

    /// Plays `sound` and returns once it finished (or after `timeout`, if iOS never reports completion),
    /// so the mic doesn't open while the chime is still coming out of the speaker.
    static func playAndWait(_ sound: Sound, enabled: Bool, timeout: TimeInterval = 1.0) async {
        if sound == .success {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        guard enabled else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = ResumeOnce(continuation)
            AudioServicesPlaySystemSoundWithCompletion(sound.systemSoundID) { once.resume() }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once.resume() }
        }
    }
}

/// The completion and the timeout race on different threads; only the first may resume the continuation.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
    }
}
