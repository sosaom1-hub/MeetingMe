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
        if let notes = manifest.notes {
            meeting.timedNotes = Array(Set(meeting.timedNotes + notes)).sorted { $0.time < $1.time }
        }
        meeting.refreshSearchText()
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

    /// Replaces one transcript segment's text (user correction). Empty text is rejected.
    func editTranscript(_ meeting: Meeting, at source: TranscriptLine.Source, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let chunks = meeting.sortedChunks
        guard !trimmed.isEmpty, chunks.indices.contains(source.chunk),
              var result = chunks[source.chunk].result,
              result.segments.indices.contains(source.segment) else { return }
        result.segments[source.segment].text = trimmed
        result.text = result.segments.map(\.text).joined(separator: " ")
        chunks[source.chunk].result = result
        meeting.refreshSearchText()
        try? context.save()
    }

    /// Deletes every meeting and its files. Callers must have confirmed with the user first.
    func deleteAll() {
        let meetings = (try? context.fetch(FetchDescriptor<Meeting>())) ?? []
        for meeting in meetings {
            try? FileManager.default.removeItem(at: meeting.directory)
            context.delete(meeting)
        }
        try? FileManager.default.removeItem(at: URL.temporaryDirectory.appending(path: "Exports"))
        try? context.save()
    }

    /// Retention setting "delete audio after transcript": removes the audio only once every chunk has a transcript.
    /// Returns false (and deletes nothing) if any chunk is still untranscribed.
    @discardableResult
    func deleteAudioIfFullyTranscribed(_ meeting: Meeting) -> Bool {
        guard meeting.hasFullTranscript, meeting.audioDeletedAt == nil else { return false }
        for chunk in meeting.sortedChunks {
            try? FileManager.default.removeItem(at: meeting.directory.appending(path: chunk.fileName))
        }
        meeting.audioDeletedAt = .now
        try? context.save()
        return true
    }
}

private extension ProcessingState {
    var isTransferring: Bool {
        if case .transferring = self { true } else { false }
    }
}
