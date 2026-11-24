import SwiftUI

@main
struct MeetingRecorderWatchApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 8) {
                Image(systemName: "record.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("บันทึกประชุม")
                    .font(.headline)
            }
        }
    }
}
