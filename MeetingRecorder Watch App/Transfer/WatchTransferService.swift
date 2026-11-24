import Foundation
import Observation
import WatchConnectivity

/// Sends each closed chunk to the iPhone and deletes it only after the iPhone acknowledges it.
/// Transfers are queued by the system and survive relaunches; anything left over is re-sent on activation.
@Observable
final class WatchTransferService: NSObject {
    struct RecentItem: Identifiable, Equatable {
        let id: UUID
        let startedAt: Date
        let duration: TimeInterval
        let status: RecordingManifest.Status
        let chunkCount: Int
        /// Chunks still stored on the Watch (not yet acknowledged by the iPhone).
        let pendingCount: Int
    }

    private(set) var recent: [RecentItem] = []
    private(set) var isPhoneReachable = false

    private let root: URL
    private static let keptFinishedRecordings = 10

    init(root: URL = RecordingPaths.root) {
        self.root = root
        super.init()
    }

    func activate() {
        refresh()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(chunk index: Int, of manifest: RecordingManifest) {
        let fileName = ChunkPlanner.fileName(for: index)
        let url = ChunkPlanner(recordingID: manifest.id, root: root).url(for: index)
        guard let data = try? manifest.encoded(), FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        WCSession.default.transferFile(url, metadata: [
            TransferMessage.kind: TransferMessage.Kind.chunk.rawValue,
            TransferMessage.fileName: fileName,
            TransferMessage.manifest: data,
        ])
        refresh()
    }

    func sendManifest(_ manifest: RecordingManifest) {
        guard let data = try? manifest.encoded() else { return }
        WCSession.default.transferUserInfo([
            TransferMessage.kind: TransferMessage.Kind.manifest.rawValue,
            TransferMessage.manifest: data,
        ])
        refresh()
    }

    /// Re-queues finished recordings' chunks that are still on the Watch and not in flight.
    func resendPending() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let inFlight = Set(session.outstandingFileTransfers.map { $0.file.fileURL.standardizedFileURL })
        for manifest in manifests() where manifest.status != .recording {
            let planner = ChunkPlanner(recordingID: manifest.id, root: root)
            var resent = false
            for chunk in manifest.chunks {
                let url = planner.url(for: chunk.index)
                guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
                      !inFlight.contains(url.standardizedFileURL) else { continue }
                send(chunk: chunk.index, of: manifest)
                resent = true
            }
            if resent {
                sendManifest(manifest)
            }
        }
    }

    func refresh() {
        let fileManager = FileManager.default
        let items = manifests().map { manifest in
            let planner = ChunkPlanner(recordingID: manifest.id, root: root)
            let pending = manifest.chunks.filter {
                fileManager.fileExists(atPath: planner.url(for: $0.index).path(percentEncoded: false))
            }.count
            return RecentItem(
                id: manifest.id,
                startedAt: manifest.startedAt,
                duration: manifest.totalDuration,
                status: manifest.status,
                chunkCount: manifest.chunks.count,
                pendingCount: pending
            )
        }
        .sorted { $0.startedAt > $1.startedAt }

        // Only fully delivered recordings are pruned; anything with audio left on the Watch is kept.
        for item in items.dropFirst(Self.keptFinishedRecordings) where item.pendingCount == 0 && item.status != .recording {
            try? fileManager.removeItem(at: ChunkPlanner(recordingID: item.id, root: root).directory)
        }
        recent = Array(items.prefix(5))
        isPhoneReachable = WCSession.isSupported() && WCSession.default.isReachable
    }

    private func handleAck(recordingID: String, fileName: String) {
        guard let id = UUID(uuidString: recordingID), ChunkPlanner.index(of: fileName) != nil else { return }
        let url = ChunkPlanner(recordingID: id, root: root).directory.appending(path: fileName)
        try? FileManager.default.removeItem(at: url)
        refresh()
    }

    private func manifests() -> [RecordingManifest] {
        let directories = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return directories.compactMap { try? RecordingManifest.read(from: $0) }
    }
}

extension WatchTransferService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.resendPending()
            self.refresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard userInfo[TransferMessage.kind] as? String == TransferMessage.Kind.ack.rawValue,
              let recordingID = userInfo[TransferMessage.recordingID] as? String,
              let fileName = userInfo[TransferMessage.fileName] as? String else { return }
        Task { @MainActor in self.handleAck(recordingID: recordingID, fileName: fileName) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: (any Error)?) {
        guard error != nil else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            self.resendPending()
        }
    }
}
