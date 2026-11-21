import Foundation

public enum ReadingMode: String, CaseIterable, Identifiable, Sendable {
    case read
    case learn

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .read: return "Vorlesen"
        case .learn: return "Anhören"
        }
    }
}

/// Pure domain state machine for working through a 4x4 Leseteppich.
public struct ReadingSessionEngine: Equatable, Sendable {
    public let carpet: Carpet
    public private(set) var activeIndex: Int
    public private(set) var completedTileIDs: Set<String>
    public private(set) var failedAttemptsOnCurrentTile: Int

    public init(carpet: Carpet) {
        self.carpet = carpet
        self.activeIndex = 0
        self.completedTileIDs = []
        self.failedAttemptsOnCurrentTile = 0
    }

    public var activeTile: ReadingTile? {
        guard carpet.tiles.indices.contains(activeIndex) else { return nil }
        return carpet.tiles[activeIndex]
    }

    public var isCompleted: Bool {
        !carpet.tiles.isEmpty && completedTileIDs.count >= carpet.tiles.count
    }

    public var progressFraction: Double {
        guard !carpet.tiles.isEmpty else { return 0 }
        return Double(completedTileIDs.count) / Double(carpet.tiles.count)
    }

    public mutating func selectTile(at index: Int) {
        guard carpet.tiles.indices.contains(index) else { return }
        activeIndex = index
        failedAttemptsOnCurrentTile = 0
    }

    @discardableResult
    public mutating func markCurrentTileCompleted(autoAdvance: Bool = true) -> Bool {
        guard let tile = activeTile else { return false }
        completedTileIDs.insert(tile.id)
        failedAttemptsOnCurrentTile = 0

        if autoAdvance {
            advanceToNextIncompleteTile()
        }
        return isCompleted
    }

    public mutating func recordFailedAttempt() {
        failedAttemptsOnCurrentTile += 1
    }

    public mutating func reset() {
        activeIndex = 0
        completedTileIDs = []
        failedAttemptsOnCurrentTile = 0
    }

    private mutating func advanceToNextIncompleteTile() {
        let count = carpet.tiles.count
        guard count > 0 else { return }

        // Prefer next incomplete tile after current index, wrapping around
        for offset in 1...count {
            let candidate = (activeIndex + offset) % count
            if !completedTileIDs.contains(carpet.tiles[candidate].id) {
                activeIndex = candidate
                return
            }
        }
    }
}
