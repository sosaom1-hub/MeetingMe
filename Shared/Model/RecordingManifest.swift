import Foundation

/// Describes one recording's chunk files. Stored as `manifest.json` inside the recording's directory
/// and sent alongside each chunk during Watch → iPhone transfer.
nonisolated struct RecordingManifest: Codable, Hashable, Sendable, Identifiable {
    enum Source: String, Codable, Sendable { case watch, phone }
    enum Status: String, Codable, Sendable { case recording, finished, interrupted }

    struct Chunk: Codable, Hashable, Sendable {
        var index: Int
        var fileName: String
        var duration: TimeInterval
    }

    static let fileName = "manifest.json"

    let id: UUID
    let source: Source
    let startedAt: Date
    var status: Status
    var chunks: [Chunk]

    init(id: UUID = UUID(), source: Source, startedAt: Date = .now, status: Status = .recording, chunks: [Chunk] = []) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
        self.status = status
        self.chunks = chunks
    }

    var totalDuration: TimeInterval {
        chunks.reduce(0) { $0 + $1.duration }
    }

    func write(to directory: URL) throws {
        let data = try Self.encoder.encode(self)
        try data.write(to: directory.appending(path: Self.fileName), options: .atomic)
    }

    static func read(from directory: URL) throws -> RecordingManifest {
        let data = try Data(contentsOf: directory.appending(path: fileName))
        return try decoder.decode(RecordingManifest.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
