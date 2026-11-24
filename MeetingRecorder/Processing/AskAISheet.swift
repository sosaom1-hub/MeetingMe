import SwiftData
import SwiftUI
import UIKit

/// Ask Claude about one or more meetings. Like the summary, the app only prepares the text; the user shares it.
struct AskAISheet: View {
    var initialSelection: Set<UUID> = []

    @Query(sort: \Meeting.startedAt, order: .reverse) private var meetings: [Meeting]
    @AppStorage(AppSettings.glossary) private var glossary = ""
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<UUID> = []
    @State private var template = AskPromptBuilder.Template.question
    @State private var question = ""
    @State private var language = SummaryLanguage.thai
    @State private var copiedPart: Int?

    private var eligible: [Meeting] {
        meetings.filter { $0.sortedChunks.contains { $0.result != nil } }
    }

    private var selected: [Meeting] {
        eligible.filter { selection.contains($0.id) }.sorted { $0.startedAt < $1.startedAt }
    }

    private var isReady: Bool {
        selected.count >= template.minimumMeetings
            && (template != .question || !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var parts: [String] {
        guard isReady else { return [] }
        return AskPromptBuilder(
            sources: selected.map {
                .init(title: $0.title, date: $0.startedAt, summary: $0.summaryText, body: SummarySheet.promptBody(for: $0))
            },
            template: template,
            question: question,
            language: language,
            glossary: glossary
        ).parts()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("1 · ต้องการให้ช่วยอะไร") {
                    Picker("แบบ", selection: $template) {
                        ForEach(AskPromptBuilder.Template.allCases) { Label($0.label, systemImage: $0.systemImage).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if template == .question {
                        TextField("เช่น สรุปว่าเราตกลงเรื่องงบไว้อย่างไร", text: $question, axis: .vertical)
                            .lineLimit(2...5)
                    }
                    Picker("ภาษาของคำตอบ", selection: $language) {
                        ForEach(SummaryLanguage.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section {
                    if eligible.isEmpty {
                        Text("ยังไม่มีการประชุมที่ถอดเสียงแล้ว")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(eligible) { meeting in
                        Button {
                            if selection.contains(meeting.id) { selection.remove(meeting.id) } else { selection.insert(meeting.id) }
                        } label: {
                            HStack {
                                Image(systemName: selection.contains(meeting.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection.contains(meeting.id) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                VStack(alignment: .leading) {
                                    Text(meeting.title)
                                    Text(meeting.startedAt, format: .dateTime.day().month().year())
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        .accessibilityAddTraits(selection.contains(meeting.id) ? .isSelected : [])
                    }
                } header: {
                    Text("2 · เลือกการประชุม (\(selection.count))")
                } footer: {
                    if template.minimumMeetings > 1 {
                        Text("เลือกอย่างน้อย \(template.minimumMeetings) รายการ")
                    }
                }

                Section {
                    if parts.count > 1 {
                        Label("ข้อมูลยาว จึงแบ่งเป็น \(parts.count) ส่วน ส่งทีละส่วนตามลำดับในแชตเดียวกัน", systemImage: "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(parts.indices, id: \.self) { index in
                        partRow(index)
                    }
                } header: {
                    Text("3 · ส่งให้แอป Claude")
                } footer: {
                    Text("ข้อความรวม transcript และโน้ตของประชุมที่เลือก ส่งไปเฉพาะเมื่อคุณกดแชร์หรือคัดลอกเอง")
                }
            }
            .navigationTitle("ถาม AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .onAppear { selection = initialSelection }
        }
    }

    private func partRow(_ index: Int) -> some View {
        let title = parts.count == 1 ? "prompt พร้อมข้อมูล" : "ส่วนที่ \(index + 1)/\(parts.count)"
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
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            ShareLink(item: parts[index]) {
                Label("แชร์", systemImage: "square.and.arrow.up")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glassProminent)
        }
    }
}
