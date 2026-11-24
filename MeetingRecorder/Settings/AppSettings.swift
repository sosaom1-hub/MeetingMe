import Foundation

/// `@AppStorage` keys and defaults, in one place so every screen reads the same values.
enum AppSettings {
    static let serverURL = "serverURL"
    static let transcriptLanguage = "transcriptLanguage"
    static let hasAcceptedUploadDisclosure = "hasAcceptedUploadDisclosure"

    /// Mixed meetings keep some English terms readable in Latin script.
    static let defaultLanguage = TranscriptLanguage.thaiMixed.rawValue
}
