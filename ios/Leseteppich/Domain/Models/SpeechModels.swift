import Foundation

public struct RecognitionMatchResult: Equatable, Sendable {
    public let isMatch: Bool
    public let confidence: Double
    public let matchedHypothesis: String?
    public let reason: String

    public init(isMatch: Bool, confidence: Double, matchedHypothesis: String?, reason: String) {
        self.isMatch = isMatch
        self.confidence = confidence
        self.matchedHypothesis = matchedHypothesis
        self.reason = reason
    }
}

public enum RetryReason: Equatable, Sendable {
    case heardNothing
    case close
    case wrong
}

public enum SpeechRecognitionStatus: Equatable, Sendable {
    case idle
    /// "Du bist dran!" – chime played, mic about to open.
    case ready
    case listening
    /// The child stopped speaking; waiting for the final recognition result.
    case evaluating
    case matched(transcript: String)
    case retryNeeded(reason: RetryReason)
    /// After `ReadAloudFlow.failedAttemptsBeforeHelp` failed attempts on the same tile: the auto-loop is paused.
    case needsHelp
    case preparingNext
    case unavailable(message: String)

    /// True while the read-aloud loop moves on by itself, including outcome holds that continue automatically.
    public var isAutoLoopRunning: Bool {
        switch self {
        case .ready, .listening, .evaluating, .matched, .retryNeeded, .preparingNext:
            return true
        case .idle, .needsHelp, .unavailable:
            return false
        }
    }
}

/// Timings and rules of the "read aloud → get rated" loop shared by carpet and dice reading.
public enum ReadAloudFlow {
    /// Pause between the "your turn" chime and opening the mic.
    public static let readyDelay: TimeInterval = 0.8
    /// Minimum time `.evaluating` stays visible so it doesn't just flicker.
    public static let minEvaluatingDuration: TimeInterval = 0.35
    /// How long `.matched` is shown before moving on.
    public static let matchedHold: TimeInterval = 1.2
    /// How long `.retryNeeded` is shown before listening again.
    public static let retryHold: TimeInterval = 1.4
    /// From this many failed attempts on one tile on, the loop stops at `.needsHelp` instead of retrying.
    public static let failedAttemptsBeforeHelp = 2
    /// Lowest fuzzy matcher score (0–1) that still counts as "almost". The matcher accepts from 0.75 (gentle) /
    /// 0.84 (normal); 0.5 means at least half of the phonetic key was right, i.e. a real attempt at the word.
    public static let closeConfidence: Double = 0.5

    /// Classifies a failed final result. `hypotheses` should be the latest non-empty ones heard in this attempt.
    public static func retryReason(hypotheses: [String], confidence: Double) -> RetryReason {
        let heardSomething = hypotheses.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard heardSomething else { return .heardNothing }
        return confidence >= closeConfidence ? .close : .wrong
    }
}
