import SwiftUI

/// Shared look for Watch and iPhone, so both apps stay consistent.
enum Theme {
    /// The only strong color in the app: it always means "recording".
    static let recording = Color.red
    static let warning = Color.orange
    static let success = Color.green
    static let meterBarCount = 16
    static let savedSummarySeconds = 4
}
