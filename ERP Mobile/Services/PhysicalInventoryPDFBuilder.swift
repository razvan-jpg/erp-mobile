import Foundation
import UIKit

struct PhysicalInventorySnapshot: Sendable {
    let company: Company?
    let inventory: PhysicalInventory
    let lines: [PhysicalInventoryLine]
    let summary: PhysicalInventorySummary
    let generatedAt: Date
}

enum PhysicalInventoryPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let columnWidthFractions: [CGFloat] = [
        0.05, 0.24, 0.08, 0.12, 0.06, 0.12, 0.12, 0.11, 0.10
    ]

    static func makePDF(from snapshot: PhysicalInventorySnapshot) -> Data {
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
                    line(L10n.tr("common.field_address"), company.adresa)
                ], at: y, pageWidth: pageRect.width, font: bodyFont)
            } else {
                y = drawText(L10n.tr("common.unknown_company"), at: y, pageWidth: pageRect.width, font: sectionFont)
            }

            var listingY = headerStartY
            for (index, text) in [
                L10n.tr("inventory.physical_pdf_generated_at"),
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
            let inventory = snapshot.inventory
            y = drawText(L10n.tr("inventory.physical_pdf_title"), at: y, pageWidth: pageRect.width, font: titleFont)
            y = drawText(
                L10n.tr("inventory.physical_number", inventory.numarInventar),
                at: y + 4,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            y += 8

            y = drawSection(L10n.tr("inventory.physical_pdf_header"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y = drawLines([
                L10n.tr("inventory.physical_date", SupplierFormatting.date(inventory.dataInventar)),
                L10n.tr("inventory.physical_status") + ": " + inventory.status.label,
                L10n.tr("inventory.physical_summary_lines") + ": \(snapshot.summary.totalLines)",
                L10n.tr("inventory.physical_summary_counted") + ": \(snapshot.summary.countedLines)",
                L10n.tr("inventory.physical_summary_differences") + ": \(snapshot.summary.differenceLines)",
                L10n.tr("inventory.physical_summary_plus") + ": \(SupplierFormatting.amountString(snapshot.summary.plusDifference))",
                L10n.tr("inventory.physical_summary_minus") + ": \(SupplierFormatting.amountString(snapshot.summary.minusDifference))"
            ], at: y, pageWidth: pageRect.width, font: bodyFont)

            if let observatii = inventory.observatii, !observatii.isEmpty {
                y += 4
                y = drawLines([
                    L10n.tr("inventory.physical_field_notes") + ": " + observatii
                ], at: y, pageWidth: pageRect.width, font: bodyFont)
            }

            y += 8
            y = drawSection(L10n.tr("inventory.physical_lines_section"), at: y, pageWidth: pageRect.width, font: sectionFont)
            _ = drawLinesTable(
                lines: snapshot.lines,
                at: y,
                pageWidth: pageRect.width,
                pageHeight: pageRect.height,
                context: context
            )
        }
    }

    static func writeTemporaryPDF(from snapshot: PhysicalInventorySnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let safeName = snapshot.inventory.numarInventar
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Inventar-\(safeName)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static var tableWidth: CGFloat {
        pageSize.width - margin * 2
    }

    private static var tableHeaderValues: [String] {
        [
            L10n.tr("inventory.physical_pdf_col_no"),
            L10n.tr("inventory.physical_product"),
            L10n.tr("inventory.physical_field_code"),
            L10n.tr("inventory.physical_field_barcode"),
            L10n.tr("inventory.field_unit"),
            L10n.tr("inventory.physical_book_stock"),
            L10n.tr("inventory.physical_counted_stock"),
            L10n.tr("inventory.physical_pdf_col_difference"),
            L10n.tr("inventory.physical_pdf_col_status")
        ]
    }

    @discardableResult
    private static func drawLinesTable(
        lines: [PhysicalInventoryLine],
        at startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 7)
        let bodyFont = UIFont.systemFont(ofSize: 7)
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

        if lines.isEmpty {
            let emptyValues = ["—", L10n.tr("common.no_records"), "", "", "", "", "", "", ""]
            let rowHeight = estimatedRowHeight(values: emptyValues, columnWidths: columnWidths, font: bodyFont, isHeader: false)
            ensureSpace(for: rowHeight)
            return drawTableRow(
                values: emptyValues,
                columnWidths: columnWidths,
                x: margin,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: false
            )
        }

        for (index, line) in lines.enumerated() {
            let values = rowValues(for: line, index: index + 1)
            let rowHeight = estimatedRowHeight(values: values, columnWidths: columnWidths, font: bodyFont, isHeader: false)
            ensureSpace(for: rowHeight)
            y = drawTableRow(
                values: values,
                columnWidths: columnWidths,
                x: margin,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: !index.isMultiple(of: 2)
            )
        }

        return y
    }

    private static func rowValues(for line: PhysicalInventoryLine, index: Int) -> [String] {
        let counted = line.cantitateNumarata.map { SupplierFormatting.amountString($0) } ?? "—"
        let difference: String
        let status: String
        if let delta = line.diferenta {
            if delta == 0 {
                difference = "0"
                status = L10n.tr("inventory.physical_pdf_status_ok")
            } else {
                let sign = delta > 0 ? "+" : "−"
                difference = "\(sign)\(SupplierFormatting.amountString(abs(delta)))"
                status = L10n.tr("inventory.physical_pdf_status_diff")
            }
        } else {
            difference = "—"
            status = L10n.tr("inventory.physical_not_counted")
        }

        return [
            "\(index)",
            line.productName,
            line.product?.cod ?? "",
            line.product?.codBare ?? "",
            line.unitateMasura,
            SupplierFormatting.amountString(line.stocScriptic),
            counted,
            difference,
            status
        ]
    }

    private static func columnWidths(for totalWidth: CGFloat) -> [CGFloat] {
        var widths = columnWidthFractions.map { floor(totalWidth * $0) }
        let used = widths.reduce(0, +)
        widths[widths.count - 1] += totalWidth - used
        return widths
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
        let padding: CGFloat = 2
        let rowHeight = estimatedRowHeight(
            values: values,
            columnWidths: columnWidths,
            font: font,
            isHeader: isHeader
        )
        let borderColor = UIColor.separator
        let rowWidth = columnWidths.reduce(0, +)
        let rowRect = CGRect(x: x, y: y, width: rowWidth, height: rowHeight)

        if isHeader {
            UIColor(white: 0.92, alpha: 1).setFill()
        } else if isAlternateRow {
            UIColor(white: 0.94, alpha: 1).setFill()
        } else {
            UIColor.white.setFill()
        }
        UIBezierPath(rect: rowRect).fill()

        var cellX = x
        for (index, value) in values.enumerated() {
            let width = columnWidths[index]
            let rect = CGRect(x: cellX, y: y, width: width, height: rowHeight)
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 0.5
            borderColor.setStroke()
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = index == 1 ? .left : .right
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
        let padding: CGFloat = 2
        let minHeight: CGFloat = isHeader ? 14 : 12
        let heights = zip(values, columnWidths).map { value, width in
            measureTextHeight(value, width: width - padding * 2, font: font, alignLeft: false)
        }
        if values.count > 1 {
            var adjusted = heights
            adjusted[1] = measureTextHeight(values[1], width: columnWidths[1] - padding * 2, font: font, alignLeft: true)
            return max(adjusted.max() ?? minHeight, minHeight) + padding * 2
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
