import Foundation

public struct DiceCellCoordinate: Equatable, Hashable, Sendable {
    public let diceValue: Int
    public let rowIndex: Int

    public init(diceValue: Int, rowIndex: Int) {
        self.diceValue = diceValue
        self.rowIndex = rowIndex
    }
}

/// Pure domain state machine for the 6-column Würfellesen treasure game.
public struct DiceGameEngine: Equatable, Sendable {
    public let board: DiceBoard
    public let twoPlayerMode: Bool
    public private(set) var currentPlayer: DicePlayer
    public private(set) var lastRolledValue: Int?
    public private(set) var activeCoordinate: DiceCellCoordinate?
    /// Maps cell ID -> player who completed it.
    public private(set) var claimedCells: [String: DicePlayer]
    public private(set) var winner: DicePlayer?
    public private(set) var winningColumnDiceValue: Int?

    public init(board: DiceBoard, twoPlayerMode: Bool = false) {
        self.board = board
        self.twoPlayerMode = twoPlayerMode
        self.currentPlayer = .one
        self.lastRolledValue = nil
        self.activeCoordinate = nil
        self.claimedCells = [:]
        self.winner = nil
        self.winningColumnDiceValue = nil
    }

    public var activeCell: DiceCell? {
        guard let coord = activeCoordinate,
              let col = column(for: coord.diceValue),
              col.cells.indices.contains(coord.rowIndex) else {
            return nil
        }
        return col.cells[coord.rowIndex]
    }

    public var availableDiceValues: [Int] {
        board.columns.compactMap { column in
            nextFreeRowIndex(in: column.diceValue) != nil ? column.diceValue : nil
        }
    }

    public func column(for diceValue: Int) -> DiceColumn? {
        board.columns.first(where: { $0.diceValue == diceValue })
    }

    public func nextFreeRowIndex(in diceValue: Int) -> Int? {
        guard let col = column(for: diceValue) else { return nil }
        for (idx, cell) in col.cells.enumerated() {
            if claimedCells[cell.id] == nil {
                return idx
            }
        }
        return nil
    }

    @discardableResult
    public mutating func roll(forcedValue: Int? = nil) -> DiceCellCoordinate? {
        guard winner == nil else { return nil }
        let candidates = availableDiceValues
        guard !candidates.isEmpty else { return nil }

        let chosenDice: Int
        if let forced = forcedValue, candidates.contains(forced) {
            chosenDice = forced
        } else {
            chosenDice = candidates.randomElement() ?? candidates[0]
        }

        lastRolledValue = chosenDice
        if let rowIndex = nextFreeRowIndex(in: chosenDice) {
            let coord = DiceCellCoordinate(diceValue: chosenDice, rowIndex: rowIndex)
            activeCoordinate = coord
            return coord
        }
        return nil
    }

    public mutating func selectNextFreeCell(in diceValue: Int) {
        guard winner == nil, let rowIndex = nextFreeRowIndex(in: diceValue) else { return }
        lastRolledValue = diceValue
        activeCoordinate = DiceCellCoordinate(diceValue: diceValue, rowIndex: rowIndex)
    }

    /// Marks the currently active cell as read by the current player.
    /// Returns true if the treasure chest at the top of the column was reached!
    @discardableResult
    public mutating func completeActiveCell() -> Bool {
        guard winner == nil,
              let coord = activeCoordinate,
              let col = column(for: coord.diceValue),
              col.cells.indices.contains(coord.rowIndex) else {
            return false
        }

        let cell = col.cells[coord.rowIndex]
        claimedCells[cell.id] = currentPlayer
        activeCoordinate = nil

        // Check if this column just reached the top (treasure chest!)
        let columnComplete = col.cells.allSatisfy { claimedCells[$0.id] != nil }
        if columnComplete {
            winner = currentPlayer
            winningColumnDiceValue = coord.diceValue
            return true
        }

        if twoPlayerMode {
            currentPlayer = currentPlayer.next
        }
        return false
    }

    public mutating func reset(twoPlayerMode: Bool? = nil) {
        let mode = twoPlayerMode ?? self.twoPlayerMode
        self = DiceGameEngine(board: board, twoPlayerMode: mode)
    }
}
