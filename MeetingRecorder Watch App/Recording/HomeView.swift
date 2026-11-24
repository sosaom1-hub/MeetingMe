import AVFoundation
import SwiftUI

struct HomeView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @AppStorage("consentText") private var consentText = ConsentDefaults.text
    @AppStorage("consentSnoozedUntil") private var consentSnoozedUntil = 0.0
    @AppStorage("hasSeenMicNotice") private var hasSeenMicNotice = false
    @ScaledMetric(relativeTo: .title) private var recordButtonSize = 76.0

    @State private var preflight = PreflightStatus()
    @State private var isShowingConsent = false
    @State private var snoozeConsent = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Button(action: requestStart) {
                Label("เริ่มบันทึก", systemImage: "mic.fill")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(width: recordButtonSize, height: recordButtonSize)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(Theme.recording)

            Text("เริ่มบันทึก")
                .font(.headline)

            Spacer(minLength: 0)
            PreflightLine(status: preflight)
        }
        .navigationTitle("ประชุม")
        .onAppear { preflight = .current() }
        .sheet(isPresented: $isShowingConsent) {
            ConsentSheet(
                consentText: consentText,
                showsMicNotice: !hasSeenMicNotice,
                snooze: $snoozeConsent,
                onStart: confirmConsent
            )
        }
        .alert("บันทึกไม่ได้", isPresented: $isShowingError) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func requestStart() {
        if hasSeenMicNotice, Date.now.timeIntervalSince1970 < consentSnoozedUntil {
            start()
        } else {
            isShowingConsent = true
        }
    }

    private func confirmConsent() {
        hasSeenMicNotice = true
        if snoozeConsent {
            consentSnoozedUntil = Date.now.addingTimeInterval(24 * 3600).timeIntervalSince1970
        }
        start()
    }

    private func start() {
        Task {
            guard await AVAudioApplication.requestRecordPermission() else {
                show("ยังไม่ได้อนุญาตให้ใช้ไมโครโฟน เปิดได้ที่ การตั้งค่า > ความเป็นส่วนตัว > ไมโครโฟน")
                return
            }
            do {
                try recorder.start()
            } catch {
                show(error.localizedDescription)
            }
        }
    }

    private func show(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
