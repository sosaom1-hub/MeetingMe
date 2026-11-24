import SwiftUI

/// Second page (Digital Crown down): the latest recordings and where their audio is. Never shows transcripts.
struct RecentListView: View {
    @Environment(WatchTransferService.self) private var transfer

    var body: some View {
        List {
            if transfer.recent.isEmpty {
                ContentUnavailableView("ยังไม่มีการบันทึก", systemImage: "waveform")
            } else {
                ForEach(transfer.recent) { item in
                    VStack(alignment: .leading) {
                        Text(item.startedAt, format: .dateTime.day().month().hour().minute())
                            .font(.headline)
                        Text(Duration.seconds(item.duration).formatted(.time(pattern: .hourMinuteSecond)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Label(statusText(for: item), systemImage: statusImage(for: item))
                            .font(.footnote)
                            .foregroundStyle(item.pendingCount == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Theme.warning))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("ล่าสุด")
        .onAppear(perform: transfer.refresh)
    }

    private func statusText(for item: WatchTransferService.RecentItem) -> String {
        if item.status == .recording { return "กำลังบันทึก" }
        guard item.pendingCount > 0 else { return "อยู่บน iPhone แล้ว" }
        let sent = item.chunkCount - item.pendingCount
        return transfer.isPhoneReachable
            ? "กำลังส่ง \(sent)/\(item.chunkCount)"
            : "บนนาฬิกา · รอ iPhone (\(item.pendingCount) ส่วน)"
    }

    private func statusImage(for item: WatchTransferService.RecentItem) -> String {
        if item.status == .recording { return "record.circle" }
        guard item.pendingCount > 0 else { return "iphone" }
        return transfer.isPhoneReachable ? "arrow.up.forward.circle" : "applewatch"
    }
}
