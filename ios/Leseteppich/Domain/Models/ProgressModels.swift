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

public struct CarpetProgress: Codable, Equatable, Sendable {
    public let carpetID: String
    public var completedRuns: Int
    public var lastReadAt: Date?

    public init(carpetID: String, completedRuns: Int = 0, lastReadAt: Date? = nil) {
        self.carpetID = carpetID
        self.completedRuns = completedRuns
        self.lastReadAt = lastReadAt
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var showSyllableColors: Bool
    public var showSyllableArcs: Bool
    public var speechRate: Double
    public var strictness: MatchingStrictness
    public var allowManualConfirm: Bool
    public var preferOnDeviceRecognition: Bool
    public var autoAdvanceOnMatch: Bool

    public init(
        showSyllableColors: Bool = true,
        showSyllableArcs: Bool = true,
        speechRate: Double = 0.42,
        strictness: MatchingStrictness = .gentle,
        allowManualConfirm: Bool = true,
        preferOnDeviceRecognition: Bool = true,
        autoAdvanceOnMatch: Bool = true
    ) {
        self.showSyllableColors = showSyllableColors
        self.showSyllableArcs = showSyllableArcs
        self.speechRate = speechRate
        self.strictness = strictness
        self.allowManualConfirm = allowManualConfirm
        self.preferOnDeviceRecognition = preferOnDeviceRecognition
        self.autoAdvanceOnMatch = autoAdvanceOnMatch
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
