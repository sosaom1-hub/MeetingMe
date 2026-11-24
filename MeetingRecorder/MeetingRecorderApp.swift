import SwiftData
import SwiftUI

@main
struct MeetingRecorderApp: App {
    @State private var recorder = ChunkedRecorder(source: .phone)
    @State private var transfer = PhoneTransferService()

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(recorder)
                .environment(transfer)
        }
        .modelContainer(for: Meeting.self)
    }
}
