import Foundation

/// Describes one recording's chunk files. Stored as `manifest.json` inside the recording's directory
/// and sent alongside each chunk during Watch → iPhone transfer.
nonisolated struct RecordingManifest: Codable, Hashable, Sendable, Identifiable {
    /// Where the audio came from. `imported` is a file picked in the Files app (v3 Task 25).
    enum Source: String, Codable, Sendable { case watch, phone, imported }
    enum Status: String, Codable, Sendable { case recording, finished, interrupted }

    struct Chunk: Codable, Hashable, Sendable {
        var index: Int
        var fileName: String
        var duration: TimeInterval
    }

    /// A note typed during recording, at `time` seconds from the start.
    struct TimedNote: Codable, Hashable, Sendable {
        var time: TimeInterval
        var text: String
    }

    static let fileName = "manifest.json"

    let id: UUID
    let source: Source
    let startedAt: Date
    var status: Status
    var chunks: [Chunk]
    /// ⭐ "จุดสำคัญ" markers, in seconds from the start of the recording.
    var markers: [TimeInterval]
    /// Optional so manifests written before notes existed still decode.
    var notes: [TimedNote]?
    /// Set on the Watch after stopping (quick title); nil keeps the iPhone's default title.
    var title: String?
    /// `RecordingType.rawValue`, set after stopping; nil means not chosen.
    var recordingType: String?

    init(
        id: UUID = UUID(),
        source: Source,
        startedAt: Date = .now,
        status: Status = .recording,
        chunks: [Chunk] = [],
        markers: [TimeInterval] = []
    ) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
        self.status = status
        self.chunks = chunks
        self.markers = markers
    }

    var totalDuration: TimeInterval {
        chunks.reduce(0) { $0 + $1.duration }
    }

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> RecordingManifest {
        try decoder.decode(RecordingManifest.self, from: data)
    }

    func write(to directory: URL) throws {
        try encoded().write(to: directory.appending(path: Self.fileName), options: .atomic)
    }

    static func read(from directory: URL) throws -> RecordingManifest {
        try decode(Data(contentsOf: directory.appending(path: fileName)))
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
