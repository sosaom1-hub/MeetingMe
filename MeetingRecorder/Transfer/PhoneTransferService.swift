import Foundation
import Observation
import WatchConnectivity

/// Receives chunk files and manifests from the Watch. A chunk is acknowledged only after it is safely
/// moved into app storage, so the Watch never deletes audio the iPhone does not have.
@Observable
final class PhoneTransferService: NSObject {
    /// Set by the app; called on the main actor for every manifest that arrives.
    var onManifest: ((RecordingManifest) -> Void)?
    private(set) var isWatchAppInstalled = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the consent reminder text to the Watch. Application context keeps only the latest value,
    /// and the system delivers it when the Watch app next runs.
    func sendConsentText() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let text = UserDefaults.standard.string(forKey: ConsentDefaults.storageKey) ?? ConsentDefaults.text
        try? session.updateApplicationContext([TransferMessage.consentText: text])
    }

    private func updateWatchState(installed: Bool) {
        isWatchAppInstalled = installed
        sendConsentText()
    }
}

extension PhoneTransferService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in self.updateWatchState(installed: installed) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another paired Watch: reactivate for the new one.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        Task { @MainActor in self.updateWatchState(installed: installed) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata,
              metadata[TransferMessage.kind] as? String == TransferMessage.Kind.chunk.rawValue,
              let fileName = metadata[TransferMessage.fileName] as? String,
              ChunkPlanner.index(of: fileName) != nil,
              let data = metadata[TransferMessage.manifest] as? Data,
              let manifest = try? RecordingManifest.decode(data) else { return }

        // The system deletes `file.fileURL` when this method returns, so move it now.
        let planner = ChunkPlanner(recordingID: manifest.id, root: RecordingPaths.root)
        do {
            try planner.createDirectory()
            let destination = planner.directory.appending(path: fileName)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: file.fileURL, to: destination)
        } catch {
            return // No ack: the Watch keeps the chunk and sends it again later.
        }

        session.transferUserInfo([
            TransferMessage.kind: TransferMessage.Kind.ack.rawValue,
            TransferMessage.recordingID: manifest.id.uuidString,
            TransferMessage.fileName: fileName,
        ])
        Task { @MainActor in self.onManifest?(manifest) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[TransferMessage.kind] as? String == TransferMessage.Kind.manifest.rawValue,
              let data = userInfo[TransferMessage.manifest] as? Data,
              let manifest = try? RecordingManifest.decode(data) else { return }
        Task { @MainActor in self.onManifest?(manifest) }
    }
}
