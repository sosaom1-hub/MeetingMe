import SwiftUI

/// Watch-only preferences (third page, Digital Crown down).
enum WatchSettings {
    static let periodicHaptic = "periodicHaptic"
}

struct WatchSettingsView: View {
    @AppStorage(WatchSettings.periodicHaptic) private var periodicHaptic = false

    var body: some View {
        List {
            Section {
                Toggle("สั่นเบาๆ ทุก 10 นาที", isOn: $periodicHaptic)
            } footer: {
                Text("ให้รู้ว่ายังบันทึกอยู่ โดยไม่ต้องยกข้อมือดู")
            }
        }
        .navigationTitle("ตั้งค่า")
    }
}
