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

    func testSelectNextFreeCellAdvancesWithinColumnAndIgnoresInvalidDiceValue() {
        var engine = DiceGameEngine(board: makeSampleBoard(), twoPlayerMode: false)

        engine.selectNextFreeCell(in: 4)
        XCTAssertEqual(engine.lastRolledValue, 4)
        XCTAssertEqual(engine.activeCoordinate, DiceCellCoordinate(diceValue: 4, rowIndex: 0))
        XCTAssertEqual(engine.activeCell?.id, "d4_r0")

        XCTAssertFalse(engine.completeActiveCell())

        engine.selectNextFreeCell(in: 4)
        XCTAssertEqual(engine.activeCoordinate, DiceCellCoordinate(diceValue: 4, rowIndex: 1))
        XCTAssertEqual(engine.activeCell?.id, "d4_r1")

        engine.selectNextFreeCell(in: 99)
        XCTAssertEqual(engine.activeCoordinate, DiceCellCoordinate(diceValue: 4, rowIndex: 1))
    }

    func testAvailableDiceValuesExcludesFullColumnAndNoMovesAllowedAfterWin() {
        var engine = DiceGameEngine(board: makeSampleBoard(), twoPlayerMode: false)
        XCTAssertEqual(engine.availableDiceValues, [1, 2, 3, 4, 5, 6])

        engine.selectNextFreeCell(in: 2)
        XCTAssertFalse(engine.completeActiveCell())
        engine.selectNextFreeCell(in: 2)
        XCTAssertTrue(engine.completeActiveCell())

        XCTAssertEqual(engine.winner, .one)
        XCTAssertEqual(engine.availableDiceValues, [1, 3, 4, 5, 6])

        // No further moves after win
        XCTAssertNil(engine.roll(forcedValue: 1))
        XCTAssertNil(engine.activeCoordinate)
        engine.selectNextFreeCell(in: 1)
        XCTAssertNil(engine.activeCoordinate)
        XCTAssertFalse(engine.completeActiveCell())
    }
}
