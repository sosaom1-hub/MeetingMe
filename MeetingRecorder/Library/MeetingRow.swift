import SwiftUI

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        VStack(alignment: .leading) {
            Text(meeting.title)
                .font(.headline)
                .lineLimit(2)

            HStack {
                Text(meeting.startedAt, format: .dateTime.day().month().year().hour().minute())
                Text(Duration.seconds(meeting.duration).formatted(.time(pattern: .hourMinuteSecond)))
                    .monospacedDigit()
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
