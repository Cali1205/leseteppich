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
}
