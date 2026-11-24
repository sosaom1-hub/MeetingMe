import SwiftUI

/// Stop control. With "hold to stop" on, a short tap only shows a hint; holding for 1.2 s stops.
/// VoiceOver activation is always deliberate, so it stops directly.
struct StopButton: View {
    let action: () -> Void

    @AppStorage(WatchSettings.holdToStop) private var holdToStop = false
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverOn
    @State private var showsHint = false

    var body: some View {
        Button(showsHint ? "กดค้าง" : "หยุด", systemImage: "stop.fill") {
            if holdToStop && !isVoiceOverOn {
                showsHint = true
            } else {
                action()
            }
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.recording)
        .frame(maxWidth: .infinity)
        .handGestureShortcut(.primaryAction)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.2).onEnded { _ in
                if holdToStop {
                    action()
                }
            }
        )
        .sensoryFeedback(.warning, trigger: showsHint) { _, shown in shown }
        .task(id: showsHint) {
            guard showsHint else { return }
            try? await Task.sleep(for: .seconds(2))
            showsHint = false
        }
        .accessibilityLabel("หยุดบันทึก")
    }
}
