import Foundation
import SwiftData

/// One 5-minute audio file of a meeting, and later its transcript.
@Model
final class AudioChunk {
    var index = 0
    var fileName = ""
    var duration: TimeInterval = 0
    var transcript: String?
    var meeting: Meeting?

    init(index: Int, fileName: String, duration: TimeInterval) {
        self.index = index
        self.fileName = fileName
        self.duration = duration
    }
}
