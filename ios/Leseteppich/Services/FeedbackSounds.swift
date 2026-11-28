import AudioToolbox
import UIKit

/// Short built-in system chimes for the read-aloud loop (no bundled assets).
@MainActor
enum FeedbackSounds {
    enum Sound {
        case yourTurn
        case success
        case tryAgain

        /// iOS system sound IDs; they follow the ringer switch like any system sound.
        var systemSoundID: SystemSoundID {
            switch self {
            case .yourTurn: return 1113 // "begin_record": the familiar "I'm listening" tone
            case .success: return 1025  // "Fanfare"
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
}
