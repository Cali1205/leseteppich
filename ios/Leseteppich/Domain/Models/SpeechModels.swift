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

public enum SpeechRecognitionStatus: Equatable, Sendable {
    case idle
    case listening
    case preparingNext
    case matched(transcript: String)
    case retryNeeded(heard: String?)
    case unavailable(message: String)
}
