import SwiftUI

struct RecordingView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// Marker type chosen with the Digital Crown (index into `MarkerKind.allCases`).
    @State private var markerIndex = 0
    @AppStorage(WatchSettings.periodicHaptic) private var periodicHaptic = false

    private var markerCount: Int { recorder.markerCount }
    private var markerKind: MarkerKind { MarkerKind(rawValue: markerIndex) ?? .important }

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
                    Label("\(markerCount)", systemImage: "bookmark.fill")
                        .font(.footnote)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("ทำเครื่องหมายแล้ว \(markerCount) จุด")
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

            RecordingHealthLine(isSilent: recorder.isSilent, hoursLeft: recorder.hoursLeft)

            Spacer(minLength: 0)

            if !isLuminanceReduced {
                Label("หมุน Crown: \(markerKind.label)", systemImage: "digitalcrown.arrow.clockwise")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityHidden(true)
            }

            GlassEffectContainer {
                HStack {
                    Button {
                        recorder.addMarker(markerKind)
                    } label: {
                        Text(markerKind.emoji)
                            .font(.title3)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("ทำเครื่องหมาย \(markerKind.label)")
                    .accessibilityHint("หมุน Digital Crown เพื่อเปลี่ยนเป็น จุดสำคัญ งานที่ต้องทำ มติ หรือคำถาม")
                    .accessibilityAdjustableAction { direction in
                        let count = MarkerKind.allCases.count
                        markerIndex = (markerIndex + (direction == .increment ? 1 : count - 1)) % count
                    }

                    StopButton(action: recorder.stop)
                }
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
        .focusable()
        .digitalCrownRotation(
            detent: $markerIndex,
            from: 0,
            through: MarkerKind.allCases.count - 1,
            by: 1,
            sensitivity: .low,
            isContinuous: true
        )
        .sensoryFeedback(.impact, trigger: markerCount)
        .sensoryFeedback(.selection, trigger: markerIndex)
        .sensoryFeedback(trigger: recorder.isSilent) { _, silent in silent ? .warning : nil }
        // Optional reassurance that recording is still running: one light tap every 10 minutes.
        .sensoryFeedback(trigger: Int(recorder.elapsed / 600)) { _, block in
            periodicHaptic && block > 0 ? .impact(weight: .light) : nil
        }
    }
}
