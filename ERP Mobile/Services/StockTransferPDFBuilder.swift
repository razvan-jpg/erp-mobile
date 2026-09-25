import Foundation
import UIKit

struct StockTransferSnapshot: Sendable {
    let company: Company?
    let transfer: StockTransfer
    let lines: [StockTransferLine]
    let sourceWarehouseName: String
    let destinationWarehouseName: String
    let generatedAt: Date
}

enum StockTransferPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let columnWidthFractions: [CGFloat] = [0.08, 0.52, 0.14, 0.14, 0.12]

    static func makePDF(from snapshot: StockTransferSnapshot) -> Data {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let sectionFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        var y: CGFloat = margin

        return renderer.pdfData { context in
            context.beginPage()
            let headerStartY = y

            if let company = snapshot.company {
                y = drawText(company.denumire, at: y, pageWidth: pageRect.width, font: sectionFont)
                y = drawLines([
                    fiscalLine(company),
                    addressLine(company)
                ].compactMap { $0 }, at: y, pageWidth: pageRect.width, font: bodyFont)
            } else {
                y = drawText(L10n.tr("common.unknown_company"), at: y, pageWidth: pageRect.width, font: sectionFont)
            }

            var rightY = headerStartY
            rightY = drawRightAlignedText(
                L10n.tr("inventory.transfer_pdf_generated"),
                at: rightY,
                pageWidth: pageRect.width,
                font: bodyFont,
                color: .darkGray
            )
            rightY = drawRightAlignedText(
                SupplierFormatting.date(snapshot.generatedAt),
                at: rightY,
                pageWidth: pageRect.width,
                font: sectionFont
            )

            y = max(y, rightY) + 14
            y = drawCenteredText(
                L10n.tr("inventory.transfer_pdf_title"),
                at: y,
                pageWidth: pageRect.width,
                font: titleFont
            )
            y += 6
            y = drawCenteredText(
                L10n.tr("inventory.transfer_pdf_subtitle"),
                at: y,
                pageWidth: pageRect.width,
                font: bodyFont
            )
            y += 10

            y = drawText(
                L10n.tr("inventory.transfer_number", snapshot.transfer.numar),
                at: y,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            y = drawLines([
                L10n.tr("inventory.transfer_field_date") + ": " + SupplierFormatting.date(snapshot.transfer.dataBon),
                L10n.tr("inventory.transfer_field_source") + ": " + snapshot.sourceWarehouseName,
                L10n.tr("inventory.transfer_field_destination") + ": " + snapshot.destinationWarehouseName
            ], at: y + 4, pageWidth: pageRect.width, font: bodyFont)

            if let notes = snapshot.transfer.observatii?.trimmingCharacters(in: .whitespacesAndNewlines),
               !notes.isEmpty {
                y = drawText(
                    L10n.tr("inventory.physical_field_notes") + ": " + notes,
                    at: y + 4,
                    pageWidth: pageRect.width,
                    font: bodyFont
                )
            }

            y += 12
            y = drawText(L10n.tr("inventory.transfer_lines"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y += 6
            y = drawLinesTable(
                lines: snapshot.lines,
                at: y,
                pageWidth: pageRect.width,
                pageHeight: pageRect.height,
                context: context
            )

            y += 28
            if y > pageRect.height - margin - 80 {
                context.beginPage()
                y = margin
            }
            let signatureWidth = (pageRect.width - margin * 2 - 40) / 2
            drawText(
                L10n.tr("inventory.transfer_pdf_delivered_by"),
                at: y,
                pageWidth: pageRect.width,
                font: bodyFont
            )
            drawRightAlignedText(
                L10n.tr("inventory.transfer_pdf_received_by"),
                at: y,
                pageWidth: pageRect.width,
                font: bodyFont
            )
            y += 36
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: margin + signatureWidth, y: y))
            path.move(to: CGPoint(x: pageRect.width - margin - signatureWidth, y: y))
            path.addLine(to: CGPoint(x: pageRect.width - margin, y: y))
            UIColor.darkGray.setStroke()
            path.lineWidth = 0.6
            path.stroke()
            y += 6
            drawText(
                L10n.tr("inventory.transfer_pdf_signature"),
                at: y,
                pageWidth: pageRect.width,
                font: UIFont.systemFont(ofSize: 9),
                color: .darkGray
            )
            drawRightAlignedText(
                L10n.tr("inventory.transfer_pdf_signature"),
                at: y,
                pageWidth: pageRect.width,
                font: UIFont.systemFont(ofSize: 9),
                color: .darkGray
            )
        }
    }

    static func writeTemporaryPDF(from snapshot: StockTransferSnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFileName(from: snapshot))
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportFileName(from snapshot: StockTransferSnapshot) -> String {
        let safeName = snapshot.transfer.numar
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "Aviz-expeditie-BT-\(safeName).pdf"
    }

    private static func fiscalLine(_ company: Company) -> String? {
        let prefix = company.cifCountryPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let cui = company.cui?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cui.isEmpty else { return nil }
        return L10n.tr("common.cui") + ": " + (prefix.isEmpty ? cui : "\(prefix) \(cui)")
    }

    private static func addressLine(_ company: Company) -> String? {
        let address = company.adresa?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !address.isEmpty else { return nil }
        return L10n.tr("common.field_address") + ": " + address
    }

    private static var tableWidth: CGFloat { pageSize.width - margin * 2 }

    private static var tableHeaderValues: [String] {
        [
            L10n.tr("inventory.transfer_pdf_col_no"),
            L10n.tr("inventory.transfer_pdf_col_product"),
            L10n.tr("inventory.transfer_pdf_col_code"),
            L10n.tr("inventory.field_unit"),
            L10n.tr("inventory.transfer_field_quantity")
        ]
    }

    @discardableResult
    private static func drawLinesTable(
        lines: [StockTransferLine],
        at startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 9)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        let columnWidths = columnWidths(for: tableWidth)
        var y = startY

        func ensureSpace(for rowHeight: CGFloat) {
            if y + rowHeight > pageHeight - margin {
                context.beginPage()
                y = margin
                y = drawTableRow(
                    values: tableHeaderValues,
                    columnWidths: columnWidths,
                    x: margin,
                    y: y,
                    font: headerFont,
                    isHeader: true,
                    isAlternateRow: false
                )
            }
        }

        y = drawTableRow(
            values: tableHeaderValues,
            columnWidths: columnWidths,
            x: margin,
            y: y,
            font: headerFont,
            isHeader: true,
            isAlternateRow: false
        )

        for (index, line) in lines.enumerated() {
            let values = [
                "\(index + 1)",
                line.product?.denumire ?? L10n.tr("inventory.unknown_product"),
                line.product?.cod ?? "—",
                line.unitateMasura,
                SupplierFormatting.amountString(line.cantitate)
            ]
            let rowHeight = estimatedRowHeight(values: values, columnWidths: columnWidths, font: bodyFont)
            ensureSpace(for: rowHeight)
            y = drawTableRow(
                values: values,
                columnWidths: columnWidths,
                x: margin,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: index % 2 == 1
            )
        }
        return y
    }

    private static func columnWidths(for total: CGFloat) -> [CGFloat] {
        columnWidthFractions.map { $0 * total }
    }

    private static func estimatedRowHeight(values: [String], columnWidths: [CGFloat], font: UIFont) -> CGFloat {
        var maxHeight: CGFloat = 22
        for (index, value) in values.enumerated() where index < columnWidths.count {
            let rect = (value as NSString).boundingRect(
                with: CGSize(width: columnWidths[index] - 6, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            maxHeight = max(maxHeight, ceil(rect.height) + 8)
        }
        return maxHeight
    }

    @discardableResult
    private static func drawTableRow(
        values: [String],
        columnWidths: [CGFloat],
        x: CGFloat,
        y: CGFloat,
        font: UIFont,
        isHeader: Bool,
        isAlternateRow: Bool
    ) -> CGFloat {
        let height = estimatedRowHeight(values: values, columnWidths: columnWidths, font: font)
        let totalWidth = columnWidths.reduce(0, +)
        let bgRect = CGRect(x: x, y: y, width: totalWidth, height: height)
        if isHeader {
            UIColor(white: 0.92, alpha: 1).setFill()
            UIBezierPath(rect: bgRect).fill()
        } else if isAlternateRow {
            UIColor(white: 0.97, alpha: 1).setFill()
            UIBezierPath(rect: bgRect).fill()
        }
        UIColor.lightGray.setStroke()
        let border = UIBezierPath(rect: bgRect)
        border.lineWidth = 0.4
        border.stroke()

        var cursorX = x
        for (index, value) in values.enumerated() where index < columnWidths.count {
            let width = columnWidths[index]
            let rect = CGRect(x: cursorX + 3, y: y + 4, width: width - 6, height: height - 6)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = index == 0 || index >= 3 ? .center : .left
            (value as NSString).draw(
                in: rect,
                withAttributes: [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
            )
            let colBorder = UIBezierPath()
            colBorder.move(to: CGPoint(x: cursorX + width, y: y))
            colBorder.addLine(to: CGPoint(x: cursorX + width, y: y + height))
            colBorder.lineWidth = 0.3
            UIColor.lightGray.setStroke()
            colBorder.stroke()
            cursorX += width
        }
        return y + height
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        let width = pageWidth - margin * 2
        let rect = CGRect(x: margin, y: y, width: width, height: 1000)
        let size = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
        return y + ceil(size.height) + 2
    }

    @discardableResult
    private static func drawCenteredText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont
    ) -> CGFloat {
        let width = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let size = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        (text as NSString).draw(
            in: CGRect(x: margin, y: y, width: width, height: ceil(size.height)),
            withAttributes: [.font: font, .foregroundColor: UIColor.black, .paragraphStyle: paragraph]
        )
        return y + ceil(size.height) + 2
    }

    @discardableResult
    private static func drawRightAlignedText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        let width = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let size = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        (text as NSString).draw(
            in: CGRect(x: margin, y: y, width: width, height: ceil(size.height)),
            withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
        return y + ceil(size.height) + 2
    }

    @discardableResult
    private static func drawLines(
        _ lines: [String],
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont
    ) -> CGFloat {
        var cursor = y
        for line in lines where !line.isEmpty {
            cursor = drawText(line, at: cursor, pageWidth: pageWidth, font: font)
        }
        return cursor
    }
}
