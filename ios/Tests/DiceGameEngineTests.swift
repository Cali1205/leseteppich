import XCTest
@testable import Leseteppich

final class DiceGameEngineTests: XCTestCase {
    private func makeSampleBoard() -> DiceBoard {
        let columns = (1...6).map { dice in
            DiceColumn(
                diceValue: dice,
                cells: [
                    DiceCell(id: "d\(dice)_r0", display: "ma", syllables: ["ma"], spokenText: "ma"),
                    DiceCell(id: "d\(dice)_r1", display: "Mama", syllables: ["Ma", "ma"], spokenText: "Mama")
                ]
            )
        }
        return DiceBoard(id: "test_board", title: "Test", columns: columns)
    }

    func testSinglePlayerReachesTreasure() {
        var engine = DiceGameEngine(board: makeSampleBoard(), twoPlayerMode: false)

        let first = engine.roll(forcedValue: 3)
        XCTAssertEqual(first, DiceCellCoordinate(diceValue: 3, rowIndex: 0))
        XCTAssertFalse(engine.completeActiveCell())
        XCTAssertNil(engine.winner)

        let second = engine.roll(forcedValue: 3)
        XCTAssertEqual(second, DiceCellCoordinate(diceValue: 3, rowIndex: 1))
        XCTAssertTrue(engine.completeActiveCell())
        XCTAssertEqual(engine.winner, .one)
        XCTAssertEqual(engine.winningColumnDiceValue, 3)
    }

    func testTwoPlayerAlternatesTurns() {
        var engine = DiceGameEngine(board: makeSampleBoard(), twoPlayerMode: true)
        XCTAssertEqual(engine.currentPlayer, .one)

        engine.roll(forcedValue: 1)
        XCTAssertFalse(engine.completeActiveCell())
        XCTAssertEqual(engine.currentPlayer, .two)

        engine.roll(forcedValue: 1)
        XCTAssertTrue(engine.completeActiveCell())
        XCTAssertEqual(engine.winner, .two)
    }
}
