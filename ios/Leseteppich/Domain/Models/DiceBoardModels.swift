import Foundation

public struct DiceBoardPack: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let language: String
    public let boards: [DiceBoard]

    public init(schemaVersion: Int = 1, language: String = "de-DE", boards: [DiceBoard]) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.boards = boards
    }
}

public struct DiceBoard: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let goalEmoji: String
    public let goalTitle: String
    public let columns: [DiceColumn]

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        goalEmoji: String = "🏆",
        goalTitle: String = "Schatz",
        columns: [DiceColumn]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.goalEmoji = goalEmoji
        self.goalTitle = goalTitle
        self.columns = columns
    }

    public var rowCount: Int {
        columns.first?.cells.count ?? 0
    }
}

public struct DiceColumn: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: Int { diceValue }
    public let diceValue: Int
    /// Ordered from bottom (row 0, easiest) to top (last row, closest to treasure).
    public let cells: [DiceCell]

    public init(diceValue: Int, cells: [DiceCell]) {
        self.diceValue = diceValue
        self.cells = cells
    }
}

public struct DiceCell: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let display: String
    public let syllables: [String]
    public let spokenText: String
    public let rebusSegments: [RebusSegment]?
    public let acceptedTranscriptions: [String]

    enum CodingKeys: String, CodingKey {
        case id, display, syllables, spokenText, rebusSegments, acceptedTranscriptions
    }

    public init(
        id: String,
        display: String,
        syllables: [String],
        spokenText: String,
        rebusSegments: [RebusSegment]? = nil,
        acceptedTranscriptions: [String] = []
    ) {
        self.id = id
        self.display = display
        self.syllables = syllables
        self.spokenText = spokenText
        self.rebusSegments = rebusSegments
        self.acceptedTranscriptions = acceptedTranscriptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        display = try container.decode(String.self, forKey: .display)
        syllables = try container.decode([String].self, forKey: .syllables)
        spokenText = try container.decode(String.self, forKey: .spokenText)
        rebusSegments = try container.decodeIfPresent([RebusSegment].self, forKey: .rebusSegments)
        acceptedTranscriptions = try container.decodeIfPresent([String].self, forKey: .acceptedTranscriptions) ?? []
    }

    public var asReadingTile: ReadingTile {
        ReadingTile(
            id: id,
            display: display,
            syllables: syllables,
            spokenText: spokenText,
            ipa: nil,
            isSinglePhoneme: display.count == 1,
            acceptedTranscriptions: acceptedTranscriptions
        )
    }
}

public enum DicePlayer: Int, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case one = 1
    case two = 2

    public var displayName: String {
        switch self {
        case .one: return "Kind"
        case .two: return "Mitspieler"
        }
    }

    public var next: DicePlayer {
        self == .one ? .two : .one
    }
}
