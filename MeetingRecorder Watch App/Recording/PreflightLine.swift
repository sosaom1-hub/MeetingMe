import SwiftUI

/// Battery and storage at a glance. Turns orange when a long recording may not fit.
struct PreflightLine: View {
    let status: PreflightStatus

    var body: some View {
        VStack {
            HStack {
                if let level = status.batteryLevel {
                    Label(level.formatted(.percent.precision(.fractionLength(0))), systemImage: "battery.75percent")
                        .foregroundStyle(status.isBatteryLow ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.secondary))
                        .accessibilityLabel("แบตเตอรี่ \(level.formatted(.percent.precision(.fractionLength(0))))")
                }
                if let hours = status.hoursOfAudioLeft, hours < 10 {
                    Label("~\(Int(hours)) ชม.", systemImage: "internaldrive")
                        .foregroundStyle(status.isStorageLow ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.secondary))
                        .accessibilityLabel("พื้นที่พอบันทึกได้ประมาณ \(Int(hours)) ชั่วโมง")
                }
            }

            if status.isBatteryLow || status.isStorageLow {
                Text(status.isStorageLow ? "พื้นที่ใกล้เต็ม อาจบันทึกได้ไม่ครบ" : "แบตต่ำ อาจบันทึกได้ไม่ครบ")
                    .foregroundStyle(Theme.warning)
                    .multilineTextAlignment(.center)
            }
        }
        .font(.footnote)
    }
}
