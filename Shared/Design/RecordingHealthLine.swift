import SwiftUI

/// One status line under the meter: a silence warning takes priority, otherwise the estimated time left.
struct RecordingHealthLine: View {
    let isSilent: Bool
    let hoursLeft: Double?

    var body: some View {
        if isSilent {
            Label("ไม่ได้ยินเสียงมา 1 นาที ไมค์ถูกบัง?", systemImage: "mic.slash")
                .font(.footnote)
                .foregroundStyle(Theme.warning)
                .multilineTextAlignment(.center)
        } else if let hoursLeft {
            Label(text(for: hoursLeft), systemImage: "hourglass")
                .font(.footnote)
                .foregroundStyle(hoursLeft < 1 ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.secondary))
                .accessibilityLabel("บันทึกต่อได้อีก \(text(for: hoursLeft))")
        }
    }

    private func text(for hours: Double) -> String {
        if hours >= 10 { return "เหลือ 10+ ชม." }
        if hours >= 1 { return "เหลือ ~\(Int(hours)) ชม." }
        return "เหลือ ~\(max(Int(hours * 60), 1)) นาที"
    }
}
