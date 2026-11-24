import Foundation

/// Splits the answer the user pasted from Claude into sections by its headings.
/// Anything unexpected is kept: with no recognizable headings the whole text becomes one section.
enum SummaryParser {
    enum Kind: Sendable {
        case summary, decisions, actionItems, uncertain, other

        var systemImage: String {
            switch self {
            case .summary: "text.alignleft"
            case .decisions: "checkmark.seal"
            case .actionItems: "checklist"
            case .uncertain: "questionmark.circle"
            case .other: "doc.text"
            }
        }
    }

    struct Section: Identifiable, Equatable, Sendable {
        let id: Int
        let title: String
        let body: String
        let kind: Kind
    }

    static func parse(_ text: String) -> [Section] {
        var sections: [(title: String, lines: [String])] = []
        var preamble: [String] = []

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let title = heading(in: line) {
                sections.append((title, []))
            } else if sections.isEmpty {
                preamble.append(String(rawLine))
            } else {
                sections[sections.count - 1].lines.append(String(rawLine))
            }
        }

        let trimmedPreamble = preamble.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if sections.isEmpty {
            return trimmedPreamble.isEmpty ? [] : [Section(id: 0, title: "ผลสรุป", body: trimmedPreamble, kind: .other)]
        }
        var result: [Section] = []
        if !trimmedPreamble.isEmpty {
            result.append(Section(id: 0, title: "หมายเหตุ", body: trimmedPreamble, kind: .other))
        }
        for section in sections {
            result.append(Section(
                id: result.count,
                title: section.title,
                body: section.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                kind: kind(of: section.title)
            ))
        }
        return result
    }

    /// `## Title`, `# Title`, or a line that is only `**Title**`.
    private static func heading(in line: String) -> String? {
        if line.hasPrefix("#") {
            let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : title.replacing("**", with: "")
        }
        if line.count > 4, line.hasPrefix("**"), line.hasSuffix("**"), !line.dropFirst(2).dropLast(2).contains("**") {
            return String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func kind(of title: String) -> Kind {
        let lower = title.lowercased()
        if lower.contains("ไม่แน่ใจ") || lower.contains("uncertain") { return .uncertain }
        if lower.contains("มติ") || lower.contains("decision") { return .decisions }
        if lower.contains("งาน") || lower.contains("action") { return .actionItems }
        if lower.contains("สรุป") || lower.contains("summary") { return .summary }
        return .other
    }
}
