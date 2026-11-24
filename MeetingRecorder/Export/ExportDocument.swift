import Foundation

enum ExportFormat: String, CaseIterable, Identifiable, Hashable {
    case pdf, docx, txt

    var id: Self { self }
    var fileExtension: String { rawValue }

    var label: String {
        switch self {
        case .pdf: "PDF"
        case .docx: "Word (.docx)"
        case .txt: "ข้อความ (.txt)"
        }
    }
}

/// Format-neutral content of an export, so TXT, DOCX and PDF always contain the same text.
struct ExportDocument: Equatable, Sendable {
    enum Block: Equatable, Sendable {
        case heading(String)
        case paragraph(String)
        case bullet(String)
        case transcriptLine(time: String, text: String)
    }

    var title: String
    var subtitle: String
    var blocks: [Block]

    /// - Parameter sections: ids of `SummaryParser` sections to include.
    @MainActor
    static func make(meeting: Meeting, sections: Set<Int>, includeTranscript: Bool) -> ExportDocument {
        let duration = Duration.seconds(meeting.duration).formatted(.time(pattern: .hourMinuteSecond))
        var blocks: [Block] = []

        let parsed = meeting.summaryText.map(SummaryParser.parse) ?? []
        for section in parsed where sections.contains(section.id) {
            blocks.append(.heading(section.title))
            blocks += bodyBlocks(section.body)
        }
        if !parsed.isEmpty, parsed.contains(where: { sections.contains($0.id) }) {
            blocks.append(.paragraph("สรุปโดย Claude (ผู้ใช้วางเอง) ตรวจกับ transcript ก่อนใช้งาน"))
        }

        if !meeting.myNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.heading("โน้ตของฉัน"))
            blocks += bodyBlocks(meeting.myNotes)
        }

        if includeTranscript {
            blocks.append(.heading("Transcript"))
            for line in meeting.transcriptLines {
                switch line.kind {
                case .speech(let text): blocks.append(.transcriptLine(time: line.timestamp, text: text))
                case .marker: blocks.append(.transcriptLine(time: line.timestamp, text: "⭐ จุดสำคัญ"))
                case .note(let text): blocks.append(.transcriptLine(time: line.timestamp, text: "📝 โน้ต: \(text)"))
                case .pending(let chunk): blocks.append(.transcriptLine(time: line.timestamp, text: "(ส่วนที่ \(chunk) ยังไม่ได้ถอดเสียง)"))
                }
            }
        }

        return ExportDocument(
            title: meeting.title,
            subtitle: "\(meeting.startedAt.formatted(date: .long, time: .shortened)) · ความยาว \(duration)",
            blocks: blocks
        )
    }

    /// Markdown body → plain paragraphs and bullets (bold markers removed).
    static func bodyBlocks(_ body: String) -> [Block] {
        body.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces).replacing("**", with: "")
            guard !line.isEmpty else { return nil }
            for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
                return .bullet(String(line.dropFirst(marker.count)))
            }
            return .paragraph(line)
        }
    }

    /// Writes the file to a temporary folder for the share sheet. The name is the meeting title, made file-safe.
    func write(as format: ExportFormat) throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let safeName = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        let url = folder.appending(path: "\(safeName.isEmpty ? "meeting" : safeName).\(format.fileExtension)")
        let data = switch format {
        case .txt: Data(TextExporter.text(for: self).utf8)
        case .docx: DocxExporter.data(for: self)
        case .pdf: PDFExporter.data(for: self)
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
