import CoreImage
import UIKit

enum PosSlipPdf {
    private static let pageWidth: CGFloat = 227
    private static let adFactura = "https://factura.dateconta.ro"
    private static let adBeauty = "https://www.beautymanager.net"

    struct Row {
        var left: String
        var right: String = ""
        var size: CGFloat = 8
        var bold = false
        var center = false
        var columns: [String] = []
        var qr: String = ""
        var qrLeft: String = ""
        var qrRight: String = ""

        static func title(_ text: String) -> Row { Row(left: text, size: 10, bold: true, center: true) }
        static func center(_ text: String, size: CGFloat = 8) -> Row { Row(left: text, size: size, center: true) }
        static func line(_ text: String, size: CGFloat = 8, bold: Bool = false) -> Row { Row(left: text, size: size, bold: bold) }
        static func pair(_ left: String, _ right: String, bold: Bool = false) -> Row { Row(left: left, right: right, bold: bold) }
        static func cells(_ values: [String], size: CGFloat = 7) -> Row { Row(left: "", size: size, columns: values) }
        static func qr(_ text: String) -> Row { Row(left: "", qr: text, qrLeft: adFactura, qrRight: adBeauty) }
    }

    static func make(_ rows: [Row]) -> Data {
        let margin: CGFloat = 8
        let contentWidth = pageWidth - margin * 2
        let prepared = rows.flatMap { wrap($0, width: contentWidth) }
        var height: CGFloat = 12
        for row in prepared {
            height += measure(row, width: contentWidth).height + 2
        }
        height += 10
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: max(height, 80)))
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 10
            for row in prepared {
                let font = UIFont.systemFont(ofSize: row.size, weight: row.bold ? .semibold : .regular)
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = row.center ? .center : .left
                paragraph.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
                if !row.qr.isEmpty {
                    context.cgContext.interpolationQuality = .none
                    let large = contentWidth
                    if let image = qrImage(row.qr, side: large) {
                        context.cgContext.draw(image, in: CGRect(x: margin, y: y, width: large, height: large))
                    }
                    let gap: CGFloat = 8
                    let small = (contentWidth - gap) / 2
                    let smallY = y + large + 6
                    if let image = qrImage(row.qrLeft, side: small) {
                        context.cgContext.draw(image, in: CGRect(x: margin, y: smallY, width: small, height: small))
                    }
                    if let image = qrImage(row.qrRight, side: small) {
                        context.cgContext.draw(image, in: CGRect(x: margin + small + gap, y: smallY, width: small, height: small))
                    }
                    y += large + 6 + small + 2
                } else if !row.columns.isEmpty {
                    let font = UIFont.systemFont(ofSize: row.size, weight: row.bold ? .semibold : .regular)
                    let count = CGFloat(row.columns.count)
                    let slot = contentWidth / max(count, 1)
                    for (index, text) in row.columns.enumerated() {
                        let x = margin + slot * CGFloat(index)
                        context.cgContext.saveGState()
                        context.cgContext.clip(to: CGRect(x: x, y: y - 1, width: slot - 1, height: font.lineHeight + 4))
                        let paragraph = NSMutableParagraphStyle()
                        paragraph.alignment = .right
                        paragraph.lineBreakMode = .byClipping
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: UIColor.black,
                            .paragraphStyle: paragraph
                        ]
                        (text as NSString).draw(
                            in: CGRect(x: x, y: y, width: slot - 2, height: font.lineHeight + 2),
                            withAttributes: attrs
                        )
                        context.cgContext.restoreGState()
                    }
                    y += ceil(font.lineHeight) + 2
                } else if row.right.isEmpty {
                    let rect = CGRect(x: margin, y: y, width: contentWidth, height: 80)
                    let bound = (row.left as NSString).boundingRect(
                        with: CGSize(width: contentWidth, height: 80),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs,
                        context: nil
                    )
                    (row.left as NSString).draw(in: rect, withAttributes: attrs)
                    y += ceil(bound.height) + 2
                } else {
                    let rightWidth = (row.right as NSString).size(withAttributes: [.font: font]).width
                    let leftWidth = max(40, contentWidth - rightWidth - 6)
                    (row.left as NSString).draw(
                        in: CGRect(x: margin, y: y, width: leftWidth, height: font.lineHeight + 2),
                        withAttributes: attrs
                    )
                    let rightParagraph = NSMutableParagraphStyle()
                    rightParagraph.alignment = .right
                    var rightAttrs = attrs
                    rightAttrs[.paragraphStyle] = rightParagraph
                    (row.right as NSString).draw(
                        in: CGRect(x: margin + leftWidth + 6, y: y, width: rightWidth, height: font.lineHeight + 2),
                        withAttributes: rightAttrs
                    )
                    y += ceil(font.lineHeight) + 2
                }
            }
        }
    }

    private static func qrImage(_ text: String, side: CGFloat) -> CGImage? {
        guard !text.isEmpty,
              let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        let scale = side / max(extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(scaled, from: scaled.extent.integral)
    }

    private static func wrap(_ row: Row, width: CGFloat) -> [Row] {
        if !row.qr.isEmpty || !row.columns.isEmpty { return [row] }
        let font = UIFont.systemFont(ofSize: row.size, weight: row.bold ? .semibold : .regular)
        var limit = width
        if !row.right.isEmpty {
            let rightWidth = (row.right as NSString).size(withAttributes: [.font: font]).width
            limit = max(40, width - rightWidth - 6)
        }
        let lines = breakText(row.left, limit: limit, font: font)
        return lines.enumerated().map { index, line in
            Row(left: line, right: index == 0 ? row.right : "", size: row.size, bold: row.bold, center: row.center)
        }
    }

    private static func breakText(_ text: String, limit: CGFloat, font: UIFont) -> [String] {
        let words = pieces(text, limit: limit, font: font)
        var lines: [String] = []
        var current = ""
        for word in words {
            let trial = current.isEmpty ? word : current + " " + word
            let width = (trial as NSString).size(withAttributes: [.font: font]).width
            if width <= limit {
                current = trial
            } else {
                if !current.isEmpty { lines.append(current) }
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [""] : lines
    }

    private static func pieces(_ text: String, limit: CGFloat, font: UIFont) -> [String] {
        var result: [String] = []
        for word in text.split(separator: " ", omittingEmptySubsequences: true) {
            let token = String(word)
            if (token as NSString).size(withAttributes: [.font: font]).width <= limit {
                result.append(token)
                continue
            }
            var chunk = ""
            for character in token {
                let trial = chunk + String(character)
                if (trial as NSString).size(withAttributes: [.font: font]).width <= limit {
                    chunk = trial
                } else {
                    if !chunk.isEmpty { result.append(chunk) }
                    chunk = String(character)
                }
            }
            if !chunk.isEmpty { result.append(chunk) }
        }
        return result
    }

    private static func measure(_ row: Row, width: CGFloat) -> CGRect {
        let font = UIFont.systemFont(ofSize: row.size, weight: row.bold ? .semibold : .regular)
        if !row.qr.isEmpty {
            let small = (width - 8) / 2
            return CGRect(x: 0, y: 0, width: width, height: width + 6 + small)
        }
        if !row.columns.isEmpty || !row.right.isEmpty {
            return CGRect(x: 0, y: 0, width: width, height: font.lineHeight)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = row.center ? .center : .left
        return (row.left as NSString).boundingRect(
            with: CGSize(width: width, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
    }
}
