import Foundation
import Testing
@testable import MeetingRecorder

struct ChunkLogicTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ChunkLogicTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    @Test func chunkFileNamesRoundTrip() {
        #expect(ChunkPlanner.fileName(for: 7) == "chunk-007.m4a")
        #expect(ChunkPlanner.index(of: "chunk-007.m4a") == 7)
        #expect(ChunkPlanner.index(of: "manifest.json") == nil)
        #expect(ChunkPlanner.index(of: "chunk-abc.m4a") == nil)
    }

    @Test func manifestRoundTrip() throws {
        let planner = ChunkPlanner(recordingID: UUID(), root: root)
        try planner.createDirectory()
        let manifest = RecordingManifest(
            source: .watch,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            chunks: [.init(index: 0, fileName: ChunkPlanner.fileName(for: 0), duration: 300)],
            markers: [42.5, 180]
        )

        try manifest.write(to: planner.directory)

        #expect(try RecordingManifest.read(from: planner.directory) == manifest)
    }

    @Test func recoveryAddsReadableChunksAndMarksInterrupted() throws {
        let planner = ChunkPlanner(recordingID: UUID(), root: root)
        try planner.createDirectory()
        try RecordingManifest(
            source: .watch,
            chunks: [.init(index: 0, fileName: ChunkPlanner.fileName(for: 0), duration: 300)]
        ).write(to: planner.directory)
        for index in 0...2 {
            try Data([1]).write(to: planner.url(for: index))
        }

        // chunk-001 closed but never listed; chunk-002 was open when the app died.
        let durations = [ChunkPlanner.fileName(for: 1): 300.0, ChunkPlanner.fileName(for: 2): 0.0]
        let recovered = try RecoveryScanner.recover(root: root) { durations[$0.lastPathComponent] ?? 0 }

        let manifest = try #require(recovered.first)
        #expect(recovered.count == 1)
        #expect(manifest.status == .interrupted)
        #expect(manifest.chunks.map(\.index) == [0, 1])
        #expect(manifest.totalDuration == 600)
        #expect(FileManager.default.fileExists(atPath: planner.url(for: 2).path(percentEncoded: false)))
        #expect(try RecordingManifest.read(from: planner.directory).status == .interrupted)
    }

    @Test func recoveryLeavesFinishedRecordingsAlone() throws {
        let planner = ChunkPlanner(recordingID: UUID(), root: root)
        try planner.createDirectory()
        try RecordingManifest(source: .phone, status: .finished).write(to: planner.directory)

        #expect(try RecoveryScanner.recover(root: root) { _ in 300 }.isEmpty)
    }

    @Test func processingStateRoundTrips() throws {
        let state = ProcessingState.failed(step: .transcription, chunk: 3, reason: "timeout", retryable: true)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(ProcessingState.self, from: data) == state)
    }
}
