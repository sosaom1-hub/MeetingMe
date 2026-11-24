import SwiftData
import SwiftUI

@main
struct MeetingRecorderApp: App {
    @State private var recorder = ChunkedRecorder(source: .phone)
    @State private var transfer = PhoneTransferService()
    @State private var pipeline = TranscriptionPipeline()

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(recorder)
                .environment(transfer)
                .environment(pipeline)
        }
        .modelContainer(for: Meeting.self)
    }
}
