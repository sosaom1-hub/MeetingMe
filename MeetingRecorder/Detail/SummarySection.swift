import SwiftUI

/// Results pasted back from Claude, one card per heading. Labelled clearly as Claude output the user pasted.
struct SummarySection: View {
    let meeting: Meeting
    let onEdit: () -> Void

    var body: some View {
        Section {
            if let text = meeting.summaryText {
                ForEach(SummaryParser.parse(text)) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(section.title, systemImage: section.kind.systemImage)
                            .font(.headline)
                            .foregroundStyle(section.kind == .uncertain ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.primary))
                        Text(Self.markdown(section.body))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Button("สรุปด้วย Claude", systemImage: "sparkles", action: onEdit)
                    .buttonStyle(.glassProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(!meeting.hasFullTranscript)
                if !meeting.hasFullTranscript {
                    Text("ถอดเสียงให้ครบทุกส่วนก่อน")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("ผลสรุป")
                Spacer()
                if meeting.summaryText != nil {
                    Button("แก้ไข", action: onEdit)
                        .font(.subheadline)
                }
            }
        } footer: {
            if let date = meeting.summaryPastedAt {
                Text("สรุปโดย Claude (วางเอง) · \(date.formatted(date: .abbreviated, time: .shortened)) · ตรวจกับ transcript ก่อนใช้งาน")
            }
        }
    }

    /// Renders bold, italics and links; keeps line breaks and list markers as typed.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}
