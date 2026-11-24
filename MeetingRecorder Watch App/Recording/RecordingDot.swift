import SwiftUI

/// Unmistakable "recording" indicator. Pulses by opacity only, and stays still in Always-On.
struct RecordingDot: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Label {
            Text("กำลังบันทึก")
        } icon: {
            Circle()
                .fill(Theme.recording)
                .frame(width: 10, height: 10)
                .phaseAnimator([1.0, 0.35]) { dot, opacity in
                    dot.opacity(isLuminanceReduced ? 1 : opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
        }
        .font(.footnote)
        .foregroundStyle(Theme.recording)
    }
}
