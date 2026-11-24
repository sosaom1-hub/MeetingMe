import Foundation

/// File layout for recordings: `<root>/<recording id>/chunk-000.m4a`, `chunk-001.m4a`, … plus `manifest.json`.
nonisolated struct ChunkPlanner: Sendable {
    let directory: URL

    init(recordingID: UUID, root: URL) {
        directory = root.appending(path: recordingID.uuidString, directoryHint: .isDirectory)
    }

    static func fileName(for index: Int) -> String {
        "chunk-" + String(format: "%03d", index) + ".m4a"
    }

    /// Parses `chunk-007.m4a` back to 7. Returns nil for any other file name.
    static func index(of fileName: String) -> Int? {
        guard fileName.hasPrefix("chunk-"), fileName.hasSuffix(".m4a") else { return nil }
        return Int(fileName.dropFirst("chunk-".count).dropLast(".m4a".count))
    }

    func url(for index: Int) -> URL {
        directory.appending(path: Self.fileName(for: index))
    }

    func createDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
