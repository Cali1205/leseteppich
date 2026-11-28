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
    /// Rating of each completed tile in the current run, keyed by tile id.
    public private(set) var ratings: [String: TileRating]

    public init(carpet: Carpet) {
        self.carpet = carpet
        self.activeIndex = 0
        self.completedTileIDs = []
        self.failedAttemptsOnCurrentTile = 0
        self.ratings = [:]
    }

    /// 3 stars if ≥ 80 % were read on the first try, 2 if ≥ 60 % were read without skipping, else 1.
    /// Never below 1: finishing a carpet always earns a star.
    public static func stars(for ratings: [TileRating]) -> Int {
        guard !ratings.isEmpty else { return 1 }
        let total = ratings.count
        let firstTry = ratings.filter { $0 == .firstTry }.count
        let read = ratings.filter { $0 != .practiced }.count
        // Integer cross-multiplication keeps the exact 80 % / 60 % boundaries free of float rounding.
        if firstTry * 5 >= total * 4 { return 3 }
        if read * 5 >= total * 3 { return 2 }
        return 1
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

    /// `rating` nil derives it from the failed attempts: `.firstTry` without any, else `.afterRetry`.
    @discardableResult
    public mutating func markCurrentTileCompleted(autoAdvance: Bool = true, rating: TileRating? = nil) -> Bool {
        guard let tile = activeTile else { return false }
        completedTileIDs.insert(tile.id)
        ratings[tile.id] = rating ?? (failedAttemptsOnCurrentTile == 0 ? .firstTry : .afterRetry)
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
        ratings = [:]
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
