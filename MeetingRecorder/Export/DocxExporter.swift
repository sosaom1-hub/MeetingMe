import Foundation

/// Genuine Office Open XML (.docx): document, styles, and relationships, packed with `ZipWriter`.
/// Thai is set as the complex-script language so Word picks a Thai font and breaks lines correctly.
enum DocxExporter {
    static func data(for document: ExportDocument) -> Data {
        ZipWriter.archive([
            .init(path: "[Content_Types].xml", data: Data(contentTypes.utf8)),
            .init(path: "_rels/.rels", data: Data(rootRelationships.utf8)),
            .init(path: "word/_rels/document.xml.rels", data: Data(documentRelationships.utf8)),
            .init(path: "word/styles.xml", data: Data(styles.utf8)),
            .init(path: "word/document.xml", data: Data(body(for: document).utf8)),
        ])
    }

    static func body(for document: ExportDocument) -> String {
        var paragraphs = [
            paragraph(style: "Title", runs: [run(document.title)]),
            paragraph(style: "Subtitle", runs: [run(document.subtitle)]),
        ]
        for block in document.blocks {
            switch block {
            case .heading(let text):
                paragraphs.append(paragraph(style: "Heading1", runs: [run(text)]))
            case .paragraph(let text):
                paragraphs.append(paragraph(style: nil, runs: [run(text)]))
            case .bullet(let text):
                paragraphs.append(paragraph(style: "ListBullet", runs: [run("•\t" + text)]))
            case .transcriptLine(let time, let text):
                paragraphs.append(paragraph(style: "Transcript", runs: [run(time, color: "7A7A7A"), "<w:r><w:tab/></w:r>", run(text)]))
            }
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>\(paragraphs.joined())<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="709" w:footer="709" w:gutter="0"/></w:sectPr></w:body></w:document>
        """
    }

    private static func paragraph(style: String?, runs: [String]) -> String {
        let properties = style.map { "<w:pPr><w:pStyle w:val=\"\($0)\"/></w:pPr>" } ?? ""
        return "<w:p>\(properties)\(runs.joined())</w:p>"
    }

    private static func run(_ text: String, color: String? = nil) -> String {
        let properties = color.map { "<w:rPr><w:color w:val=\"\($0)\"/></w:rPr>" } ?? ""
        return "<w:r>\(properties)<w:t xml:space=\"preserve\">\(escape(text))</w:t></w:r>"
    }

    static func escape(_ text: String) -> String {
        text.replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
            .replacing("\"", with: "&quot;")
            .filter { $0 == "\t" || $0 == "\n" || !($0.asciiValue.map { $0 < 0x20 } ?? false) }
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>
    """

    private static let rootRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
    """

    private static let documentRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
    """

    private static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\
    <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Helvetica Neue" w:hAnsi="Helvetica Neue" w:cs="Tahoma"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="th-TH" w:bidi="th-TH"/></w:rPr></w:rPrDefault>\
    <w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>\
    <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>\
    <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:bCs/><w:sz w:val="40"/><w:szCs w:val="40"/></w:rPr></w:style>\
    <w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="360"/></w:pPr><w:rPr><w:color w:val="666666"/></w:rPr></w:style>\
    <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:bCs/><w:sz w:val="30"/><w:szCs w:val="30"/></w:rPr></w:style>\
    <w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="List Bullet"/><w:basedOn w:val="Normal"/><w:pPr><w:tabs><w:tab w:val="left" w:pos="360"/></w:tabs><w:ind w:left="360" w:hanging="360"/></w:pPr></w:style>\
    <w:style w:type="paragraph" w:styleId="Transcript"><w:name w:val="Transcript"/><w:basedOn w:val="Normal"/><w:pPr><w:tabs><w:tab w:val="left" w:pos="1080"/></w:tabs><w:ind w:left="1080" w:hanging="1080"/><w:spacing w:after="60"/></w:pPr></w:style>\
    </w:styles>
    """
}
