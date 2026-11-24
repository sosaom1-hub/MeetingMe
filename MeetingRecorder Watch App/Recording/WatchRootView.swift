import SwiftUI

struct WatchRootView: View {
    @Environment(ChunkedRecorder.self) private var recorder

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
        .task { recoverUnfinishedRecording() }
    }

    @ContentBuilder private var content: some View {
        switch recorder.phase {
        case .idle:
            HomeView()
        case .recording:
            RecordingView()
        case .stopped(let status):
            StoppedView(status: status)
        }
    }

    /// A recording still marked "recording" on launch means the app was killed mid-recording.
    private func recoverUnfinishedRecording() {
        let recovered = (try? RecoveryScanner.recover(root: RecordingPaths.root, durationOf: RecordingPaths.duration(of:))) ?? []
        if let latest = recovered.max(by: { $0.startedAt < $1.startedAt }) {
            recorder.adoptRecovered(latest)
        }
    }
}
