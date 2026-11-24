import SwiftUI
import UIKit

/// Three steps on one screen: choose outputs → send the prompt to the Claude app → paste the answer back.
/// Nothing is sent anywhere by this app; the user shares the prompt themselves.
struct SummarySheet: View {
    @Bindable var meeting: Meeting

    @AppStorage(AppSettings.defaultOutputs) private var defaultOutputsRaw = AppSettings.defaultOutputsValue
    @AppStorage(AppSettings.glossary) private var glossary = ""
    @Environment(\.dismiss) private var dismiss

    @State private var outputs: Set<OutputKind> = []
    @State private var language = SummaryLanguage.thai
    @State private var pasted = ""
    @State private var copiedPart: Int?

    private var parts: [String] {
        ClaudePromptBuilder(
            title: meeting.title,
            date: meeting.startedAt,
            transcript: TranscriptLine.plainText(meeting.transcriptLines),
            outputs: outputs,
            language: language,
            glossary: glossary
        ).parts()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                    if parts.count > 1 {
                        Label("transcript ยาว จึงแบ่งเป็น \(parts.count) ส่วน ส่งให้ Claude ทีละส่วนตามลำดับในแชตเดียวกัน", systemImage: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(parts.indices, id: \.self) { index in
                        partRow(index)
                    }
                } header: {
                    Text("2 · ส่งให้แอป Claude")
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

    private func markSent() {
        if meeting.summaryText == nil {
            meeting.state = .awaitingSummaryPaste
        }
    }

    private func save() {
        meeting.summaryText = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        meeting.summaryPastedAt = .now
        meeting.state = .summaryReady
        try? meeting.modelContext?.save()
        dismiss()
    }
}
