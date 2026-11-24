import Foundation

/// Watch-only shared instances. The recorder and intent requests live in `AppServices` (shared with iPhone).
enum WatchServices {
    static let transfer = WatchTransferService()
}
