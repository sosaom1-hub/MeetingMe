import SwiftUI
import UIKit

/// Three steps on one screen: choose outputs → send the prompt to Claude → review and save the answer.
/// Sending is always the user's tap: either via the user's Mac (`/v1/claude`, their own Claude login), or by sharing
/// the prompt to the Claude app and pasting the answer back.
struct SummarySheet: View {
    @Bindable var meeting: Meeting

    @AppStorage(AppSettings.defaultOutputs) private var defaultOutputsRaw = AppSettings.defaultOutputsValue
    @AppStorage(AppSettings.glossary) private var glossary = ""
    @Environment(\.dismiss) private var dismiss

    @State private var outputs: Set<OutputKind> = []
    @State private var language = SummaryLanguage.thai
    @State private var pasted = ""
    @State private var copiedPart: Int?
    @AppStorage(AppSettings.serverURL) private var serverURL = ""
    @State private var isAsking = false
    @State private var askError: String?

    /// One Mac request is one `claude -p` run with no chat history, so the whole transcript must fit in one prompt.
    /// Stays under the server's 400,000-character limit.
    static let macPromptLimit = 380_000

    private var parts: [String] { prompt(maxPartCharacters: ClaudePromptBuilder.defaultMaxPartCharacters) }

    private func prompt(maxPartCharacters: Int) -> [String] {
        ClaudePromptBuilder(
            title: meeting.title,
            date: meeting.startedAt,
            transcript: Self.promptBody(for: meeting),
            outputs: outputs,
            language: language,
            glossary: glossary,
            recordingType: meeting.recordingType,
            maxPartCharacters: maxPartCharacters
        ).parts()
    }

    /// Transcript lines, then the user's free-text notes marked as theirs.
    static func promptBody(for meeting: Meeting) -> String {
        let transcript = TranscriptLine.plainText(meeting.transcriptLines)
        let notes = meeting.myNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? transcript : transcript + "\n\n📝 โน้ตเพิ่มเติมของผู้บันทึก (ไม่ใช่คำพูดในห้อง):\n" + notes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("ประเภท", selection: $meeting.recordingTypeRaw) {
                        ForEach(RecordingType.allCases) { type in
                            Label(type.label, systemImage: type.systemImage).tag(type.rawValue)
                        }
                    }
                    ForEach(OutputKind.allCases) { kind in
                        Toggle(isOn: binding(for: kind)) {
                            Label(kind.label, systemImage: kind.systemImage)
                        }
                    }
                    Picker("ภาษาของผลสรุป", selection: $language) {
                        ForEach(SummaryLanguage.allCases) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("1 · เลือกสิ่งที่ต้องการ")
                } footer: {
                    Text("ทุกครั้งจะมี “ข้อที่ไม่แน่ใจ” ด้วย Claude จะไม่เดาผู้รับผิดชอบหรือวันที่ ถ้าในประชุมไม่ได้พูดไว้จะเขียนว่า “ไม่ระบุ”")
                }

                Section {
                    Button(action: askMac) {
                        if isAsking {
                            Label("Claude กำลังสรุป…", systemImage: "hourglass")
                        } else {
                            Label("ให้ Claude บน Mac สรุปเลย", systemImage: "desktopcomputer")
                        }
                    }
                    .disabled(serverURL.isEmpty || isAsking)
                    if isAsking {
                        ProgressView()
                    }
                    if let askError {
                        Label(askError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)
                    }
                } header: {
                    Text("2 · ส่งให้ Claude")
                } footer: {
                    Text(serverURL.isEmpty
                         ? "ตั้งที่อยู่เครื่อง Mac ในหน้าตั้งค่าก่อน หรือใช้การคัดลอกด้านล่าง"
                         : "Mac ของคุณส่ง transcript ไปให้ Claude ด้วยบัญชี Claude ที่ login ไว้บน Mac ไม่ต้องคัดลอก ผลจะมาอยู่ในช่องข้อ 3 ให้ตรวจก่อนบันทึก")
                }
                .disabled(outputs.isEmpty)

                Section {
                    if parts.count > 1 {
                        Label("transcript ยาว จึงแบ่งเป็น \(parts.count) ส่วน ส่งให้ Claude ทีละส่วนตามลำดับในแชตเดียวกัน", systemImage: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(parts.indices, id: \.self) { index in
                        partRow(index)
                    }
                } header: {
                    Text("หรือส่งเองผ่านแอป Claude")
                } footer: {
                    Text("กดแชร์แล้วเลือกแอป Claude หรือคัดลอกไปวางในแชตใหม่ ข้อความรวม transcript ของประชุมนี้")
                }
                .disabled(outputs.isEmpty)

                Section {
                    PasteButton(payloadType: String.self) { strings in
                        pasted = strings.joined(separator: "\n")
                    }
                    TextEditor(text: $pasted)
                        .frame(minHeight: 160)
                        .overlay(alignment: .topLeading) {
                            if pasted.isEmpty {
                                Text("วางคำตอบจาก Claude ที่นี่")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("3 · วางผลสรุปกลับมา")
                }
            }
            .navigationTitle("สรุปด้วย Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึกผลสรุป", action: save)
                        .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func partRow(_ index: Int) -> some View {
        let title = parts.count == 1 ? "prompt พร้อม transcript" : "ส่วนที่ \(index + 1)/\(parts.count)"
        return HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text("\(parts[index].count.formatted()) ตัวอักษร")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(copiedPart == index ? "คัดลอกแล้ว" : "คัดลอก", systemImage: copiedPart == index ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = parts[index]
                copiedPart = index
                markSent()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            ShareLink(item: parts[index], subject: Text(meeting.title)) {
                Label("แชร์", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glassProminent)
            .simultaneousGesture(TapGesture().onEnded(markSent))
        }
    }

    private func binding(for kind: OutputKind) -> Binding<Bool> {
        Binding {
            outputs.contains(kind)
        } set: { isOn in
            if isOn { outputs.insert(kind) } else { outputs.remove(kind) }
            defaultOutputsRaw = OutputKind.encode(outputs)
        }
    }

    private func load() {
        outputs = OutputKind.decode(defaultOutputsRaw)
        pasted = meeting.summaryText ?? ""
    }

    private func askMac() {
        guard let provider = MacASRProvider(string: serverURL) else {
            askError = TranscriptionError.invalidServerURL.localizedDescription
            return
        }
        let prompts = prompt(maxPartCharacters: Self.macPromptLimit)
        guard prompts.count == 1, let text = prompts.first else {
            askError = "transcript ยาวเกินจะส่งในครั้งเดียว ใช้การคัดลอกทีละส่วนด้านล่างแทน"
            return
        }
        askError = nil
        isAsking = true
        markSent()
        Task {
            do {
                pasted = try await provider.askClaude(prompt: text)
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }

    private func markSent() {
        if meeting.summaryText == nil {
            meeting.state = .awaitingSummaryPaste
        }
    }

    private func save() {
        meeting.summaryText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        meeting.summaryPastedAt = .now
        meeting.state = .summaryReady
        meeting.refreshSearchText()
        try? meeting.modelContext?.save()
        dismiss()
    }
}
