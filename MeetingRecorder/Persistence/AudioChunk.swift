import Foundation
import SwiftData

/// One 5-minute audio file of a meeting, and later its transcript.
@Model
final class AudioChunk {
    var index = 0
    var fileName = ""
    var duration: TimeInterval = 0
    /// Plain text of the chunk, kept separately for search.
    var transcript: String?
    var segmentsData: Data?
    var meeting: Meeting?

    init(index: Int, fileName: String, duration: TimeInterval) {
        self.index = index
        self.fileName = fileName
        self.duration = duration
    }

    var result: ChunkTranscript? {
        get {
            guard let transcript else { return nil }
            let segments = segmentsData.flatMap { try? JSONDecoder().decode([ChunkTranscript.Segment].self, from: $0) } ?? []
            return ChunkTranscript(text: transcript, segments: segments)
        }
        set {
            transcript = newValue?.text
            segmentsData = newValue.flatMap { try? JSONEncoder().encode($0.segments) }
        }
    }
}
