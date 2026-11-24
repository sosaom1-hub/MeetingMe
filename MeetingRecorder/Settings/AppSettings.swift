import Foundation

/// `@AppStorage` keys and defaults, in one place so every screen reads the same values.
enum AppSettings {
    static let serverURL = "serverURL"
    static let transcriptLanguage = "transcriptLanguage"
    static let hasAcceptedUploadDisclosure = "hasAcceptedUploadDisclosure"
    /// Pre-ticked outputs in the summary sheet; the user still confirms per meeting.
    static let defaultOutputs = "defaultOutputs"
    static let defaultOutputsValue = OutputKind.encode(Set(OutputKind.allCases))

    /// Mixed meetings keep some English terms readable in Latin script.
    static let defaultLanguage = TranscriptLanguage.thaiMixed.rawValue
}
