import XCTest
@testable import Leseteppich

final class ReadingSessionEngineTests: XCTestCase {
    private func makeSampleCarpet() -> Carpet {
        Carpet(
            id: "sample",
            order: 1,
            title: "Testteppich",
            focusLetters: ["N", "I", "A"],
            motifEmoji: "🐜",
            motifName: "Ameise",
            tiles: [
                ReadingTile(id: "t1", display: "na", syllables: ["na"], spokenText: "na"),
                ReadingTile(id: "t2", display: "ni", syllables: ["ni"], spokenText: "ni"),
                ReadingTile(id: "t3", display: "Nina", syllables: ["Ni", "na"], spokenText: "Nina"),
                ReadingTile(id: "t4", display: "Ina", syllables: ["I", "na"], spokenText: "Ina")
            ]
        )
    }

    func testGuidedProgressionCompletesCarpet() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        XCTAssertEqual(engine.activeIndex, 0)
        XCTAssertFalse(engine.isCompleted)

        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertEqual(engine.activeIndex, 1)

        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertEqual(engine.activeIndex, 2)

        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertEqual(engine.activeIndex, 3)

        XCTAssertTrue(engine.markCurrentTileCompleted())
        XCTAssertTrue(engine.isCompleted)
        XCTAssertEqual(engine.progressFraction, 1.0, accuracy: 0.001)
    }

    func testOutOfOrderSelectionWrapsToRemainingTile() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        engine.selectTile(at: 2)
        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertEqual(engine.activeIndex, 3)

        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertEqual(engine.activeIndex, 0)
    }

    func testFailedAttemptsCountAndResetOnCompletionSelectionAndReset() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 0)

        engine.recordFailedAttempt()
        engine.recordFailedAttempt()
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 2)

        engine.markCurrentTileCompleted()
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 0)

        engine.recordFailedAttempt()
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 1)

        engine.selectTile(at: 3)
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 0)

        engine.recordFailedAttempt()
        engine.reset()
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 0)
        XCTAssertEqual(engine.activeIndex, 0)
        XCTAssertTrue(engine.completedTileIDs.isEmpty)
    }

    func testOutOfBoundsSelectTileIsIgnored() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        engine.recordFailedAttempt()

        engine.selectTile(at: -1)
        XCTAssertEqual(engine.activeIndex, 0)
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 1)

        engine.selectTile(at: 99)
        XCTAssertEqual(engine.activeIndex, 0)
        XCTAssertEqual(engine.failedAttemptsOnCurrentTile, 1)
    }

    func testRatingsRecordFirstTryAfterRetryAndPracticed() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())

        engine.markCurrentTileCompleted()
        engine.recordFailedAttempt()
        engine.markCurrentTileCompleted()
        engine.recordFailedAttempt()
        engine.recordFailedAttempt()
        engine.markCurrentTileCompleted(rating: .practiced)
        // A manual confirm with zero failed attempts still counts as read on the first try.
        engine.markCurrentTileCompleted(rating: nil)

        XCTAssertEqual(engine.ratings, ["t1": .firstTry, "t2": .afterRetry, "t3": .practiced, "t4": .firstTry])
        XCTAssertTrue(engine.isCompleted)

        engine.reset()
        XCTAssertTrue(engine.ratings.isEmpty)
    }

    func testCompletingAgainReportsCarpetCompletionOnlyOnce() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        for _ in 0..<3 { XCTAssertFalse(engine.markCurrentTileCompleted()) }
        XCTAssertTrue(engine.markCurrentTileCompleted())
        // The last tile stays active; a second confirm must not report the run finished again.
        XCTAssertFalse(engine.markCurrentTileCompleted())
        XCTAssertFalse(engine.markCurrentTileCompleted(rating: .practiced))
        XCTAssertTrue(engine.isCompleted)
    }

    func testRatingIsKeptFromFirstCompletionInRun() {
        var engine = ReadingSessionEngine(carpet: makeSampleCarpet())
        engine.markCurrentTileCompleted(autoAdvance: false)
        engine.recordFailedAttempt()
        engine.markCurrentTileCompleted(autoAdvance: false)
        engine.markCurrentTileCompleted(autoAdvance: false, rating: .practiced)
        XCTAssertEqual(engine.ratings, ["t1": .firstTry])

        engine.reset()
        engine.markCurrentTileCompleted(autoAdvance: false, rating: .practiced)
        XCTAssertEqual(engine.ratings, ["t1": .practiced])
    }

    func testStarsThresholds() {
        typealias E = ReadingSessionEngine
        XCTAssertEqual(E.stars(for: []), 1)
        XCTAssertEqual(E.stars(for: [.firstTry, .firstTry]), 3)
        // Exactly 80 % first try → 3.
        XCTAssertEqual(E.stars(for: [.firstTry, .firstTry, .firstTry, .firstTry, .practiced]), 3)
        // 75 % first try, but everything read → 2.
        XCTAssertEqual(E.stars(for: [.firstTry, .firstTry, .firstTry, .afterRetry]), 2)
        // Exactly 60 % read (first try + after retry) → 2.
        XCTAssertEqual(E.stars(for: [.firstTry, .afterRetry, .afterRetry, .practiced, .practiced]), 2)
        // 40 % read → 1, never 0.
        XCTAssertEqual(E.stars(for: [.firstTry, .afterRetry, .practiced, .practiced, .practiced]), 1)
        XCTAssertEqual(E.stars(for: [.practiced, .practiced]), 1)
    }
}
