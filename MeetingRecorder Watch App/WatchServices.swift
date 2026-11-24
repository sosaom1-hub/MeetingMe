import Foundation
import Observation

/// Single instances shared by the SwiftUI app and App Intents (Siri, Shortcuts, Action button),
/// which run in the same Watch app process.
enum WatchServices {
    static let recorder = ChunkedRecorder(source: .watch)
    static let transfer = WatchTransferService()
    static let requests = IntentRequests()
}

/// Requests from App Intents that the UI must finish (start goes through the consent reminder on screen).
@Observable
final class IntentRequests {
    /// A timestamp, not a Bool: a stale request (e.g. made during a recording) must not start one later.
    var startRequestedAt: Date?

    /// Takes a start request made in the last 15 seconds, once.
    func consumeStartRequest() -> Bool {
        defer { startRequestedAt = nil }
        guard let requested = startRequestedAt else { return false }
        return Date.now.timeIntervalSince(requested) < 15
    }
}
