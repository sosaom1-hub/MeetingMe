import Foundation

enum TextExporter {
    static func text(for document: ExportDocument) -> String {
        var lines = [document.title, document.subtitle, ""]
        for block in document.blocks {
            switch block {
            case .heading(let text):
                if lines.last != "" { lines.append("") }
                lines += [text, String(repeating: "=", count: min(max(text.count, 4), 40))]
            case .paragraph(let text):
                lines.append(text)
            case .bullet(let text):
                lines.append("• " + text)
            case .transcriptLine(let time, let text):
                lines.append("[\(time)] \(text)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
