import SwiftUI

struct MeetingRow: View {
    let meeting: Meeting

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading) {
            Text(meeting.title)
                .font(.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)

            // At accessibility text sizes the details stack vertically instead of overflowing.
            let details = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading))
                : AnyLayout(HStackLayout())
            details {
                Text(meeting.startedAt, format: .dateTime.day().month().year().hour().minute())
                Text(Duration.seconds(meeting.duration).formatted(.time(pattern: .hourMinuteSecond)))
                    .monospacedDigit()
                    .accessibilityLabel("ความยาว \(Duration.seconds(meeting.duration).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide)))")
                if !meeting.markers.isEmpty {
                    Label("\(meeting.markers.count)", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("จุดสำคัญ \(meeting.markers.count) จุด")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            StatusChip(state: meeting.state, source: meeting.source)
        }
        .padding(.vertical, 4)
    }
}
