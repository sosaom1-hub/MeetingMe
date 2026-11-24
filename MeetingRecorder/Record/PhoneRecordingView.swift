import SwiftUI

/// Full-screen recording on iPhone: same engine and look as the Watch, scaled up.
struct PhoneRecordingView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 72.0

    private var markerCount: Int { recorder.manifest?.markers.count ?? 0 }

    var body: some View {
        Group {
            switch recorder.phase {
            case .recording:
                recording
            case .stopped(let status):
                StoppedView(status: status)
            case .idle:
                Color.clear
            }
        }
        .sensoryFeedback(.impact, trigger: markerCount)
        .sensoryFeedback(trigger: recorder.phase) { _, newPhase in
            switch newPhase {
            case .recording: .start
            case .stopped(.interrupted): .warning
            case .stopped: .success
            case .idle: nil
            }
        }
    }

    private var recording: some View {
        VStack {
            RecordingDot()
                .font(.headline)

            Spacer()

            Text(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .hourMinuteSecond)))
                .font(.system(size: timerSize, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("บันทึกไปแล้ว \(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .hourMinuteSecond)))")

            LevelMeter(level: recorder.level)
                .scaleEffect(1.6)
                .padding(.vertical)

            if markerCount > 0 {
                Label("\(markerCount) จุดสำคัญ", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }

            Spacer()

            Text("ล็อกจอได้ การบันทึกจะทำงานต่อ")
                .font(.footnote)
                .foregroundStyle(.secondary)

            GlassEffectContainer {
                HStack {
                    Button("จุดสำคัญ", systemImage: "star.fill", action: recorder.addMarker)
                        .buttonStyle(.glass)

                    Button("หยุดบันทึก", systemImage: "stop.fill", action: recorder.stop)
                        .buttonStyle(.glassProminent)
                        .tint(Theme.recording)
                }
                .controlSize(.extraLarge)
            }
        }
        .padding()
    }
}
