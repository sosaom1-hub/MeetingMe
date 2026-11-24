import Foundation

/// Builds the text the user hands to the Claude app. Summaries must stay grounded in the transcript:
/// no invented owners, deadlines, or decisions, and uncertainty is always reported.
struct ClaudePromptBuilder {
    /// Keeps each paste comfortably sized. Longer transcripts are split into numbered parts, never truncated.
    // shortcut: fixed size picked without a measured Claude-app paste limit; tune after real 3 h meetings.
    static let defaultMaxPartCharacters = 40_000

    var title: String
    var date: Date
    var transcript: String
    var outputs: Set<OutputKind>
    var language: SummaryLanguage
    /// User-supplied correct spellings, separated by new lines or commas.
    var glossary = ""
    var maxPartCharacters = defaultMaxPartCharacters

    func parts() -> [String] {
        let header = instructions()
        let ask = finalAsk()
        if header.count + transcript.count + ask.count <= maxPartCharacters {
            return [header + "\n\n<transcript>\n" + transcript + "\n</transcript>\n\n" + ask]
        }

        let budget = maxPartCharacters - header.count - ask.count - 400
        let pieces = Self.split(transcript, maxCharacters: max(budget, 1_000))
        let total = pieces.count
        return pieces.enumerated().map { offset, piece in
            let number = offset + 1
            var text = number == 1 ? header + "\n\n" : ""
            text += "ส่วนที่ \(number)/\(total) ของ transcript:\n<transcript part=\"\(number)/\(total)\">\n\(piece)\n</transcript>\n\n"
            text += number < total
                ? "ยังไม่ต้องสรุป ตอบเพียง “รับส่วนที่ \(number)/\(total) แล้ว” แล้วรอส่วนถัดไป"
                : "นี่คือส่วนสุดท้าย สรุปจากทุกส่วน (1–\(total)) รวมกัน ห้ามซ้ำงานหรือมติเดียวกัน และถ้าส่วนต่างๆ ขัดกันให้บอกในข้อที่ไม่แน่ใจ\n\n" + ask
            return text
        }
    }

    // MARK: Text

    var headings: [String] {
        let english = language == .english
        var result: [String] = []
        if outputs.contains(.summary) { result.append(english ? "Summary" : "สรุป") }
        if outputs.contains(.decisions) { result.append(english ? "Decisions" : "มติที่ประชุม") }
        if outputs.contains(.actionItems) { result.append(english ? "Action items" : "งานที่ต้องทำ") }
        result.append(english ? "Uncertain points" : "ข้อที่ไม่แน่ใจ")
        return result
    }

    private func instructions() -> String {
        let languageRule = switch language {
        case .thai: "ตอบเป็นภาษาไทย"
        case .english: "Answer in English."
        case .followMeeting: "ตอบเป็นภาษาหลักที่ใช้ในการประชุม ถ้าเป็นภาษาไทยให้ใช้หัวข้อภาษาไทยด้านล่าง ถ้าเป็นภาษาอังกฤษให้ใช้หัวข้อ Summary / Decisions / Action items / Uncertain points"
        }
        let notSpecified = language == .english ? "Not specified" : "ไม่ระบุ"
        var rules = [
            "คุณช่วยสรุปการประชุม “\(title)” วันที่ \(date.formatted(date: .long, time: .shortened))",
            "ใช้เฉพาะข้อมูลใน transcript เท่านั้น ห้ามแต่งเนื้อหา ชื่อคน มติ ผู้รับผิดชอบ หรือวันที่ที่ไม่มีใน transcript",
            "transcript มาจากการถอดเสียงอัตโนมัติ อาจมีคำผิด โดยเฉพาะชื่อคนและคำภาษาอังกฤษ ถ้าไม่แน่ใจให้เขียนไว้ในหัวข้อสุดท้าย",
            languageRule,
            "คงชื่อเฉพาะและศัพท์เทคนิคตามต้นฉบับ ไม่ต้องแปลชื่อคนหรือชื่อระบบ",
            "บรรทัดที่มี ⭐ คือจุดที่ผู้บันทึกกดไว้ว่าสำคัญระหว่างประชุม",
            "อ้างเวลา [ชม:นาที:วินาที] จาก transcript เมื่อช่วยให้ตรวจสอบได้",
        ]
        let terms = glossary
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !terms.isEmpty {
            rules.append("ชื่อคนและคำเฉพาะที่สะกดถูกต้อง: \(terms.joined(separator: ", ")) — ถ้าคำใน transcript ออกเสียงใกล้กับคำในรายการนี้ (เช่น “วิพา” กับ “วิภา” หรือ “ทีมอีก” กับ “ทีม IT”) ให้ใช้ตัวสะกดในรายการนี้ ห้ามใส่คำจากรายการนี้ถ้าไม่มีคำที่ออกเสียงใกล้เคียงใน transcript")
        }
        if outputs.contains(.actionItems) {
            rules.append("งานที่ต้องทำ: เขียนแต่ละข้อเป็น “- งาน — ผู้รับผิดชอบ: … — กำหนดส่ง: …” ถ้า transcript ไม่ได้บอกผู้รับผิดชอบหรือกำหนดส่ง ให้เขียน “\(notSpecified)” ห้ามเดา")
        }
        if outputs.contains(.decisions) {
            rules.append("มติที่ประชุม: ใส่เฉพาะสิ่งที่ที่ประชุมตกลงกันชัดเจน ถ้าไม่มีให้เขียน “- ไม่มีมติที่ชัดเจน”")
        }
        return rules.map { "- " + $0 }.joined(separator: "\n")
    }

    private func finalAsk() -> String {
        let list = headings.map { "## " + $0 }.joined(separator: "\n")
        return "ตอบโดยใช้หัวข้อ Markdown ต่อไปนี้เท่านั้น ตามลำดับนี้ และไม่มีข้อความอื่นก่อนหรือหลัง:\n\(list)"
    }

    /// Splits on line boundaries so no transcript line is cut in half.
    static func split(_ text: String, maxCharacters: Int) -> [String] {
        var parts: [String] = []
        var current = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if !current.isEmpty, current.count + line.count + 1 > maxCharacters {
                parts.append(current)
                current = ""
            }
            current += current.isEmpty ? String(line) : "\n" + line
        }
        if !current.isEmpty || parts.isEmpty {
            parts.append(current)
        }
        return parts
    }
}
