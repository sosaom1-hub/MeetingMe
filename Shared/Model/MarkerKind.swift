import Foundation

/// What a marker tapped during recording means.
/// ⭐ stays in `RecordingManifest.markers` (so old manifests read as ⭐); the other kinds are stored as
/// `TimedNote`s whose text starts with the kind's emoji. That needs no new SwiftData field, and notes already
/// flow to the transcript timeline, the Claude prompt, and exports.
nonisolated enum MarkerKind: Int, CaseIterable, Identifiable, Sendable {
    case important, actionItem, decision, question

    var id: Self { self }

    var emoji: String {
        switch self {
        case .important: "⭐"
        case .actionItem: "✅"
        case .decision: "⚖️"
        case .question: "❓"
        }
    }

    var label: String {
        switch self {
        case .important: "จุดสำคัญ"
        case .actionItem: "งานที่ต้องทำ"
        case .decision: "มติ"
        case .question: "คำถาม"
        }
    }

    var systemImage: String {
        switch self {
        case .important: "star.fill"
        case .actionItem: "checkmark.circle.fill"
        case .decision: "scalemass.fill"
        case .question: "questionmark.circle.fill"
        }
    }

    /// Text of the `TimedNote` that stores this marker (not used for ⭐).
    var noteText: String { "\(emoji) \(label)" }

    /// Recognizes a note created by `noteText`, so the iPhone can show it as a marker rather than typed text.
    init?(noteText: String) {
        guard let kind = Self.allCases.first(where: { $0 != .important && noteText == $0.noteText }) else { return nil }
        self = kind
    }
}
