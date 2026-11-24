import SwiftUI

/// The Watch as a remote for an iPhone recording (the iPhone on the table has the better microphone).
/// Start, stop and ⭐ marker are sent with WatchConnectivity; the iPhone does the recording.
struct PhoneRemoteView: View {
    @Environment(WatchTransferService.self) private var transfer
    @AppStorage(ConsentDefaults.storageKey) private var consentText = ConsentDefaults.text

    @State private var isConfirmingStart = false
    @State private var startOnWatch = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var markerFeedback = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if !transfer.isPhoneReachable {
                    unreachable
                } else if let state = transfer.phoneState, state.isActive {
                    recording(state)
                } else {
                    ready
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("iPhone")
        .consentStartFlow(isRequested: $startOnWatch)
        .confirmationDialog(consentText, isPresented: $isConfirmingStart, titleVisibility: .visible) {
            Button("แจ้งแล้ว เริ่มบันทึก") { send(.start) }
        }
        .sensoryFeedback(.success, trigger: markerFeedback)
        .task {
            try? await transfer.sendRemote(.status)
        }
    }

    private var unreachable: some View {
        VStack(spacing: 8) {
            Label("ติดต่อ iPhone ไม่ได้", systemImage: "iphone.slash")
                .font(.headline)
            Text("เปิดแอป MeetingMe บน iPhone ไว้ และให้ iPhone อยู่ใกล้นาฬิกา")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("อัดบนนาฬิกาแทน", systemImage: "mic.fill") { startOnWatch = true }
                .tint(Theme.recording)
        }
    }

    private var ready: some View {
        VStack(spacing: 8) {
            Label("iPhone พร้อม", systemImage: "iphone")
                .font(.headline)
            Text("วาง iPhone กลางโต๊ะ เสียงจะชัดกว่าไมค์ที่ข้อมือ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("อัดด้วย iPhone", systemImage: "mic.fill") { isConfirmingStart = true }
                .tint(Theme.recording)
                .disabled(isBusy)
        }
    }

    private func recording(_ state: RemoteState) -> some View {
        VStack(spacing: 8) {
            Label(state.phase == .paused ? "iPhone หยุดชั่วคราว" : "iPhone กำลังบันทึก", systemImage: "iphone.radiowaves.left.and.right")
                .font(.footnote)
                .foregroundStyle(state.phase == .paused ? .secondary : Theme.recording)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = elapsed(state, at: context.date)
                Text(Duration.seconds(elapsed).formatted(.time(pattern: .hourMinuteSecond)))
                    .font(.title2.monospacedDigit())
                    .accessibilityLabel("บันทึกไปแล้ว \(Duration.seconds(elapsed).formatted(.time(pattern: .hourMinuteSecond)))")
            }
            LevelMeter(level: state.level)
            HStack {
                Button("จุดสำคัญ", systemImage: "star.fill") { send(.marker) }
                    .labelStyle(.iconOnly)
                    .disabled(isBusy || state.phase != .recording)
                    .accessibilityHint("ทำเครื่องหมายจุดสำคัญในการบันทึกบน iPhone")
                Button("หยุดบันทึก", systemImage: "stop.fill") { send(.stop) }
                    .labelStyle(.iconOnly)
                    .tint(Theme.recording)
                    .disabled(isBusy)
                    .accessibilityHint("หยุดการบันทึกบน iPhone")
            }
            if state.markers > 0 {
                Text("⭐ \(state.markers)")
                    .font(.footnote)
                    .accessibilityLabel("จุดสำคัญ \(state.markers) จุด")
            }
        }
    }

    /// Counts on between the iPhone's once-a-second updates, but never more than 5 s past the last one.
    private func elapsed(_ state: RemoteState, at date: Date) -> TimeInterval {
        guard state.phase == .recording else { return state.elapsed }
        return state.elapsed + min(max(date.timeIntervalSince(transfer.phoneStateReceivedAt), 0), 5)
    }

    private func send(_ command: RemoteCommand) {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                try await transfer.sendRemote(command)
                if command == .marker { markerFeedback += 1 }
            } catch {
                errorMessage = error.localizedDescription
            }
            isBusy = false
        }
    }
}
