import Foundation

@MainActor
public final class LocalProgressStore: ProgressStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directoryURL: URL? = nil) {
        let baseDir = directoryURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = baseDir.appendingPathComponent("leseteppich_state.json")

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func load() -> PersistedAppData {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode(PersistedAppData.self, from: data) else {
            return PersistedAppData()
        }
        return decoded
    }

    public func save(_ data: PersistedAppData) {
        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal persistence warning; keep app responsive for the child.
            print("LocalProgressStore save error: \(error)")
        }
    }
}
