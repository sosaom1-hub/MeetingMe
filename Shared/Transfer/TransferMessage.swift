import Foundation

/// Keys for WatchConnectivity payloads. Values must be property-list types.
///
/// - Watch → iPhone file: `kind=chunk`, `fileName`, `manifest` (JSON `RecordingManifest`).
/// - Watch → iPhone user info: `kind=manifest`, `manifest` (sent when a recording ends).
/// - iPhone → Watch user info: `kind=ack`, `recordingID`, `fileName` (the Watch may now delete that chunk).
/// - iPhone → Watch application context: `consentText` (latest value wins).
/// - Watch → iPhone message: `kind=remoteCommand`, `command`; reply `RemoteState` or `error` (see RemoteState.swift).
/// - iPhone → Watch message: `kind=remoteState` while the iPhone records.
nonisolated enum TransferMessage {
    static let kind = "kind"
    static let manifest = "manifest"
    static let fileName = "fileName"
    static let recordingID = "recordingID"
    static let consentText = "consentText"
    static let command = "command"
    static let error = "error"

    enum Kind: String {
        case chunk, manifest, ack, remoteCommand, remoteState
    }
}
