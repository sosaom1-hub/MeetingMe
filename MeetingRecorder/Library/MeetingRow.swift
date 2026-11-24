import SwiftUI

struct MeetingRow: View {
    let meeting: Meeting
    /// Text around a search match in transcript, summary or notes.
    var snippet: String?

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

            if let snippet {
                Text(snippet)
                    .font(.subheadline)
                    .lineLimit(2)
                    .padding(.vertical, 2)
                    .accessibilityLabel("พบใน: \(snippet)")
            }

            StatusChip(state: meeting.state, source: meeting.source)
        }
        .padding(.vertical, 4)
    }
}
