import Foundation

/// Prompt for questions across one or more meetings, handed to the Claude app like the summary prompt.
struct AskPromptBuilder {
    enum Template: String, CaseIterable, Identifiable, Sendable {
        case question, followUpEmail, compare, recurringTopics

        var id: Self { self }

        var label: String {
            switch self {
            case .question: "ถามคำถามเอง"
            case .followUpEmail: "ร่างอีเมลติดตามงาน"
            case .compare: "เปรียบเทียบการประชุม"
            case .recurringTopics: "หัวข้อที่พูดซ้ำหลายครั้ง"
            }
        }

        var systemImage: String {
            switch self {
            case .question: "questionmark.bubble"
            case .followUpEmail: "envelope"
            case .compare: "arrow.left.arrow.right"
            case .recurringTopics: "arrow.triangle.2.circlepath"
            }
        }

        var minimumMeetings: Int { self == .compare || self == .recurringTopics ? 2 : 1 }
    }

    struct Source {
        var title: String
        var date: Date
        /// Summary the user pasted earlier, if any.
        var summary: String?
        /// Transcript lines with times, plus the user's notes.
        var body: String
    }

    var sources: [Source]
    var template: Template
    var question: String
    var language: SummaryLanguage
    var glossary = ""
    var maxPartCharacters = ClaudePromptBuilder.defaultMaxPartCharacters

    func parts() -> [String] {
        ClaudePromptBuilder.assemble(header: instructions(), body: meetingsText(), tag: "meetings", ask: ask(), maxCharacters: maxPartCharacters)
    }

    private func meetingsText() -> String {
        sources.map { source in
            var text = "### \(source.title) — \(source.date.formatted(date: .long, time: .shortened))"
            if let summary = source.summary, !summary.isEmpty {
                text += "\nสรุปที่เคยทำไว้ (อาจมีข้อผิดพลาด ให้ยึด transcript เป็นหลัก):\n\(summary)"
            }
            return text + "\nTranscript:\n" + source.body
        }
        .joined(separator: "\n\n")
    }

    private func instructions() -> String {
        let languageRule = switch language {
        case .thai: "ตอบเป็นภาษาไทย"
        case .english: "Answer in English."
        case .followMeeting: "ตอบเป็นภาษาหลักที่ใช้ในการประชุม"
        }
        var rules = [
            "คุณช่วยตอบจากบันทึกการประชุม \(sources.count) รายการด้านล่าง",
            "ใช้เฉพาะข้อมูลในบันทึกเท่านั้น ห้ามแต่งเนื้อหา ชื่อคน มติ ผู้รับผิดชอบ หรือวันที่ ถ้าบันทึกไม่มีข้อมูลให้ตอบว่า “ไม่มีในบันทึก”",
            "transcript มาจากการถอดเสียงอัตโนมัติ อาจมีคำผิด ถ้าไม่แน่ใจให้บอกตรงๆ",
            "อ้างชื่อการประชุมและเวลา [ชม:นาที:วินาที] ทุกครั้งที่ใช้ข้อมูล เพื่อให้ตรวจสอบได้",
            languageRule,
            "คงชื่อเฉพาะและศัพท์เทคนิคตามต้นฉบับ",
        ] + ClaudePromptBuilder.annotationRules
        if let rule = ClaudePromptBuilder.glossaryRule(glossary) {
            rules.append(rule)
        }
        return rules.map { "- " + $0 }.joined(separator: "\n")
    }

    private func ask() -> String {
        let notSpecified = language == .english ? "Not specified" : "ไม่ระบุ"
        return switch template {
        case .question:
            "คำถาม: \(question.trimmingCharacters(in: .whitespacesAndNewlines))\nตอบให้ตรงคำถาม สั้นและชัด แล้วบอกว่าข้อมูลมาจากประชุมไหน เวลาเท่าไร"
        case .followUpEmail:
            "ร่างอีเมลติดตามงานหลังประชุม ภาษาสุภาพแบบที่ทำงาน มีหัวเรื่อง สรุปสั้น มติ และงานที่ต้องทำพร้อมผู้รับผิดชอบและกำหนดส่ง (เขียน “\(notSpecified)” ถ้าบันทึกไม่ได้บอก) ไม่ต้องใส่ชื่อผู้รับถ้าบันทึกไม่ได้บอก"
        case .compare:
            "เปรียบเทียบการประชุมเหล่านี้ตามลำดับเวลา: อะไรเปลี่ยนไป, มติที่ขัดกันหรือถูกแก้, งานที่ค้างมาจากครั้งก่อนและสถานะล่าสุด ใช้หัวข้อ Markdown ## สำหรับแต่ละประเด็น"
        case .recurringTopics:
            "หาหัวข้อที่ถูกพูดถึงในหลายการประชุม แต่ละหัวข้อบอก: ประชุมไหนบ้าง (ชื่อ + เวลา), สรุปสิ่งที่พูด, และสถานะล่าสุด ใช้หัวข้อ Markdown ## ต่อหนึ่งหัวข้อ"
        }
    }
}
