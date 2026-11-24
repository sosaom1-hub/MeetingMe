import Foundation
import SwiftData
import Testing
@testable import MeetingRecorder

struct MeetingStoreTests {
    let store: MeetingStore
    let id = UUID()
    let planner: ChunkPlanner

    init() throws {
        let container = try ModelContainer(for: Meeting.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = MeetingStore(context: ModelContext(container))
        planner = ChunkPlanner(recordingID: id, root: RecordingPaths.root)
        try planner.createDirectory()
    }

    private func manifest(_ status: RecordingManifest.Status, chunks: Int) -> RecordingManifest {
        RecordingManifest(
            id: id,
            source: .watch,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            status: status,
            chunks: (0..<chunks).map { .init(index: $0, fileName: ChunkPlanner.fileName(for: $0), duration: 300) }
        )
    }

    private func arrive(_ index: Int) throws {
        try Data([1]).write(to: planner.url(for: index))
    }

    private func meeting() throws -> Meeting {
        try #require(try store.context.fetch(FetchDescriptor<Meeting>()).first)
    }

    @Test func chunkDuringRecordingShowsRecording() throws {
        defer { try? FileManager.default.removeItem(at: planner.directory) }
        try arrive(0)
        store.upsert(manifest(.recording, chunks: 1))

        #expect(try meeting().state == .recording)
        #expect(try meeting().duration == 300)
    }

    @Test func finishedWithMissingChunksShowsTransferring() throws {
        defer { try? FileManager.default.removeItem(at: planner.directory) }
        try arrive(0)
        store.upsert(manifest(.finished, chunks: 3))

        #expect(try meeting().state == .transferring(sent: 1, total: 3))
    }

    @Test func lateChunkManifestDoesNotUndoFinishedRecording() throws {
        defer { try? FileManager.default.removeItem(at: planner.directory) }
        try arrive(0)
        try arrive(1)
        store.upsert(manifest(.finished, chunks: 2))
        store.upsert(manifest(.recording, chunks: 1))

        let meeting = try meeting()
        #expect(meeting.state == .awaitingSelection)
        #expect(meeting.chunks?.count == 2)
        #expect(meeting.duration == 600)
    }

    @Test func retentionKeepsAudioUntilEveryChunkHasTranscript() throws {
        defer { try? FileManager.default.removeItem(at: planner.directory) }
        try arrive(0)
        try arrive(1)
        store.upsert(manifest(.finished, chunks: 2))
        let meeting = try meeting()
        meeting.sortedChunks[0].result = ChunkTranscript(text: "ก", segments: [])

        #expect(!store.deleteAudioIfFullyTranscribed(meeting))
        #expect(FileManager.default.fileExists(atPath: planner.url(for: 0).path(percentEncoded: false)))

        meeting.sortedChunks[1].result = ChunkTranscript(text: "ข", segments: [])
        #expect(store.deleteAudioIfFullyTranscribed(meeting))
        #expect(!FileManager.default.fileExists(atPath: planner.url(for: 0).path(percentEncoded: false)))
        #expect(meeting.audioDeletedAt != nil)
        #expect(meeting.sortedChunks.map(\.transcript) == ["ก", "ข"])
    }

    @Test func deleteAllRemovesEveryMeeting() throws {
        try arrive(0)
        store.upsert(manifest(.finished, chunks: 1))

        store.deleteAll()

        #expect(try store.context.fetch(FetchDescriptor<Meeting>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: planner.directory.path(percentEncoded: false)))
    }

    @Test func deleteRemovesAudioFiles() throws {
        try arrive(0)
        store.upsert(manifest(.finished, chunks: 1))

        store.delete(try meeting())

        #expect(!FileManager.default.fileExists(atPath: planner.directory.path(percentEncoded: false)))
        #expect(try store.context.fetch(FetchDescriptor<Meeting>()).isEmpty)
    }
}
