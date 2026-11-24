import SwiftData
import SwiftUI

/// Transcript status, the start/retry control, and the transcript itself (tap a time to play from there).
struct TranscriptSection: View {
    let meeting: Meeting
    let player: ChunkPlayer

    @Environment(TranscriptionPipeline.self) private var pipeline
    @AppStorage(AppSettings.serverURL) private var serverURL = ""
    @AppStorage(AppSettings.transcriptLanguage) private var languageRaw = AppSettings.defaultLanguage
    @AppStorage(AppSettings.hasAcceptedUploadDisclosure) private var hasAcceptedDisclosure = false
    @AppStorage(AppSettings.audioRetention) private var retentionRaw = AudioRetention.keep.rawValue
    @Environment(\.modelContext) private var context
    @State private var isShowingDisclosure = false
    @State private var editing: EditingLine?

    struct EditingLine: Identifiable {
        let source: TranscriptLine.Source
        var text: String
        var id: TranscriptLine.Source { source }
    }

    private var chunks: [AudioChunk] { meeting.sortedChunks }
    private var doneCount: Int { chunks.count { $0.result != nil } }
    private var isComplete: Bool { !chunks.isEmpty && doneCount == chunks.count }
    private var isRunning: Bool { pipeline.isRunning(meeting) }

    private var lines: [TranscriptLine] {
        guard doneCount > 0 else { return [] }
        return TranscriptLine.build(chunks: chunks.map { ($0.duration, $0.result) }, markers: meeting.markers)
    }

    /// The line being played, for a subtle highlight.
    private var currentLineID: Int? {
        lines.last { $0.start <= player.currentTime && $0.kind != .marker }?.id
    }

    var body: some View {
        Section {
            status
            ForEach(lines) { line in
                row(for: line)
                    .listRowBackground(line.id == currentLineID && player.isPlaying ? Theme.recording.opacity(0.08) : nil)
            }
        } header: {
            Text("ถอดเสียง")
        } footer: {
            if isComplete {
                Text("ถอดเสียงด้วย OpenThai บนเครื่อง Mac ของคุณ ข้อความอาจผิดได้ โดยเฉพาะชื่อคนและคำเฉพาะ กดค้างที่บรรทัดเพื่อแก้ไข")
            }
        }
        .sheet(item: $editing) { line in
            EditLineSheet(original: line.text) { newText in
                MeetingStore(context: context).editTranscript(meeting, at: line.source, text: newText)
            }
        }
        .sheet(isPresented: $isShowingDisclosure) {
            UploadDisclosureSheet(serverURL: serverURL) {
                hasAcceptedDisclosure = true
                start()
            }
        }
    }

    @ContentBuilder private var status: some View {
        if isRunning {
            ProgressView(value: Double(doneCount), total: Double(max(chunks.count, 1))) {
                Text("กำลังถอดเสียง \(doneCount)/\(chunks.count) ส่วน")
            } currentValueLabel: {
                Text("ส่วนละประมาณ 1 นาที")
            }
        } else if !isComplete {
            notStartedOrStopped
        }
    }

    @ContentBuilder private var notStartedOrStopped: some View {
        switch meeting.state {
        case .recording, .transferring:
            Label("รอเสียงส่งมาจากนาฬิกาให้ครบก่อน", systemImage: "applewatch")
                .foregroundStyle(.secondary)
        default:
            VStack(alignment: .leading) {
                if case .waitingForServer = meeting.state {
                    Label(TranscriptionError.serverUnreachable.localizedDescription, systemImage: "desktopcomputer.trianglebadge.exclamationmark")
                        .foregroundStyle(Theme.warning)
                } else if case .failed(_, _, let reason, _) = meeting.state {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.warning)
                }
                if serverURL.isEmpty {
                    Text("ตั้งที่อยู่เครื่อง Mac ก่อน (ปุ่มเฟืองในหน้าคลังประชุม)")
                        .foregroundStyle(.secondary)
                }
                Button(doneCount > 0 ? "ถอดเสียงส่วนที่เหลือ" : "ถอดเสียง", systemImage: "waveform.badge.magnifyingglass", action: requestStart)
                    .buttonStyle(.glassProminent)
                    .disabled(serverURL.isEmpty)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }

    @ContentBuilder private func row(for line: TranscriptLine) -> some View {
        switch line.kind {
        case .speech(let text):
            HStack(alignment: .firstTextBaseline) {
                timeButton(line.start)
                Text(text)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .contextMenu {
                if let source = line.source {
                    Button("แก้ไขข้อความ", systemImage: "pencil") {
                        editing = EditingLine(source: source, text: text)
                    }
                }
            }
            .accessibilityAction(named: "แก้ไขข้อความ") {
                if let source = line.source {
                    editing = EditingLine(source: source, text: text)
                }
            }
        case .note(let text):
            HStack(alignment: .firstTextBaseline) {
                timeButton(line.start)
                Label(text, systemImage: "note.text")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("โน้ตของคุณ: \(text)")
            }
        case .marker:
            HStack {
                timeButton(line.start)
                Label("จุดสำคัญ", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
            }
        case .pending(let number):
            HStack {
                timeButton(line.start)
                Text("ส่วนที่ \(number) ยังไม่ได้ถอดเสียง")
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    private func timeButton(_ start: TimeInterval) -> some View {
        Button(Duration.seconds(start).formatted(.time(pattern: .hourMinuteSecond))) {
            player.seek(to: start)
            if !player.isPlaying {
                player.togglePlay()
            }
        }
        .font(.footnote)
        .monospacedDigit()
        .buttonStyle(.borderless)
        .accessibilityLabel("เล่นจาก \(Duration.seconds(start).formatted(.time(pattern: .hourMinuteSecond)))")
    }

    private func requestStart() {
        if hasAcceptedDisclosure {
            start()
        } else {
            isShowingDisclosure = true
        }
    }

    private func start() {
        guard let provider = MacASRProvider(string: serverURL) else {
            meeting.state = .failed(step: .transcription, chunk: nil, reason: TranscriptionError.invalidServerURL.localizedDescription, retryable: true)
            return
        }
        let language = TranscriptLanguage(rawValue: languageRaw) ?? .thaiMixed
        let deleteAudio = retentionRaw == AudioRetention.deleteAfterTranscript.rawValue
        Task {
            await pipeline.run(meeting, provider: provider, language: language)
            if deleteAudio {
                MeetingStore(context: context).deleteAudioIfFullyTranscribed(meeting)
            }
        }
    }
}
