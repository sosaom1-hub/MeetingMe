import Foundation
import SwiftData

/// One recorded meeting on the iPhone. Audio files live on disk under `RecordingPaths.root/<id>/`.
/// Shaped for a later CloudKit sync: every property has a default and relationships are optional.
@Model
final class Meeting {
    var id = UUID()
    var title = ""
    var startedAt = Date.now
    var duration: TimeInterval = 0
    var sourceRaw = RecordingManifest.Source.phone.rawValue
    var markers: [TimeInterval] = []
    /// Known once the recording has ended; nil while the Watch is still recording.
    var expectedChunkCount: Int?
    var stateData: Data?

    @Relationship(deleteRule: .cascade, inverse: \AudioChunk.meeting)
    var chunks: [AudioChunk]? = []

    init(id: UUID, startedAt: Date, source: RecordingManifest.Source) {
        self.id = id
        self.startedAt = startedAt
        self.sourceRaw = source.rawValue
        self.title = "ประชุม " + startedAt.formatted(.dateTime.day().month().hour().minute())
    }

    var source: RecordingManifest.Source {
        RecordingManifest.Source(rawValue: sourceRaw) ?? .phone
    }

    var state: ProcessingState {
        get { stateData.flatMap { try? JSONDecoder().decode(ProcessingState.self, from: $0) } ?? .onPhone }
        set { stateData = try? JSONEncoder().encode(newValue) }
    }

    var sortedChunks: [AudioChunk] {
        (chunks ?? []).sorted { $0.index < $1.index }
    }

    var directory: URL {
        ChunkPlanner(recordingID: id, root: RecordingPaths.root).directory
    }
}
