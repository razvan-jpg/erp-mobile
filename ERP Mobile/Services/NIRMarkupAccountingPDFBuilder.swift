import Foundation
import UIKit

struct NIRMarkupAccountingSnapshot: Sendable {
    let company: Company?
    let report: NIRMarkupAccountingReport
    let generatedAt: Date
}

enum NIRMarkupAccountingPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let columnWidthFractions: [CGFloat] = [
        0.12, 0.10, 0.14, 0.34, 0.15, 0.15
    ]

    static func makePDF(from snapshot: NIRMarkupAccountingSnapshot) -> Data {
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
                    line(L10n.tr("common.cui"), company.cui),
                    line(L10n.tr("common.field_nr_reg_com"), company.nrRegCom)
                ], at: y, pageWidth: pageRect.width, font: bodyFont)
            } else {
                y = drawText(L10n.tr("common.unknown_company"), at: y, pageWidth: pageRect.width, font: sectionFont)
            }

            var listingY = headerStartY
            for (index, text) in [
                L10n.tr("account.listing_date"),
                SupplierFormatting.date(snapshot.generatedAt)
            ].enumerated() {
                listingY = drawRightAlignedText(
                    text,
                    at: listingY,
                    pageWidth: pageRect.width,
                    font: index == 0 ? bodyFont : sectionFont,
                    color: index == 0 ? .darkGray : .black
                )
            }

            y = max(y, listingY) + 12
            y = drawText(L10n.tr("nir.markup_accounting_note_title"), at: y, pageWidth: pageRect.width, font: titleFont)
            y = drawText(
                L10n.tr("nir.markup_accounting_month_label", SupplierFormatting.monthYear(snapshot.report.month)),
                at: y + 4,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            y += 8

            y = drawSection(L10n.tr("nir.markup_accounting_section_note"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y = drawLines([
                accountingLine(debit: "371", credit: "378", amount: snapshot.report.adaosSuma),
                accountingLine(debit: "371", credit: "4428", amount: snapshot.report.tvaAfAdeaos)
            ], at: y, pageWidth: pageRect.width, font: bodyFont)
            y += 8

            y = drawSection(
                L10n.tr("nir.markup_accounting_section_nirs", snapshot.report.entries.count),
                at: y,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            _ = drawEntriesTable(
                entries: snapshot.report.entries,
                at: y,
                pageWidth: pageRect.width,
                pageHeight: pageRect.height,
                context: context
            )
        }
    }

    static func writeTemporaryPDF(from snapshot: NIRMarkupAccountingSnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFileName(from: snapshot))
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportFileName(from snapshot: NIRMarkupAccountingSnapshot) -> String {
        let monthLabel = SupplierFormatting.monthYear(snapshot.report.month)
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "Nota-Adaos-\(monthLabel).pdf"
    }

    private static var tableWidth: CGFloat {
        pageSize.width - margin * 2
    }

    private static var tableHeaderValues: [String] {
        [
            L10n.tr("nir.markup_accounting_pdf_col_nir"),
            L10n.tr("nir.markup_accounting_pdf_col_date"),
            L10n.tr("nir.markup_accounting_pdf_col_invoice"),
            L10n.tr("nir.markup_accounting_pdf_col_supplier"),
            L10n.tr("nir.markup_accounting_pdf_col_markup"),
            L10n.tr("nir.markup_accounting_pdf_col_vat")
        ]
    }

    @discardableResult
    private static func drawEntriesTable(
        entries: [NIRMarkupAccountingEntry],
        at startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        let columnWidths = columnWidthFractions.map { $0 * tableWidth }
        var y = startY

        y = drawTableRow(
            values: tableHeaderValues,
            columnWidths: columnWidths,
            at: y,
            font: headerFont,
            isHeader: true
        )

        for (index, entry) in entries.enumerated() {
            let rowValues = [
                entry.numarNir,
                SupplierFormatting.date(entry.dataNir),
                entry.invoiceNumber,
                entry.supplierName,
                SupplierFormatting.amountString(entry.adaosSuma),
                SupplierFormatting.amountString(entry.tvaAfAdeaos)
            ]
            let rowHeight = estimatedRowHeight(
                values: rowValues,
                columnWidths: columnWidths,
                font: bodyFont,
                isHeader: false
            )
            if y + rowHeight > pageHeight - margin {
                context.beginPage()
                y = margin
                y = drawTableRow(
                    values: tableHeaderValues,
                    columnWidths: columnWidths,
                    at: y,
                    font: headerFont,
                    isHeader: true
                )
            }
            y = drawTableRow(
                values: rowValues,
                columnWidths: columnWidths,
                at: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: index.isMultiple(of: 2)
            )
        }

        return y
    }

    @discardableResult
    private static func drawTableRow(
        values: [String],
        columnWidths: [CGFloat],
        at y: CGFloat,
        font: UIFont,
        isHeader: Bool,
        isAlternateRow: Bool = false
    ) -> CGFloat {
        let padding: CGFloat = 3
        let rowHeight = estimatedRowHeight(
            values: values,
            columnWidths: columnWidths,
            font: font,
            isHeader: isHeader
        )
        let borderColor = UIColor.separator
        let rowWidth = columnWidths.reduce(0, +)
        let rowRect = CGRect(x: margin, y: y, width: rowWidth, height: rowHeight)

        if isHeader {
            UIColor(white: 0.92, alpha: 1).setFill()
        } else if isAlternateRow {
            UIColor(white: 0.94, alpha: 1).setFill()
        } else {
            UIColor.white.setFill()
        }
        UIBezierPath(rect: rowRect).fill()

        var cellX = margin
        for (index, value) in values.enumerated() {
            let width = columnWidths[index]
            let rect = CGRect(x: cellX, y: y, width: width, height: rowHeight)
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 0.5
            borderColor.setStroke()
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = index == 3 ? .left : .right
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isHeader ? UIColor.darkGray : UIColor.black,
                .paragraphStyle: paragraph
            ]
            value.draw(in: rect.insetBy(dx: padding, dy: padding), withAttributes: attributes)
            cellX += width
        }

        return y + rowHeight
    }

    private static func estimatedRowHeight(
        values: [String],
        columnWidths: [CGFloat],
        font: UIFont,
        isHeader: Bool
    ) -> CGFloat {
        let padding: CGFloat = 3
        let minHeight: CGFloat = isHeader ? 16 : 14
        let heights = zip(values, columnWidths).enumerated().map { index, pair in
            measureTextHeight(pair.0, width: pair.1 - padding * 2, font: font, alignLeft: index == 3)
        }
        return max(heights.max() ?? minHeight, minHeight) + padding * 2
    }

    private static func measureTextHeight(_ text: String, width: CGFloat, font: UIFont, alignLeft: Bool) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignLeft ? .left : .right
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph
        ]
        return ceil(
            text.boundingRect(
                with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).height
        )
    }

    private static func accountingLine(debit: String, credit: String, amount: Decimal) -> String {
        L10n.tr(
            "nir.markup_accounting_line",
            debit,
            credit,
            SupplierFormatting.amountString(amount)
        )
    }

    private static func line(_ label: String, _ value: String?) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "" : L10n.tr("common.detail_line", label, text)
    }

    @discardableResult
    private static func drawSection(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont) -> CGFloat {
        drawText(text, at: y, pageWidth: pageWidth, font: font) + 4
    }

    @discardableResult
    private static func drawLines(_ lines: [String], at y: CGFloat, pageWidth: CGFloat, font: UIFont) -> CGFloat {
        var cursor = y
        for line in lines where !line.isEmpty {
            cursor = drawText(line, at: cursor, pageWidth: pageWidth, font: font)
        }
        return cursor
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        drawAlignedText(text, at: y, pageWidth: pageWidth, font: font, color: color, alignment: .left)
    }

    @discardableResult
    private static func drawRightAlignedText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        drawAlignedText(text, at: y, pageWidth: pageWidth, font: font, color: color, alignment: .right)
    }

    @discardableResult
    private static func drawAlignedText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) -> CGFloat {
        let maxWidth = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let height = text.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        ).height
        text.draw(
            in: CGRect(x: margin, y: y, width: maxWidth, height: ceil(height)),
            withAttributes: attributes
        )
        return y + ceil(height) + 4
    }
}
