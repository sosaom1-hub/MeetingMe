import SwiftUI

/// Rolling input level, so the user can see the microphone is hearing the room.
struct LevelMeter: View {
    let level: Float

    @State private var history = Array(repeating: Float(0), count: Theme.meterBarCount)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(history.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.recording.gradient)
                    .frame(width: 4, height: 4 + CGFloat(history[index]) * 28)
            }
        }
        .frame(height: 32)
        .onChange(of: level) { _, newLevel in
            history.removeFirst()
            history.append(newLevel)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ระดับเสียง")
        .accessibilityValue(level < 0.05 ? "เงียบ" : "ได้ยินเสียง")
    }
}
