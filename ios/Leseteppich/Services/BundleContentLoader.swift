import Foundation

public enum ContentLoaderError: LocalizedError {
    case resourceNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .resourceNotFound(let name):
            return "Lerninhalt '\(name)' konnte nicht im App-Bundle gefunden werden."
        }
    }
}

public final class BundleContentLoader: ContentLoading, @unchecked Sendable {
    private let bundle: Bundle

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    public func loadBuiltInCarpets() throws -> [Carpet] {
        let data = try loadJSONData(named: "leseteppiche")
        let pack = try JSONDecoder().decode(CarpetPack.self, from: data)
        return pack.carpets.sorted(by: { $0.order < $1.order })
    }

    public func loadBuiltInDiceBoards() throws -> [DiceBoard] {
        let data = try loadJSONData(named: "wuerfellesen")
        let pack = try JSONDecoder().decode(DiceBoardPack.self, from: data)
        return pack.boards
    }

    private func loadJSONData(named resourceName: String) throws -> Data {
        if let url = bundle.url(forResource: resourceName, withExtension: "json") {
            return try Data(contentsOf: url)
        }
        throw ContentLoaderError.resourceNotFound("\(resourceName).json")
    }
}
