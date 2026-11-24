import SwiftUI

/// Full-screen recording on iPhone: same engine and look as the Watch, scaled up.
struct PhoneRecordingView: View {
    @Environment(ChunkedRecorder.self) private var recorder
    @ScaledMetric(relativeTo: .largeTitle) private var timerSize = 72.0

    @State private var noteTime: TimeInterval?
    @State private var noteText = ""

    private var markerCount: Int { recorder.manifest?.markers.count ?? 0 }
    private var noteCount: Int { recorder.manifest?.notes?.count ?? 0 }

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

            RecordingHealthLine(isSilent: recorder.isSilent, hoursLeft: recorder.hoursLeft)
                .sensoryFeedback(trigger: recorder.isSilent) { _, silent in silent ? .warning : nil }

            HStack {
                if markerCount > 0 {
                    Label("\(markerCount) จุดสำคัญ", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                }
                if noteCount > 0 {
                    Label("\(noteCount) โน้ต", systemImage: "note.text")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("ล็อกจอได้ การบันทึกจะทำงานต่อ")
                .font(.footnote)
                .foregroundStyle(.secondary)

            GlassEffectContainer {
                HStack {
                    Button("จุดสำคัญ", systemImage: "star.fill", action: recorder.addMarker)
                        .buttonStyle(.glass)

                    Button("โน้ต", systemImage: "note.text.badge.plus") {
                        // The note belongs to the moment the user decided to write it, not when they finish typing.
                        noteTime = recorder.elapsed
                    }
                    .buttonStyle(.glass)

                    Button("หยุดบันทึก", systemImage: "stop.fill", action: recorder.stop)
                        .buttonStyle(.glassProminent)
                        .tint(Theme.recording)
                }
                .controlSize(.extraLarge)
            }
        }
        .padding()
        .sheet(isPresented: Binding { noteTime != nil } set: { if !$0 { noteTime = nil } }) {
            NavigationStack {
                Form {
                    TextField("พิมพ์โน้ต (การบันทึกยังทำงานต่อ)", text: $noteText, axis: .vertical)
                        .lineLimit(3...8)
                }
                .navigationTitle("โน้ตที่ \(Duration.seconds(noteTime ?? 0).formatted(.time(pattern: .hourMinuteSecond)))")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("ยกเลิก", role: .cancel) { noteTime = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("บันทึกโน้ต") {
                            recorder.addNote(noteText, at: noteTime ?? recorder.elapsed)
                            noteText = ""
                            noteTime = nil
                        }
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
