import SwiftUI

/// After a recording ends: a short confirmation, or an honest interruption notice with a resume option.
struct StoppedView: View {
    let status: RecordingManifest.Status

    @Environment(ChunkedRecorder.self) private var recorder
    @State private var errorMessage: String?

    private var isInterrupted: Bool { status == .interrupted }
    private var durationText: String {
        Duration.seconds(recorder.manifest?.totalDuration ?? 0).formatted(.time(pattern: .hourMinuteSecond))
    }
    private var chunkCount: Int { recorder.manifest?.chunks.count ?? 0 }

    var body: some View {
        ScrollView {
            VStack {
                Image(systemName: isInterrupted ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(isInterrupted ? Theme.warning : Theme.success)
                    .symbolEffect(.bounce, value: status)
                    .accessibilityHidden(true)

                Text(isInterrupted ? "การบันทึกหยุดกลางคัน" : "บันทึกแล้ว")
                    .font(.headline)

                if let reason = recorder.stopReason {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("เก็บเสียงไว้แล้ว \(durationText) · \(chunkCount) ส่วน")
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                if recorder.markerCount > 0 {
                    Label("\(recorder.markerCount) เครื่องหมาย", systemImage: "bookmark.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                }

                #if os(watchOS)
                AfterStopDetails()
                #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }

                if isInterrupted {
                    Button("บันทึกต่อ", systemImage: "mic.fill", action: resume)
                        .buttonStyle(.glassProminent)
                        .tint(Theme.recording)
                    Button("จบการบันทึก", action: recorder.reset)
                        .buttonStyle(.glass)
                } else {
                    Button("เสร็จ", action: recorder.reset)
                        .buttonStyle(.glass)
                }
            }
        }
        .task(id: status) {
            #if os(watchOS)
            return // The Watch shows title/type/playback here, so it waits for "เสร็จ".
            #else
            guard !isInterrupted else { return }
            try? await Task.sleep(for: .seconds(Theme.savedSummarySeconds))
            recorder.reset()
            #endif
        }
    }

    private func resume() {
        do {
            try recorder.resume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
