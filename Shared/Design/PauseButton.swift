import SwiftUI

/// Pause / resume within the same recording (Watch and iPhone).
struct PauseButton: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @State private var errorMessage: String?

    private var isPaused: Bool { recorder.phase == .paused }

    var body: some View {
        Button(isPaused ? "บันทึกต่อ" : "หยุดชั่วคราว", systemImage: isPaused ? "record.circle" : "pause.fill") {
            if isPaused {
                do {
                    try recorder.resumeFromPause()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                recorder.pause()
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(isPaused ? Theme.recording : nil)
        .alert("บันทึกต่อไม่ได้", isPresented: Binding { errorMessage != nil } set: { if !$0 { errorMessage = nil } }) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
