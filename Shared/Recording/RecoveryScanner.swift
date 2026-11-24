import Foundation

/// Finds recordings left in `.recording` state (app killed, crash, restart) and closes them as `.interrupted`.
nonisolated enum RecoveryScanner {
    /// - Parameter durationOf: playable duration of a chunk file; 0 when the file cannot be read
    ///   (an AAC file cut off mid-write usually has no index and is unreadable).
    /// - Parameter source: only recover recordings made on this device. On iPhone, Watch recordings that are
    ///   still arriving also say `.recording` and must not be closed.
    /// - Returns: the manifests that were recovered and rewritten.
    static func recover(
        root: URL,
        source: RecordingManifest.Source? = nil,
        durationOf: (URL) -> TimeInterval
    ) throws -> [RecordingManifest] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path(percentEncoded: false)) else { return [] }

        var recovered: [RecordingManifest] = []
        for directory in try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            guard var manifest = try? RecordingManifest.read(from: directory),
                  manifest.status == .recording,
                  source == nil || manifest.source == source else { continue }

            let known = Set(manifest.chunks.map(\.fileName))
            let unlisted = try fileManager.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
                .compactMap { name in ChunkPlanner.index(of: name).map { (index: $0, name: name) } }
                .filter { !known.contains($0.name) }
                .sorted { $0.index < $1.index }

            for file in unlisted {
                let duration = durationOf(directory.appending(path: file.name))
                // Unreadable files stay on disk untouched; they are never deleted silently.
                guard duration > 0 else { continue }
                manifest.chunks.append(.init(index: file.index, fileName: file.name, duration: duration))
            }

            manifest.status = .interrupted
            try manifest.write(to: directory)
            recovered.append(manifest)
        }
        return recovered
    }
}
