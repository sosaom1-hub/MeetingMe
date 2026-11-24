import Foundation

/// One row of the meeting transcript, with a time relative to the start of the whole meeting.
nonisolated struct TranscriptLine: Identifiable, Hashable, Sendable {
    enum Kind: Hashable {
        case speech(String)
        case marker
        /// A note the user typed while recording. Not something said in the room.
        case note(String)
        /// A chunk with no transcript yet: shown honestly instead of skipped.
        case pending(chunk: Int)
    }

    /// Where a speech line came from, so it can be edited: position in the sorted chunk list and segment index.
    struct Source: Hashable, Sendable {
        let chunk: Int
        let segment: Int
    }

    let id: Int
    let start: TimeInterval
    let kind: Kind
    var source: Source?

    var timestamp: String {
        Duration.seconds(start).formatted(.time(pattern: .hourMinuteSecond))
    }

    /// `[0:05:12] text` per line, used for the Claude prompt and for exports.
    static func plainText(_ lines: [TranscriptLine]) -> String {
        lines.map { line in
            switch line.kind {
            case .speech(let text): "[\(line.timestamp)] \(text)"
            case .marker: "[\(line.timestamp)] ⭐ จุดสำคัญ"
            case .note(let text):
                if let kind = MarkerKind(noteText: text) {
                    "[\(line.timestamp)] \(kind.emoji) ผู้บันทึกทำเครื่องหมาย: \(kind.label)"
                } else {
                    "[\(line.timestamp)] 📝 โน้ตผู้บันทึก: \(text)"
                }
            case .pending(let chunk): "[\(line.timestamp)] (ส่วนที่ \(chunk) ยังไม่ได้ถอดเสียง)"
            }
        }
        .joined(separator: "\n")
    }

    /// Joins per-chunk segments into one timeline by adding each chunk's start offset,
    /// and interleaves ⭐ markers and typed notes.
    static func build(
        chunks: [(duration: TimeInterval, transcript: ChunkTranscript?)],
        markers: [TimeInterval],
        notes: [RecordingManifest.TimedNote] = []
    ) -> [TranscriptLine] {
        var items: [(start: TimeInterval, kind: Kind, source: Source?)] = []
        var offset: TimeInterval = 0
        for (position, chunk) in chunks.enumerated() {
            if let transcript = chunk.transcript {
                items += transcript.segments.enumerated().map {
                    (offset + $0.element.start, .speech($0.element.text), Source(chunk: position, segment: $0.offset))
                }
            } else {
                items.append((offset, .pending(chunk: position + 1), nil))
            }
            offset += chunk.duration
        }
        items += markers.map { ($0, .marker, nil) }
        items += notes.map { ($0.time, .note($0.text), nil) }

        // Stable order: at equal times, markers and notes come before the speech they point to.
        func rank(_ kind: Kind) -> Int {
            switch kind {
            case .marker, .note: 0
            default: 1
            }
        }
        let sorted = items.enumerated().sorted {
            ($0.element.start, rank($0.element.kind), $0.offset) < ($1.element.start, rank($1.element.kind), $1.offset)
        }
        return sorted.enumerated().map {
            TranscriptLine(id: $0.offset, start: $0.element.element.start, kind: $0.element.element.kind, source: $0.element.element.source)
        }
    }
}
