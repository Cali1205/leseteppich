import Foundation

public enum MatchingStrictness: String, Codable, CaseIterable, Identifiable, Sendable {
    case gentle
    case normal
    case strict

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .gentle: return "Sanft (Anfänger)"
        case .normal: return "Normal"
        case .strict: return "Genau"
        }
    }

    public var description: String {
        switch self {
        case .gentle:
            return "Erlaubt kleine Laut-Abweichungen (z. B. t/d) – ideal für den Start."
        case .normal:
            return "Ausgewogene Erkennung mit deutscher Phonetik-Toleranz."
        case .strict:
            return "Erfordert sehr genaue Aussprache ohne weiche Laut-Ersetzung."
        }
    }
}

public enum TileRating: String, Codable, Sendable {
    case firstTry
    case afterRetry
    /// Skipped after needing help: the tile was practised, not read.
    case practiced
}

public struct RunResult: Codable, Equatable, Sendable {
    public var date: Date
    /// Keyed by tile id.
    public var ratings: [String: TileRating]
    public var stars: Int

    public init(date: Date, ratings: [String: TileRating], stars: Int) {
        self.date = date
        self.ratings = ratings
        self.stars = stars
    }
}

public struct CarpetProgress: Codable, Equatable, Sendable {
    public let carpetID: String
    public var completedRuns: Int
    public var lastReadAt: Date?
    public var lastRun: RunResult?
    public var bestStars: Int

    public init(
        carpetID: String,
        completedRuns: Int = 0,
        lastReadAt: Date? = nil,
        lastRun: RunResult? = nil,
        bestStars: Int = 0
    ) {
        self.carpetID = carpetID
        self.completedRuns = completedRuns
        self.lastReadAt = lastReadAt
        self.lastRun = lastRun
        self.bestStars = bestStars
    }

    enum CodingKeys: String, CodingKey {
        case carpetID, completedRuns, lastReadAt, lastRun, bestStars
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        carpetID = try container.decode(String.self, forKey: .carpetID)
        completedRuns = try container.decodeIfPresent(Int.self, forKey: .completedRuns) ?? 0
        lastReadAt = try container.decodeIfPresent(Date.self, forKey: .lastReadAt)
        lastRun = try container.decodeIfPresent(RunResult.self, forKey: .lastRun)
        bestStars = try container.decodeIfPresent(Int.self, forKey: .bestStars) ?? 0
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let currentSettingsVersion = 2

    public var settingsVersion: Int
    public var showSyllableColors: Bool
    public var showSyllableArcs: Bool
    public var speechRate: Double
    public var strictness: MatchingStrictness
    public var allowManualConfirm: Bool
    public var preferOnDeviceRecognition: Bool
    public var autoAdvanceOnMatch: Bool
    /// When false (default), the "Anhören" / TTS audio-help controls are hidden from the child.
    public var allowAudioHelp: Bool
    /// When true (default), after a recognized sound/word the app automatically listens for the next tile.
    public var autoListenNextTile: Bool
    /// Optional identifier of the user-selected German AVSpeechSynthesisVoice.
    public var selectedVoiceIdentifier: String?
    /// Short chimes for "your turn", success and "try again".
    public var feedbackSounds: Bool

    enum CodingKeys: String, CodingKey {
        case settingsVersion
        case showSyllableColors
        case showSyllableArcs
        case speechRate
        case strictness
        case allowManualConfirm
        case preferOnDeviceRecognition
        case autoAdvanceOnMatch
        case allowAudioHelp
        case autoListenNextTile
        case selectedVoiceIdentifier
        case feedbackSounds
    }

    public init(
        settingsVersion: Int = AppSettings.currentSettingsVersion,
        showSyllableColors: Bool = true,
        showSyllableArcs: Bool = true,
        speechRate: Double = 0.48,
        strictness: MatchingStrictness = .gentle,
        allowManualConfirm: Bool = false,
        preferOnDeviceRecognition: Bool = true,
        autoAdvanceOnMatch: Bool = true,
        allowAudioHelp: Bool = false,
        autoListenNextTile: Bool = true,
        selectedVoiceIdentifier: String? = nil,
        feedbackSounds: Bool = true
    ) {
        self.settingsVersion = settingsVersion
        self.showSyllableColors = showSyllableColors
        self.showSyllableArcs = showSyllableArcs
        self.speechRate = speechRate
        self.strictness = strictness
        self.allowManualConfirm = allowManualConfirm
        self.preferOnDeviceRecognition = preferOnDeviceRecognition
        self.autoAdvanceOnMatch = autoAdvanceOnMatch
        self.allowAudioHelp = allowAudioHelp
        self.autoListenNextTile = autoListenNextTile
        self.selectedVoiceIdentifier = selectedVoiceIdentifier
        self.feedbackSounds = feedbackSounds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .settingsVersion) ?? 1
        showSyllableColors = try container.decodeIfPresent(Bool.self, forKey: .showSyllableColors) ?? true
        showSyllableArcs = try container.decodeIfPresent(Bool.self, forKey: .showSyllableArcs) ?? true
        speechRate = try container.decodeIfPresent(Double.self, forKey: .speechRate) ?? 0.48
        strictness = try container.decodeIfPresent(MatchingStrictness.self, forKey: .strictness) ?? .gentle
        preferOnDeviceRecognition = try container.decodeIfPresent(Bool.self, forKey: .preferOnDeviceRecognition) ?? true
        autoAdvanceOnMatch = try container.decodeIfPresent(Bool.self, forKey: .autoAdvanceOnMatch) ?? true
        allowAudioHelp = try container.decodeIfPresent(Bool.self, forKey: .allowAudioHelp) ?? false
        autoListenNextTile = try container.decodeIfPresent(Bool.self, forKey: .autoListenNextTile) ?? true
        selectedVoiceIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedVoiceIdentifier)
        feedbackSounds = try container.decodeIfPresent(Bool.self, forKey: .feedbackSounds) ?? true

        if decodedVersion < Self.currentSettingsVersion {
            allowManualConfirm = false
            settingsVersion = Self.currentSettingsVersion
        } else {
            allowManualConfirm = try container.decodeIfPresent(Bool.self, forKey: .allowManualConfirm) ?? false
            settingsVersion = decodedVersion
        }
    }
}

public struct PersistedAppData: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var progressByCarpetID: [String: CarpetProgress]
    public var settings: AppSettings
    public var customCarpets: [Carpet]
    public var diceWinsCount: Int

    public init(
        schemaVersion: Int = 1,
        progressByCarpetID: [String: CarpetProgress] = [:],
        settings: AppSettings = AppSettings(),
        customCarpets: [Carpet] = [],
        diceWinsCount: Int = 0
    ) {
        self.schemaVersion = schemaVersion
        self.progressByCarpetID = progressByCarpetID
        self.settings = settings
        self.customCarpets = customCarpets
        self.diceWinsCount = diceWinsCount
    }
}
