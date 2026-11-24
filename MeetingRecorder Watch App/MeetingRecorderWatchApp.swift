import SwiftUI

@main
struct MeetingRecorderWatchApp: App {
    @State private var recorder = WatchServices.recorder
    @State private var transfer = WatchServices.transfer
    @State private var requests = WatchServices.requests

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(recorder)
                .environment(transfer)
                .environment(requests)
        }
    }
}
