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
    /// Answer pasted back from the Claude app, stored exactly as pasted.
    var summaryText: String?
    var summaryPastedAt: Date?
    /// Set when audio files were removed by the retention setting; the transcript stays.
    var audioDeletedAt: Date?
    /// Free-text notes the user writes about the meeting.
    var myNotes = ""
    /// Notes typed during recording, JSON `[RecordingManifest.TimedNote]`.
    var timedNotesData: Data?
    var recordingTypeRaw = RecordingType.meeting.rawValue
    /// Lowercased title, transcript, summary and notes, for full-text search. Rebuilt by `refreshSearchText()`.
    var searchText = ""

    @Relationship(deleteRule: .cascade, inverse: \AudioChunk.meeting)
    var chunks: [AudioChunk]? = []

    init(id: UUID, startedAt: Date, source: RecordingManifest.Source) {
        self.id = id
        self.startedAt = startedAt
        self.sourceRaw = source.rawValue
        self.title = Self.defaultTitle(for: startedAt)
    }

    /// Automatic title; a title chosen on the Watch replaces it only while it is still this value.
    static func defaultTitle(for date: Date) -> String {
        "ประชุม " + date.formatted(.dateTime.day().month().hour().minute())
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

    var timedNotes: [RecordingManifest.TimedNote] {
        get { timedNotesData.flatMap { try? JSONDecoder().decode([RecordingManifest.TimedNote].self, from: $0) } ?? [] }
        set { timedNotesData = try? JSONEncoder().encode(newValue) }
    }

    var recordingType: RecordingType {
        get { RecordingType(rawValue: recordingTypeRaw) ?? .meeting }
        set { recordingTypeRaw = newValue.rawValue }
    }

    var transcriptLines: [TranscriptLine] {
        TranscriptLine.build(chunks: sortedChunks.map { ($0.duration, $0.result) }, markers: markers, notes: timedNotes)
    }

    /// Call after any change to title, transcript, summary or notes.
    func refreshSearchText() {
        let parts = [title, myNotes, summaryText ?? ""]
            + timedNotes.map(\.text)
            + sortedChunks.compactMap(\.transcript)
        searchText = parts.joined(separator: "\n").lowercased()
    }

    /// About 40 characters either side of the first match in transcript, summary or notes.
    func snippet(matching query: String) -> String? {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty, !title.lowercased().contains(needle),
              let range = searchText.range(of: needle) else { return nil }
        let start = searchText.index(range.lowerBound, offsetBy: -40, limitedBy: searchText.startIndex) ?? searchText.startIndex
        let end = searchText.index(range.upperBound, offsetBy: 40, limitedBy: searchText.endIndex) ?? searchText.endIndex
        let text = searchText[start..<end].replacing("\n", with: " ")
        return (start > searchText.startIndex ? "…" : "") + text + (end < searchText.endIndex ? "…" : "")
    }

    var hasFullTranscript: Bool {
        let chunks = sortedChunks
        return !chunks.isEmpty && chunks.allSatisfy { $0.result != nil }
    }
}
