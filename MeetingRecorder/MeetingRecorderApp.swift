import SwiftUI

@main
struct MeetingRecorderApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentUnavailableView(
                    "ยังไม่มีการบันทึก",
                    systemImage: "waveform",
                    description: Text("เริ่มบันทึกประชุมจาก Apple Watch หรือ iPhone")
                )
                .navigationTitle("บันทึกประชุม")
            }
        }
    }
}
