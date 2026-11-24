import Foundation

/// One row of the meeting transcript, with a time relative to the start of the whole meeting.
nonisolated struct TranscriptLine: Identifiable, Hashable, Sendable {
    enum Kind: Hashable {
        case speech(String)
        case marker
        /// A chunk with no transcript yet: shown honestly instead of skipped.
        case pending(chunk: Int)
    }

    let id: Int
    let start: TimeInterval
    let kind: Kind

    var timestamp: String {
        Duration.seconds(start).formatted(.time(pattern: .hourMinuteSecond))
    }

    /// `[0:05:12] text` per line, used for the Claude prompt and for exports.
    static func plainText(_ lines: [TranscriptLine]) -> String {
        lines.map { line in
            switch line.kind {
            case .speech(let text): "[\(line.timestamp)] \(text)"
            case .marker: "[\(line.timestamp)] ⭐ จุดสำคัญ"
            case .pending(let chunk): "[\(line.timestamp)] (ส่วนที่ \(chunk) ยังไม่ได้ถอดเสียง)"
            }
        }
        .joined(separator: "\n")
    }

    /// Joins per-chunk segments into one timeline by adding each chunk's start offset, and interleaves ⭐ markers.
    static func build(chunks: [(duration: TimeInterval, transcript: ChunkTranscript?)], markers: [TimeInterval]) -> [TranscriptLine] {
        var items: [(start: TimeInterval, kind: Kind)] = []
        var offset: TimeInterval = 0
        for (number, chunk) in chunks.enumerated() {
            if let transcript = chunk.transcript {
                items += transcript.segments.map { (offset + $0.start, .speech($0.text)) }
            } else {
                items.append((offset, .pending(chunk: number + 1)))
            }
            offset += chunk.duration
        }
        items += markers.map { ($0, .marker) }
        // Stable order: at equal times a marker comes before the speech it points to.
        let sorted = items.enumerated().sorted {
            ($0.element.start, $0.element.kind == .marker ? 0 : 1, $0.offset) < ($1.element.start, $1.element.kind == .marker ? 0 : 1, $1.offset)
        }
        return sorted.enumerated().map { TranscriptLine(id: $0.offset, start: $0.element.element.start, kind: $0.element.element.kind) }
    }
}
