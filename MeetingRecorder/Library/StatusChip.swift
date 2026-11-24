import SwiftUI

/// Small capsule showing where a meeting is in the pipeline, plus where it was recorded.
struct StatusChip: View {
    let state: ProcessingState
    let source: RecordingManifest.Source

    private var sourceImage: String {
        switch source {
        case .watch: "applewatch"
        case .phone: "iphone"
        case .imported: "square.and.arrow.down"
        }
    }

    private var sourceLabel: String {
        switch source {
        case .watch: "บันทึกจาก Apple Watch"
        case .phone: "บันทึกจาก iPhone"
        case .imported: "นำเข้าจากไฟล์"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: sourceImage)
                .accessibilityLabel(sourceLabel)
            Label(state.label, systemImage: state.systemImage)
        }
        .font(.footnote)
        .foregroundStyle(state.needsAttention ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.fill.tertiary, in: .capsule)
    }
}
