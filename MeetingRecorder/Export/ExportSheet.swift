import SwiftUI

/// Pick a format and the sections to include; the file is rebuilt whenever the choice changes,
/// then saved or shared through the system share sheet.
struct ExportSheet: View {
    let meeting: Meeting

    @Environment(\.dismiss) private var dismiss
    @State private var format = ExportFormat.pdf
    @State private var includedSections: Set<Int> = []
    @State private var includeTranscript = true
    @State private var fileURL: URL?
    @State private var errorMessage: String?

    private struct Options: Hashable {
        let format: ExportFormat
        let sections: Set<Int>
        let transcript: Bool
    }

    private var sections: [SummaryParser.Section] {
        meeting.summaryText.map(SummaryParser.parse) ?? []
    }

    private var hasContent: Bool { includeTranscript || !includedSections.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("รูปแบบไฟล์") {
                    Picker("รูปแบบไฟล์", selection: $format) {
                        ForEach(ExportFormat.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    ForEach(sections) { section in
                        Toggle(isOn: Binding {
                            includedSections.contains(section.id)
                        } set: { isOn in
                            if isOn { includedSections.insert(section.id) } else { includedSections.remove(section.id) }
                        }) {
                            Label(section.title, systemImage: section.kind.systemImage)
                        }
                    }
                    Toggle(isOn: $includeTranscript) {
                        Label("Transcript พร้อมเวลา", systemImage: "text.quote")
                    }
                    .disabled(meeting.transcriptLines.isEmpty)
                } header: {
                    Text("เนื้อหา")
                } footer: {
                    if sections.isEmpty {
                        Text("ยังไม่มีผลสรุป ส่งออกได้เฉพาะ transcript")
                    }
                }

                Section {
                    if !hasContent {
                        Text("เลือกเนื้อหาอย่างน้อย 1 อย่าง")
                            .foregroundStyle(.secondary)
                    } else if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("แชร์หรือบันทึก \(fileURL.lastPathComponent)", systemImage: "square.and.arrow.up")
                        }
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Theme.warning)
                    } else {
                        ProgressView("กำลังสร้างไฟล์…")
                    }
                }
            }
            .navigationTitle("ส่งออก")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .onAppear {
                includedSections = Set(sections.map(\.id))
                includeTranscript = !meeting.transcriptLines.isEmpty
            }
            .task(id: Options(format: format, sections: includedSections, transcript: includeTranscript)) {
                generate()
            }
        }
    }

    private func generate() {
        fileURL = nil
        errorMessage = nil
        guard hasContent else { return }
        let document = ExportDocument.make(meeting: meeting, sections: includedSections, includeTranscript: includeTranscript)
        do {
            fileURL = try document.write(as: format)
        } catch {
            errorMessage = "สร้างไฟล์ไม่ได้: \(error.localizedDescription)"
        }
    }
}
