import Foundation
import Testing
@testable import MeetingRecorder

struct AudioImporterTests {
    private let fixture = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/thai-sample.m4a")

    @Test func importSplitsIntoChunksWithoutTouchingTheOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "AudioImporterTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let originalSize = try fixture.resourceValues(forKeys: [.fileSizeKey]).fileSize
        var updates: [Int] = []

        // 14 s file with 5 s chunks → 3 chunks (5 + 5 + ~4 s).
        let manifest = try await AudioImporter.importFile(at: fixture, root: root, chunkDuration: 5) { done, _ in
            updates.append(done)
        }

        #expect(manifest.source == .imported)
        #expect(manifest.status == .finished)
        #expect(manifest.title == "thai-sample")
        #expect(manifest.chunks.map(\.index) == [0, 1, 2])
        #expect(abs(manifest.totalDuration - 13.94) < 0.2)
        #expect(updates == [1, 2, 3])
        let directory = ChunkPlanner(recordingID: manifest.id, root: root).directory
        for chunk in manifest.chunks {
            #expect(RecordingPaths.duration(of: directory.appending(path: chunk.fileName)) > 3)
        }
        // Saved manifest (dates are stored in whole seconds, so compare the fields that matter).
        let saved = try RecordingManifest.read(from: directory)
        #expect(saved.id == manifest.id)
        #expect(saved.chunks == manifest.chunks)
        #expect(saved.status == .finished)
        #expect(saved.title == "thai-sample")
        #expect(try fixture.resourceValues(forKeys: [.fileSizeKey]).fileSize == originalSize)
    }

    @Test func rejectsFilesWithoutAudio() async throws {
        let notAudio = FileManager.default.temporaryDirectory.appending(path: "not-audio-\(UUID().uuidString).m4a")
        try Data("hello".utf8).write(to: notAudio)
        defer { try? FileManager.default.removeItem(at: notAudio) }

        await #expect(throws: (any Error).self) {
            _ = try await AudioImporter.importFile(at: notAudio, root: FileManager.default.temporaryDirectory)
        }
    }
}
