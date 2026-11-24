import SwiftUI

/// Small capsule showing where a meeting is in the pipeline, plus where it was recorded.
struct StatusChip: View {
    let state: ProcessingState
    let source: RecordingManifest.Source

    var body: some View {
        HStack {
            Image(systemName: source == .watch ? "applewatch" : "iphone")
                .accessibilityLabel(source == .watch ? "บันทึกจาก Apple Watch" : "บันทึกจาก iPhone")
            Label(state.label, systemImage: state.systemImage)
        }
        .font(.footnote)
        .foregroundStyle(state.needsAttention ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.fill.tertiary, in: .capsule)
    }
}
