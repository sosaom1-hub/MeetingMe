import Foundation
import SwiftData

/// The only place that writes meetings. Keeping persistence behind this type is the seam for a later sync layer.
struct MeetingStore {
    let context: ModelContext

    /// Creates or updates the meeting for a manifest from the Watch or from the iPhone recorder.
    /// Manifests can arrive out of order, so an ended recording never goes back to "recording".
    func upsert(_ manifest: RecordingManifest) {
        let id = manifest.id
        let existing = try? context.fetch(FetchDescriptor<Meeting>(predicate: #Predicate { $0.id == id })).first
        let meeting = existing ?? Meeting(id: id, startedAt: manifest.startedAt, source: manifest.source)
        if existing == nil {
            context.insert(meeting)
        }

        let known = Set((meeting.chunks ?? []).map(\.index))
        for chunk in manifest.chunks where !known.contains(chunk.index) {
            let url = meeting.directory.appending(path: chunk.fileName)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            let audio = AudioChunk(index: chunk.index, fileName: chunk.fileName, duration: chunk.duration)
            meeting.chunks = (meeting.chunks ?? []) + [audio]
        }

        meeting.markers = Array(Set(meeting.markers + manifest.markers)).sorted()
        meeting.duration = meeting.sortedChunks.reduce(0) { $0 + $1.duration }
        if manifest.status != .recording {
            meeting.expectedChunkCount = max(meeting.expectedChunkCount ?? 0, manifest.chunks.count)
        }

        let present = meeting.chunks?.count ?? 0
        switch (meeting.expectedChunkCount, manifest.status) {
        case (nil, _):
            meeting.state = .recording
        case (let expected?, _) where present < expected:
            meeting.state = .transferring(sent: present, total: expected)
        case (_, .interrupted):
            meeting.state = .interrupted
        default:
            if meeting.state == .recording || meeting.state.isTransferring || meeting.state == .onPhone {
                meeting.state = .awaitingSelection
            }
        }
        try? context.save()
    }

    /// Deletes the meeting and its audio files. Callers must have confirmed with the user first.
    func delete(_ meeting: Meeting) {
        try? FileManager.default.removeItem(at: meeting.directory)
        context.delete(meeting)
        try? context.save()
    }
}

private extension ProcessingState {
    var isTransferring: Bool {
        if case .transferring = self { true } else { false }
    }
}
