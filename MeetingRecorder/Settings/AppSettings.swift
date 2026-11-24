import Foundation

/// `@AppStorage` keys and defaults, in one place so every screen reads the same values.
enum AppSettings {
    static let serverURL = "serverURL"
    static let transcriptLanguage = "transcriptLanguage"
    static let hasAcceptedUploadDisclosure = "hasAcceptedUploadDisclosure"
    /// Pre-ticked outputs in the summary sheet; the user still confirms per meeting.
    static let defaultOutputs = "defaultOutputs"
    static let defaultOutputsValue = OutputKind.encode(Set(OutputKind.allCases))
    static let audioRetention = "audioRetention"
    /// Correct spellings of names and terms, one per line; Claude uses them to fix ASR misspellings in the summary.
    static let glossary = "glossary"

    /// Mixed meetings keep some English terms readable in Latin script.
    static let defaultLanguage = TranscriptLanguage.thaiMixed.rawValue
}

enum AudioRetention: String, CaseIterable, Identifiable {
    case keep
    case deleteAfterTranscript

    var id: Self { self }

    var label: String {
        switch self {
        case .keep: "เก็บไฟล์เสียงไว้"
        case .deleteAfterTranscript: "ลบไฟล์เสียงเมื่อถอดเสียงครบ"
        }
    }
}
