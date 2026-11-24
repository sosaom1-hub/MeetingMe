import AVFAudio
import Foundation
import Observation
import WatchConnectivity

/// Receives chunk files and manifests from the Watch. A chunk is acknowledged only after it is safely
/// moved into app storage, so the Watch never deletes audio the iPhone does not have.
@Observable
final class PhoneTransferService: NSObject {
    /// Set by the app; called on the main actor for every manifest that arrives.
    var onManifest: ((RecordingManifest) -> Void)?
    /// Set by the app: the iPhone recorder the Watch remote controls.
    var recorder: ChunkedRecorder?
    private(set) var isWatchAppInstalled = false
    private var remoteLoop: Task<Void, Never>?
    private var lastSentState: RemoteState?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        remoteLoop?.cancel()
        remoteLoop = Task { [weak self] in
            while !Task.isCancelled {
                self?.pushRemoteState()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    var remoteState: RemoteState {
        guard let recorder else { return .idle }
        let phase: RemoteState.Phase = switch recorder.phase {
        case .idle: .idle
        case .recording: .recording
        case .paused: .paused
        case .stopped: .stopped
        }
        return RemoteState(phase: phase, elapsed: recorder.elapsed, level: recorder.level, markers: recorder.markerCount)
    }

    /// Live elapsed time and level for the Watch remote: every second while recording, otherwise only on change.
    private func pushRemoteState() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            lastSentState = nil  // send again as soon as the Watch is back
            return
        }
        let state = remoteState
        guard state.phase == .recording || state != lastSentState else { return }
        lastSentState = state
        session.sendMessage(state.message, replyHandler: nil, errorHandler: nil)
    }

    /// Runs a Watch remote command and returns the reply payload.
    func handle(_ command: RemoteCommand) -> [String: Any] {
        guard let recorder else { return [TransferMessage.error: "แอปบน iPhone ยังไม่พร้อม"] }
        switch command {
        case .status:
            break
        case .start where !recorder.isActive:
            if recorder.phase == .stopped(.interrupted) {
                return [TransferMessage.error: "มีการบันทึกที่ถูกขัดจังหวะบน iPhone เปิด iPhone เพื่อจัดการก่อน"]
            }
            guard AVAudioApplication.shared.recordPermission == .granted else {
                return [TransferMessage.error: "ยังไม่ได้อนุญาตไมโครโฟนบน iPhone เปิดแอปบน iPhone แล้วอัดครั้งแรกจากที่นั่น"]
            }
            recorder.reset()
            do {
                try recorder.start()
            } catch {
                // iOS does not let an app start recording from the background.
                return [TransferMessage.error: "เริ่มบันทึกบน iPhone ไม่ได้ เปิดแอป MeetingMe บน iPhone ไว้ แล้วลองใหม่"]
            }
        case .start:
            break
        case .stop:
            if recorder.isActive { recorder.stop() }
        case .marker:
            recorder.addMarker()
        }
        let state = remoteState
        lastSentState = state
        return state.message
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

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = RemoteCommand(message: message) else {
            replyHandler([TransferMessage.error: "คำสั่งไม่ถูกต้อง"])
            return
        }
        nonisolated(unsafe) let reply = replyHandler  // WatchConnectivity allows replying from any thread
        Task { @MainActor in reply(self.handle(command)) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[TransferMessage.kind] as? String == TransferMessage.Kind.manifest.rawValue,
              let data = userInfo[TransferMessage.manifest] as? Data,
              let manifest = try? RecordingManifest.decode(data) else { return }
        Task { @MainActor in self.onManifest?(manifest) }
    }
}
