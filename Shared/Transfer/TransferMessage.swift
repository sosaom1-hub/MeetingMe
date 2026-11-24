import Foundation

/// Keys for WatchConnectivity payloads. Values must be property-list types.
///
/// - Watch → iPhone file: `kind=chunk`, `fileName`, `manifest` (JSON `RecordingManifest`).
/// - Watch → iPhone user info: `kind=manifest`, `manifest` (sent when a recording ends).
/// - iPhone → Watch user info: `kind=ack`, `recordingID`, `fileName` (the Watch may now delete that chunk).
/// - iPhone → Watch application context: `consentText` (latest value wins).
nonisolated enum TransferMessage {
    static let kind = "kind"
    static let manifest = "manifest"
    static let fileName = "fileName"
    static let recordingID = "recordingID"
    static let consentText = "consentText"

    enum Kind: String {
        case chunk, manifest, ack
    }
}
