import UIKit

/// A4 PDF laid out with TextKit (one text container per page), which shapes Thai vowels and tone marks
/// correctly and breaks Thai lines at word boundaries. Raw Core Text drawing detached the marks.
/// Every page has a footer "หน้า n / N"; pages after the first repeat the meeting title at the top.
enum PDFExporter {
    private static let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private static let margin: CGFloat = 56
    private static let headerHeight: CGFloat = 28
    private static let footerHeight: CGFloat = 28

    private static var contentRect: CGRect {
        CGRect(
            x: margin,
            y: margin + headerHeight,
            width: page.width - margin * 2,
            height: page.height - margin * 2 - headerHeight - footerHeight
        )
    }

    static func data(for document: ExportDocument) -> Data {
        let storage = NSTextStorage(attributedString: attributedBody(for: document))
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        // Pass 1: add page-sized containers until all text is laid out, so the footer can say "n / N".
        var pages: [NSRange] = []
        repeat {
            let container = NSTextContainer(size: contentRect.size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let range = layout.glyphRange(for: container)
            guard range.length > 0 || pages.isEmpty else { break }
            pages.append(range)
        } while NSMaxRange(pages[pages.count - 1]) < layout.numberOfGlyphs

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: document.title]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)

        // Pass 2: draw.
        return renderer.pdfData { context in
            for (index, range) in pages.enumerated() {
                context.beginPage()
                if index > 0 {
                    draw("\(document.title) · \(document.subtitle)", at: CGPoint(x: margin, y: margin), size: 9)
                }
                let footer = "หน้า \(index + 1) / \(pages.count)"
                let footerWidth = NSAttributedString(string: footer, attributes: [.font: UIFont.systemFont(ofSize: 9)]).size().width
                draw(footer, at: CGPoint(x: page.width - margin - footerWidth, y: page.height - margin - 12), size: 9)

                layout.drawBackground(forGlyphRange: range, at: contentRect.origin)
                layout.drawGlyphs(forGlyphRange: range, at: contentRect.origin)
            }
        }
    }

    private static func draw(_ text: String, at point: CGPoint, size: CGFloat) {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size),
            .foregroundColor: UIColor.darkGray,
        ]).draw(at: point)
    }

    static func attributedBody(for document: ExportDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()

        func style(spacingBefore: CGFloat = 0, after: CGFloat = 4, indent: CGFloat = 0, firstLine: CGFloat? = nil) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            style.paragraphSpacingBefore = spacingBefore
            style.paragraphSpacing = after
            style.headIndent = indent
            style.firstLineHeadIndent = firstLine ?? indent
            style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
            style.lineBreakMode = .byWordWrapping
            return style
        }

        func append(_ text: String, font: UIFont, color: UIColor = .black, paragraph: NSParagraphStyle) {
            result.append(NSAttributedString(string: text, attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]))
        }

        append(document.title + "\n", font: .boldSystemFont(ofSize: 20), paragraph: style(after: 4))
        append(document.subtitle + "\n", font: .systemFont(ofSize: 11), color: .darkGray, paragraph: style(after: 18))

        for block in document.blocks {
            switch block {
            case .heading(let text):
                append(text + "\n", font: .boldSystemFont(ofSize: 15), paragraph: style(spacingBefore: 14, after: 6))
            case .paragraph(let text):
                append(text + "\n", font: .systemFont(ofSize: 11), paragraph: style(after: 6))
            case .bullet(let text):
                append("•\t" + text + "\n", font: .systemFont(ofSize: 11), paragraph: style(after: 4, indent: 14, firstLine: 0))
            case .transcriptLine(let time, let text):
                let paragraph = style(after: 3, indent: 54, firstLine: 0)
                append(time + "\t", font: .monospacedDigitSystemFont(ofSize: 9, weight: .regular), color: .gray, paragraph: paragraph)
                append(text + "\n", font: .systemFont(ofSize: 11), paragraph: paragraph)
            }
        }
        return result
    }
}
