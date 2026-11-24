import SwiftUI

@main
struct MeetingRecorderWatchApp: App {
    @State private var recorder = ChunkedRecorder(source: .watch)
    @State private var transfer = WatchTransferService()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(recorder)
                .environment(transfer)
        }
    }
}
