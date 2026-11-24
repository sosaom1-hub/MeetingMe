import SwiftUI

struct WatchRootView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @Environment(WatchTransferService.self) private var transfer

    var body: some View {
        NavigationStack {
            content
        }
        .tint(Theme.recording)
        .sensoryFeedback(trigger: recorder.phase) { _, newPhase in
            switch newPhase {
            case .recording: .start
            case .stopped(.interrupted): .warning
            case .stopped: .stop
            case .idle: nil
            }
        }
        .task { connect() }
    }

    @ContentBuilder private var content: some View {
        switch recorder.phase {
        case .idle:
            TabView {
                HomeView()
                RecentListView()
            }
            .tabViewStyle(.verticalPage)
        case .recording:
            RecordingView()
        case .stopped(let status):
            StoppedView(status: status)
        }
    }

    private func connect() {
        recorder.onChunkClosed = { manifest, index in transfer.send(chunk: index, of: manifest) }
        recorder.onFinish = { manifest in transfer.sendManifest(manifest) }

        // A recording still marked "recording" on launch means the app was killed mid-recording.
        let recovered = (try? RecoveryScanner.recover(
            root: RecordingPaths.root,
            source: .watch,
            durationOf: RecordingPaths.duration(of:)
        )) ?? []
        if let latest = recovered.max(by: { $0.startedAt < $1.startedAt }) {
            recorder.adoptRecovered(latest)
        }
        transfer.activate()
    }
}
