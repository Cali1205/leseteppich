import Foundation

public struct CarpetPack: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let language: String
    public let carpets: [Carpet]

    public init(schemaVersion: Int = 1, language: String = "de-DE", carpets: [Carpet]) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.carpets = carpets
    }
}

public struct Carpet: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let order: Int
    public let title: String
    public let subtitle: String?
    public let focusLetters: [String]
    public let motifEmoji: String
    public let motifName: String
    public let accentHex: String
    public let targetRepetitions: Int
    public let columns: Int
    public let tiles: [ReadingTile]
    public let isCustom: Bool

    enum CodingKeys: String, CodingKey {
        case id, order, title, subtitle, focusLetters, motifEmoji, motifName, accentHex, targetRepetitions, columns, tiles, isCustom
    }

    public init(
        id: String,
        order: Int,
        title: String,
        subtitle: String? = nil,
        focusLetters: [String],
        motifEmoji: String,
        motifName: String,
        accentHex: String = "#267DE0",
        targetRepetitions: Int = 5,
        columns: Int = 4,
        tiles: [ReadingTile],
        isCustom: Bool = false
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.subtitle = subtitle
        self.focusLetters = focusLetters
        self.motifEmoji = motifEmoji
        self.motifName = motifName
        self.accentHex = accentHex
        self.targetRepetitions = targetRepetitions
        self.columns = columns
        self.tiles = tiles
        self.isCustom = isCustom
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        order = try container.decode(Int.self, forKey: .order)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        focusLetters = try container.decode([String].self, forKey: .focusLetters)
        motifEmoji = try container.decode(String.self, forKey: .motifEmoji)
        motifName = try container.decode(String.self, forKey: .motifName)
        accentHex = try container.decode(String.self, forKey: .accentHex)
        targetRepetitions = try container.decode(Int.self, forKey: .targetRepetitions)
        columns = try container.decode(Int.self, forKey: .columns)
        tiles = try container.decode([ReadingTile].self, forKey: .tiles)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
    }
}

public struct ReadingTile: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let display: String
    public let syllables: [String]
    public let spokenText: String
    public let ipa: String?
    public let isSinglePhoneme: Bool
    public let acceptedTranscriptions: [String]

    enum CodingKeys: String, CodingKey {
        case id, display, syllables, spokenText, ipa, isSinglePhoneme, acceptedTranscriptions
    }

    public init(
        id: String,
        display: String,
        syllables: [String],
        spokenText: String,
        ipa: String? = nil,
        isSinglePhoneme: Bool = false,
        acceptedTranscriptions: [String] = []
    ) {
        self.id = id
        self.display = display
        self.syllables = syllables
        self.spokenText = spokenText
        self.ipa = ipa
        self.isSinglePhoneme = isSinglePhoneme
        self.acceptedTranscriptions = acceptedTranscriptions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        display = try container.decode(String.self, forKey: .display)
        syllables = try container.decode([String].self, forKey: .syllables)
        spokenText = try container.decode(String.self, forKey: .spokenText)
        ipa = try container.decodeIfPresent(String.self, forKey: .ipa)
        isSinglePhoneme = try container.decodeIfPresent(Bool.self, forKey: .isSinglePhoneme) ?? false
        acceptedTranscriptions = try container.decodeIfPresent([String].self, forKey: .acceptedTranscriptions) ?? []
    }
}

public struct RebusSegment: Codable, Equatable, Hashable, Sendable {
    public let text: String?
    public let emoji: String?
    public let spokenWord: String?

    public init(text: String? = nil, emoji: String? = nil, spokenWord: String? = nil) {
        self.text = text
        self.emoji = emoji
        self.spokenWord = spokenWord
    }
}
