import AVFoundation

/// Turns an audio file picked in the Files app into a meeting: copies it into app storage as 5-minute AAC
/// chunks (the same layout as a recording), so it goes through the same transcription pipeline.
/// The user's original file is never modified.
enum AudioImporter {
    enum ImportError: LocalizedError {
        case unreadable
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: "อ่านไฟล์เสียงนี้ไม่ได้ หรือไฟล์ไม่มีเสียง"
            case .exportFailed: "แปลงไฟล์เสียงไม่สำเร็จ"
            }
        }
    }

    /// - Parameter progress: called after each chunk with (done, total).
    static func importFile(
        at url: URL,
        root: URL = RecordingPaths.root,
        chunkDuration: TimeInterval = RecordingDefaults.chunkDuration,
        progress: (Int, Int) -> Void = { _, _ in }
    ) async throws -> RecordingManifest {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: url)
        guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else { throw ImportError.unreadable }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0.5 else { throw ImportError.unreadable }

        let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        var manifest = RecordingManifest(source: .imported, startedAt: created ?? .now, status: .recording)
        manifest.title = url.deletingPathExtension().lastPathComponent
        let planner = ChunkPlanner(recordingID: manifest.id, root: root)
        try planner.createDirectory()

        do {
            let count = Int((duration / chunkDuration).rounded(.up))
            for index in 0..<count {
                let start = Double(index) * chunkDuration
                let length = min(chunkDuration, duration - start)
                guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                    throw ImportError.exportFailed
                }
                export.timeRange = CMTimeRange(
                    start: CMTime(seconds: start, preferredTimescale: 600),
                    duration: CMTime(seconds: length, preferredTimescale: 600)
                )
                try await export.export(to: planner.url(for: index), as: .m4a)
                manifest.chunks.append(.init(index: index, fileName: ChunkPlanner.fileName(for: index), duration: length))
                progress(index + 1, count)
            }
        } catch {
            // Only our partial copy is removed; the user's file is untouched.
            try? FileManager.default.removeItem(at: planner.directory)
            throw error
        }

        manifest.status = .finished
        try manifest.write(to: planner.directory)
        return manifest
    }
}
