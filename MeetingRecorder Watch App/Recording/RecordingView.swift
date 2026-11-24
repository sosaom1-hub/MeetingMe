import SwiftUI

struct RecordingView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var markerCount: Int { recorder.manifest?.markers.count ?? 0 }

    private var elapsedText: String {
        // Wrist down / Always-On: no per-second updates.
        let pattern: Duration.TimeFormatStyle.Pattern = isLuminanceReduced ? .hourMinute : .hourMinuteSecond
        return Duration.seconds(recorder.elapsed).formatted(.time(pattern: pattern))
    }

    var body: some View {
        VStack {
            HStack {
                RecordingDot()
                Spacer()
                if markerCount > 0 {
                    Label("\(markerCount)", systemImage: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("จุดสำคัญ \(markerCount) จุด")
                }
            }

            Text(elapsedText)
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel("บันทึกไปแล้ว \(elapsedText)")

            if !isLuminanceReduced {
                LevelMeter(level: recorder.level)
            }

            Spacer(minLength: 0)

            GlassEffectContainer {
                HStack {
                    Button("จุดสำคัญ", systemImage: "star.fill", action: recorder.addMarker)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)

                    Button("หยุด", systemImage: "stop.fill", action: recorder.stop)
                        .buttonStyle(.glassProminent)
                        .tint(Theme.recording)
                        .frame(maxWidth: .infinity)
                        .handGestureShortcut(.primaryAction)
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact, trigger: markerCount)
    }
}
