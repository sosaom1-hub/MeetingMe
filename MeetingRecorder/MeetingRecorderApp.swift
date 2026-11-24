import SwiftData
import SwiftUI

@main
struct MeetingRecorderApp: App {
    // Shared with App Intents (Siri, Shortcuts, Action button), which run in this process.
    @State private var recorder = AppServices.recorder
    @State private var requests = AppServices.requests
    @State private var transfer = PhoneTransferService()
    @State private var pipeline = TranscriptionPipeline()

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(recorder)
                .environment(requests)
                .environment(transfer)
                .environment(pipeline)
        }
        .modelContainer(for: Meeting.self)
    }
}
