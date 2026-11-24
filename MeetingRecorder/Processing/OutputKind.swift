import Foundation

/// Outputs the user can ask Claude for. The transcript itself always exists once transcription is done.
enum OutputKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case summary
    case decisions
    case actionItems

    var id: Self { self }

    var label: String {
        switch self {
        case .summary: "สรุปสั้น"
        case .decisions: "มติที่ประชุม"
        case .actionItems: "งานที่ต้องทำ (ผู้รับผิดชอบ, กำหนดส่ง)"
        }
    }

    var systemImage: String {
        switch self {
        case .summary: "text.alignleft"
        case .decisions: "checkmark.seal"
        case .actionItems: "checklist"
        }
    }

    /// Stored in `@AppStorage` as a comma-separated list.
    static func decode(_ raw: String) -> Set<OutputKind> {
        Set(raw.split(separator: ",").compactMap { OutputKind(rawValue: String($0)) })
    }

    static func encode(_ kinds: Set<OutputKind>) -> String {
        allCases.filter(kinds.contains).map(\.rawValue).joined(separator: ",")
    }
}

enum SummaryLanguage: String, CaseIterable, Identifiable, Sendable {
    case thai
    case english
    case followMeeting

    var id: Self { self }

    var label: String {
        switch self {
        case .thai: "ภาษาไทย"
        case .english: "English"
        case .followMeeting: "ตามภาษาหลักของการประชุม"
        }
    }
}
