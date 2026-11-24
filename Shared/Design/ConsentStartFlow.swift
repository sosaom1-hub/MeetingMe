import AVFoundation
import SwiftUI

/// Shared start flow for Watch and iPhone: consent reminder (unless snoozed), microphone permission, then record.
struct ConsentStartFlow: ViewModifier {
    @Binding var isRequested: Bool

    @Environment(ChunkedRecorder.self) private var recorder
    @AppStorage(ConsentDefaults.storageKey) private var consentText = ConsentDefaults.text
    @AppStorage("consentSnoozedUntil") private var consentSnoozedUntil = 0.0
    @AppStorage("hasSeenMicNotice") private var hasSeenMicNotice = false

    @State private var isShowingConsent = false
    @State private var snoozeConsent = false
    @State private var errorMessage: String?
    @State private var isShowingError = false

    func body(content: Content) -> some View {
        content
            .onChange(of: isRequested) { _, requested in
                guard requested else { return }
                isRequested = false
                if hasSeenMicNotice, Date.now.timeIntervalSince1970 < consentSnoozedUntil {
                    start()
                } else {
                    isShowingConsent = true
                }
            }
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

extension View {
    func consentStartFlow(isRequested: Binding<Bool>) -> some View {
        modifier(ConsentStartFlow(isRequested: isRequested))
    }
}
