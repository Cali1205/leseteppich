import XCTest
@testable import Leseteppich

final class ReadingFeedbackTests: XCTestCase {
    func testOldCarpetProgressJSONDecodesWithDefaults() throws {
        let json = """
        { "carpetID": "c1", "completedRuns": 3, "lastReadAt": 700000000 }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CarpetProgress.self, from: json)
        XCTAssertEqual(decoded.carpetID, "c1")
        XCTAssertEqual(decoded.completedRuns, 3)
        XCTAssertNotNil(decoded.lastReadAt)
        XCTAssertNil(decoded.lastRun)
        XCTAssertEqual(decoded.bestStars, 0)
    }

    func testRunResultAndCarpetProgressRoundTrip() throws {
        let run = RunResult(
            date: Date(timeIntervalSinceReferenceDate: 700000000),
            ratings: ["t1": .firstTry, "t2": .afterRetry, "t3": .practiced],
            stars: 2
        )
        let decodedRun = try JSONDecoder().decode(RunResult.self, from: JSONEncoder().encode(run))
        XCTAssertEqual(decodedRun, run)

        let progress = CarpetProgress(carpetID: "c1", completedRuns: 1, lastReadAt: run.date, lastRun: run, bestStars: 2)
        let decodedProgress = try JSONDecoder().decode(CarpetProgress.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(decodedProgress, progress)
    }

    func testRetryReasonClassification() {
        XCTAssertEqual(ReadAloudFlow.retryReason(hypotheses: [], confidence: 0.9), .heardNothing)
        XCTAssertEqual(ReadAloudFlow.retryReason(hypotheses: ["  ", ""], confidence: 0.9), .heardNothing)
        XCTAssertEqual(ReadAloudFlow.retryReason(hypotheses: ["nana"], confidence: ReadAloudFlow.closeConfidence), .close)
        XCTAssertEqual(ReadAloudFlow.retryReason(hypotheses: ["nana"], confidence: 0.49), .wrong)
        XCTAssertEqual(ReadAloudFlow.retryReason(hypotheses: ["nana"], confidence: 0.0), .wrong)
    }

    func testMatcherReportsNearMissConfidenceOnNoMatch() {
        let matcher = PhoneticMatcher()

        let near = matcher.match(hypotheses: ["Banale"], expected: "Banane", strictness: .normal)
        XCTAssertFalse(near.isMatch)
        XCTAssertGreaterThanOrEqual(near.confidence, ReadAloudFlow.closeConfidence)

        let far = matcher.match(hypotheses: ["Tisch"], expected: "Banane", strictness: .normal)
        XCTAssertFalse(far.isMatch)
        XCTAssertLessThan(far.confidence, ReadAloudFlow.closeConfidence)
    }
}
