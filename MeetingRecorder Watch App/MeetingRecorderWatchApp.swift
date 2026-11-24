import SwiftUI

@main
struct MeetingRecorderWatchApp: App {
    @State private var recorder = ChunkedRecorder(source: .watch)

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(recorder)
        }
    }
}
