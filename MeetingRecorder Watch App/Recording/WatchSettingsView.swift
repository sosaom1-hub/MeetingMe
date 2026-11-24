import SwiftUI

/// Watch-only preferences (third page, Digital Crown down).
enum WatchSettings {
    static let periodicHaptic = "periodicHaptic"
    /// Stray-tap protection. Replaces Water Lock, which watchOS only allows during a workout or location
    /// session (WKInterfaceDevice.h) — sessions this app must not use just to keep recording.
    static let holdToStop = "holdToStop"
}

struct WatchSettingsView: View {
    @AppStorage(WatchSettings.periodicHaptic) private var periodicHaptic = false
    @AppStorage(WatchSettings.holdToStop) private var holdToStop = false

    var body: some View {
        List {
            Section {
                Toggle("สั่นเบาๆ ทุก 10 นาที", isOn: $periodicHaptic)
            } footer: {
                Text("ให้รู้ว่ายังบันทึกอยู่ โดยไม่ต้องยกข้อมือดู")
            }
            Section {
                Toggle("กดค้างเพื่อหยุดบันทึก", isOn: $holdToStop)
            } footer: {
                Text("กันแขนเสื้อหรือมือแตะโดนแล้วหยุดโดยไม่ตั้งใจ ต้องกดปุ่มหยุดค้างไว้ประมาณ 1 วินาที")
            }
        }
        .navigationTitle("ตั้งค่า")
    }
}
