import Foundation
import PDFKit
import Testing
@testable import MeetingRecorder

struct PromptBuilderTests {
    private func builder(_ transcript: String, outputs: Set<OutputKind> = Set(OutputKind.allCases), language: SummaryLanguage = .thai, max: Int = 40_000) -> ClaudePromptBuilder {
        ClaudePromptBuilder(title: "ประชุมงบ", date: Date(timeIntervalSince1970: 1_800_000_000), transcript: transcript, outputs: outputs, language: language, maxPartCharacters: max)
    }

    @Test func shortTranscriptIsOnePromptWithGroundingRules() throws {
        let parts = builder("[0:00:01] สวัสดี").parts()

        let prompt = try #require(parts.first)
        #expect(parts.count == 1)
        #expect(prompt.contains("[0:00:01] สวัสดี"))
        #expect(prompt.contains("ห้ามแต่งเนื้อหา"))
        #expect(prompt.contains("“ไม่ระบุ”"))
        #expect(prompt.contains("## สรุป\n## มติที่ประชุม\n## งานที่ต้องทำ\n## ข้อที่ไม่แน่ใจ"))
    }

    @Test func onlySelectedOutputsBecomeHeadings() {
        let headings = builder("x", outputs: [.decisions], language: .english).headings
        #expect(headings == ["Decisions", "Uncertain points"])
    }

    @Test func englishUsesNotSpecified() throws {
        let prompt = try #require(builder("x", outputs: [.actionItems], language: .english).parts().first)
        #expect(prompt.contains("“Not specified”"))
    }

    @Test func longTranscriptSplitsWithoutLosingOrCuttingLines() {
        let lines = (0..<600).map { "[0:\(String(format: "%02d", $0 / 60)):\(String(format: "%02d", $0 % 60))] ประโยคที่ \($0) ของการประชุมยาว" }
        let transcript = lines.joined(separator: "\n")

        let parts = builder(transcript, max: 8_000).parts()

        #expect(parts.count > 1)
        #expect(parts.allSatisfy { $0.count <= 8_000 })
        #expect(parts.first?.contains("ห้ามแต่งเนื้อหา") == true)
        #expect(parts.last?.contains("## ข้อที่ไม่แน่ใจ") == true)
        #expect(parts.dropLast().allSatisfy { $0.contains("ยังไม่ต้องสรุป") })
        let rejoined = parts.flatMap { $0.split(separator: "\n").map(String.init) }.filter { $0.hasPrefix("[0:") }
        #expect(rejoined == lines)
    }
}

struct SummaryParserTests {
    @Test func splitsThaiHeadings() {
        let text = """
        ## สรุป
        ประชุมเรื่องงบประมาณ
        ## มติที่ประชุม
        - ย้ายไป Teams
        ## งานที่ต้องทำ
        - ส่งรายงาน — ผู้รับผิดชอบ: คุณสมชาย — กำหนดส่ง: วันศุกร์
        ## ข้อที่ไม่แน่ใจ
        - ชื่อ “วิพา” อาจเป็น “วิภา”
        """

        let sections = SummaryParser.parse(text)

        #expect(sections.map(\.title) == ["สรุป", "มติที่ประชุม", "งานที่ต้องทำ", "ข้อที่ไม่แน่ใจ"])
        #expect(sections.map(\.kind) == [.summary, .decisions, .actionItems, .uncertain])
        #expect(sections[2].body.contains("คุณสมชาย"))
    }

    @Test func acceptsEnglishAndBoldHeadingsAndKeepsPreamble() {
        let sections = SummaryParser.parse("Here you go:\n**Summary**\nBudget.\n# Action items\n- Send report")

        #expect(sections.map(\.title) == ["หมายเหตุ", "Summary", "Action items"])
        #expect(sections.map(\.kind) == [.other, .summary, .actionItems])
    }

    @Test func textWithoutHeadingsIsKeptWhole() {
        let sections = SummaryParser.parse("แค่ข้อความธรรมดา\nสองบรรทัด")
        #expect(sections.count == 1)
        #expect(sections.first?.body == "แค่ข้อความธรรมดา\nสองบรรทัด")
    }
}

struct ExportTests {
    let document = ExportDocument(
        title: "ประชุมงบประมาณ Q1 & แผน <IT>",
        subtitle: "24 พฤศจิกายน 2569 · ความยาว 1:02:37",
        blocks: [.heading("สรุป"), .paragraph("ที่ประชุมตกลงย้ายระบบไป Microsoft Teams")]
            + ExportDocument.bodyBlocks("- ส่งรายงาน — ผู้รับผิดชอบ: **คุณสมชาย** — กำหนดส่ง: ไม่ระบุ")
            + [.heading("Transcript")]
            + (0..<400).map { .transcriptLine(time: "0:\(String(format: "%02d", $0 / 60)):\(String(format: "%02d", $0 % 60))", text: "ฝ่ายการตลาดเสนอให้เพิ่มงบโฆษณาออนไลน์ร้อยละสิบ และคุณวิภาจะประสานงานกับผู้ขายเพื่อนัดประชุมครั้งถัดไปในวันอังคารหน้า") }
    )

    /// Exports also land in build/test-exports so they can be opened in Pages, Word, and Preview.
    private func keep(_ url: URL) {
        let folder = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "build/test-exports")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appending(path: url.lastPathComponent)
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.copyItem(at: url, to: target)
    }

    @Test func bulletsLoseMarkdownMarkers() {
        #expect(ExportDocument.bodyBlocks("- งาน **A**\nย่อหน้า") == [.bullet("งาน A"), .paragraph("ย่อหน้า")])
    }

    @Test func textExportContainsEverything() throws {
        let text = TextExporter.text(for: document)
        #expect(text.hasPrefix("ประชุมงบประมาณ Q1 & แผน <IT>\n"))
        #expect(text.contains("• ส่งรายงาน — ผู้รับผิดชอบ: คุณสมชาย — กำหนดส่ง: ไม่ระบุ"))
        #expect(text.contains("[0:06:39] ฝ่ายการตลาด"))
        keep(try document.write(as: .txt))
    }

    @Test func docxIsAZipWithEscapedXML() throws {
        let data = DocxExporter.data(for: document)

        #expect(data.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
        #expect(data.suffix(22).prefix(4) == Data([0x50, 0x4B, 0x05, 0x06]))
        let body = DocxExporter.body(for: document)
        #expect(body.contains("Q1 &amp; แผน &lt;IT&gt;"))
        #expect(body.contains("<w:pStyle w:val=\"Heading1\"/>"))
        keep(try document.write(as: .docx))
    }

    @Test func crc32MatchesKnownValue() {
        #expect(ZipWriter.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    }

    @Test func pdfPaginatesLongThaiTranscript() throws {
        let url = try document.write(as: .pdf)
        let pdf = try #require(PDFDocument(url: url))

        #expect(pdf.pageCount > 3)
        let lastPage = try #require(pdf.page(at: pdf.pageCount - 1)?.string)
        #expect(lastPage.contains("หน้า \(pdf.pageCount) / \(pdf.pageCount)"))
        #expect(pdf.string?.contains("วันอังคารหน้า") == true)
        keep(url)
    }
}
