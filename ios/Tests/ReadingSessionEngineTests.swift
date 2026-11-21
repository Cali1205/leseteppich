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
}
