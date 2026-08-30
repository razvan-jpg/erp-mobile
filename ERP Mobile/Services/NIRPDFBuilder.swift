import Foundation
import UIKit

enum NIRPDFBuilder {
    private static let pageSize = CGSize(width: 842, height: 595)
    private static let margin: CGFloat = 28
    private static let columnWidthFractions: [CGFloat] = [
        0.03, 0.11, 0.04, 0.04, 0.04, 0.05, 0.05, 0.04, 0.04, 0.05,
        0.04, 0.04, 0.06, 0.05, 0.06, 0.06, 0.04, 0.04, 0.05, 0.05
    ]

    static func makePDF(from snapshot: NIRSnapshot) -> Data {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let sectionFont = UIFont.boldSystemFont(ofSize: 9)
        let bodyFont = UIFont.systemFont(ofSize: 8)
        var y: CGFloat = margin

        return renderer.pdfData { context in
            context.beginPage()
            let headerStartY = y

            y = drawText(
                L10n.tr("nir.pdf_company_label") + " " + snapshot.company.denumire,
                at: y,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            y = drawText(companyFiscalLine(snapshot.company), at: y, pageWidth: pageRect.width, font: bodyFont)
            y = drawCompanyReceptionDetails(snapshot: snapshot, at: y, pageWidth: pageRect.width, font: bodyFont)

            var rightY = headerStartY
            rightY = drawRightAlignedText(
                L10n.tr("nir.pdf_title"),
                at: rightY,
                pageWidth: pageRect.width,
                font: sectionFont
            )
            rightY = drawRightAlignedText(
                L10n.tr("nir.pdf_number_date", snapshot.nir.numarNir, SupplierFormatting.date(snapshot.nir.dataNir)),
                at: rightY + 2,
                pageWidth: pageRect.width,
                font: bodyFont
            )

            y = max(y, rightY) + 10
            let documentTitleFont = UIFont.boldSystemFont(ofSize: bodyFont.pointSize * 3)
            y = drawCenteredText(
                L10n.tr("nir.pdf_document_title"),
                at: y,
                pageWidth: pageRect.width,
                font: documentTitleFont
            )
            y += 6
            y = drawText(
                L10n.tr("nir.pdf_invoice_number", snapshot.invoiceNumber),
                at: y,
                pageWidth: pageRect.width,
                font: bodyFont
            )
            y = drawRightAlignedText(
                L10n.tr("nir.pdf_supplier", snapshot.supplier.denumire),
                at: y - 12,
                pageWidth: pageRect.width,
                font: bodyFont
            )
            y += 6

            _ = drawLinesTable(
                snapshot: snapshot,
                at: y,
                pageWidth: pageRect.width,
                pageHeight: pageRect.height,
                context: context
            )
        }
    }

    static func exportFileName(from snapshot: NIRSnapshot) -> String {
        let safeNirNumber = sanitizedFileNameComponent(snapshot.nir.numarNir)
        let safeInvoiceNumber = sanitizedFileNameComponent(snapshot.invoiceNumber)
        if safeInvoiceNumber.isEmpty {
            return "NIR-\(safeNirNumber).pdf"
        }
        return "NIR-\(safeNirNumber)-Factura-\(safeInvoiceNumber).pdf"
    }

    private static func sanitizedFileNameComponent(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    static func writeTemporaryPDF(from snapshot: NIRSnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(exportFileName(from: snapshot))
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func companyFiscalLine(_ company: Company) -> String {
        let prefix = company.cifCountryPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        let cui = company.cui?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let onrc = company.nrRegCom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var parts: [String] = []
        if !cui.isEmpty {
            parts.append(L10n.tr("nir.pdf_fiscal_code", prefix.isEmpty ? cui : "\(prefix) \(cui)"))
        }
        if !onrc.isEmpty {
            parts.append(L10n.tr("nir.pdf_onrc", onrc))
        }
        return parts.joined(separator: "   ")
    }

    @discardableResult
    private static func drawCompanyReceptionDetails(
        snapshot: NIRSnapshot,
        at startY: CGFloat,
        pageWidth: CGFloat,
        font: UIFont
    ) -> CGFloat {
        var y = startY

        if let workLocationName = snapshot.workLocationName {
            y = drawText(
                L10n.tr("nir.pdf_work_location", workLocationName),
                at: y,
                pageWidth: pageWidth,
                font: font
            )
            if let workLocationAddress = snapshot.workLocationAddress {
                y = drawText(workLocationAddress, at: y, pageWidth: pageWidth, font: font)
            }
            y += 2
        }

        if let warehouseName = snapshot.warehouseName {
            y = drawText(
                L10n.tr("nir.pdf_warehouse", warehouseName),
                at: y,
                pageWidth: pageWidth,
                font: font
            )
            if let warehouseAddress = snapshot.warehouseAddress {
                y = drawText(warehouseAddress, at: y, pageWidth: pageWidth, font: font)
            }
        }

        return y == startY ? y : y + 4
    }

    private static var tableWidth: CGFloat {
        pageSize.width - margin * 2
    }

    @discardableResult
    private static func drawLinesTable(
        snapshot: NIRSnapshot,
        at startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 5.5)
        let bodyFont = UIFont.systemFont(ofSize: 5.5)
        let columnWidths = columnWidths(for: tableWidth)
        var y = startY

        let headerRow1 = [
            L10n.tr("nir.pdf_col_no"),
            L10n.tr("nir.pdf_col_product"),
            L10n.tr("nir.pdf_col_unit"),
            L10n.tr("nir.pdf_col_vat_rate"),
            L10n.tr("nir.pdf_col_qty"),
            L10n.tr("nir.pdf_col_unit_price"),
            L10n.tr("nir.pdf_col_value"),
            L10n.tr("nir.pdf_col_vat_unit"),
            L10n.tr("nir.pdf_col_vat_total"),
            L10n.tr("nir.pdf_col_invoice_total"),
            L10n.tr("nir.pdf_col_markup_pct"),
            L10n.tr("nir.pdf_col_markup_sum"),
            L10n.tr("nir.pdf_col_retail_unit_ex_vat"),
            L10n.tr("nir.pdf_col_vat_markup"),
            L10n.tr("nir.pdf_col_retail_unit_inc_vat"),
            L10n.tr("nir.pdf_col_retail_value"),
            L10n.tr("nir.pdf_col_retail_vat_unit"),
            L10n.tr("nir.pdf_col_retail_vat_total"),
            "",
            ""
        ]

        func ensureSpace(for rowHeight: CGFloat) {
            if y + rowHeight > pageHeight - margin {
                context.beginPage()
                y = margin
                y = drawTableRow(
                    values: headerRow1,
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
            values: headerRow1,
            columnWidths: columnWidths,
            x: margin,
            y: y,
            font: headerFont,
            isHeader: true,
            isAlternateRow: false
        )

        if snapshot.lines.isEmpty {
            var emptyValues = Array(repeating: "—", count: headerRow1.count)
            emptyValues[1] = L10n.tr("common.no_records")
            let rowHeight = estimatedRowHeight(values: emptyValues, columnWidths: columnWidths, font: bodyFont, isHeader: false)
            ensureSpace(for: rowHeight)
            y = drawTableRow(
                values: emptyValues,
                columnWidths: columnWidths,
                x: margin,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: false
            )
        } else {
            for (index, line) in snapshot.lines.enumerated() {
                let values = rowValues(for: line)
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
        }

        let totals = snapshot.totals
        let hasRetailTotals = totals.valoareAmanunt > 0
        let hasMarkupTotals = totals.adaosSuma > 0
        let totalValues = [
            "",
            L10n.tr("nir.pdf_total"),
            "—",
            "",
            amount(totals.cantitate),
            "—",
            amount(totals.valoare),
            "—",
            amount(totals.tvaTotal),
            amount(totals.totalFactura),
            hasMarkupTotals ? percent(totals.adaosProcent) : "",
            hasMarkupTotals ? amount(totals.adaosSuma) : "",
            "—",
            hasRetailTotals ? amount(totals.tvaAfAdeaos) : "",
            "—",
            hasRetailTotals ? amount(totals.valoareAmanunt) : "",
            "—",
            hasRetailTotals ? amount(totals.tvaAmanuntTotal) : "",
            "",
            ""
        ]
        let totalHeight = estimatedRowHeight(values: totalValues, columnWidths: columnWidths, font: headerFont, isHeader: true)
        ensureSpace(for: totalHeight)
        y = drawTableRow(
            values: totalValues,
            columnWidths: columnWidths,
            x: margin,
            y: y,
            font: headerFont,
            isHeader: true,
            isAlternateRow: false
        )

        y += 14
        let footerBlockHeight: CGFloat = snapshot.warehouseManagerName == nil ? 24 : 36
        ensureSpace(for: footerBlockHeight)
        _ = drawText(L10n.tr("nir.pdf_reception_committee"), at: y, pageWidth: pageWidth, font: bodyFont)
        var rightY = y
        rightY = drawRightAlignedText(L10n.tr("nir.pdf_received_in_stock"), at: rightY, pageWidth: pageWidth, font: bodyFont)
        if let warehouseManagerName = snapshot.warehouseManagerName {
            rightY = drawRightAlignedText(warehouseManagerName, at: rightY, pageWidth: pageWidth, font: bodyFont)
        }
        return max(y, rightY) + 12
    }

    private static func rowValues(for line: NIRComputedLine) -> [String] {
        let hasRetail = line.pretUnitarCuTvaAmanunt > 0 || line.valoareAmanunt > 0
        let hasMarkup = line.adaosSuma > 0
        return [
            "\(line.index)",
            line.conversieNota.map { "\(line.denumire)\n\($0)" } ?? line.denumire,
            line.unitateMasura,
            percent(line.cotaTva),
            amount(line.cantitate),
            amount(line.pretUnitar),
            amount(line.valoare),
            amount(line.tvaPeUnitate),
            amount(line.tvaTotal),
            amount(line.totalFactura),
            hasMarkup ? percent(line.adaosProcent) : "",
            hasMarkup ? amount(line.adaosSuma) : "",
            hasRetail ? amount(line.pretUnitarFaraTvaAmanunt) : "",
            hasRetail ? amount(line.tvaAfAdeaos) : "",
            hasRetail ? amount(line.pretUnitarCuTvaAmanunt) : "",
            hasRetail ? amount(line.valoareAmanunt) : "",
            hasRetail ? amount(line.tvaAmanuntPeUnitate) : "",
            hasRetail ? amount(line.tvaAmanuntTotal) : "",
            "",
            ""
        ]
    }

    private static func amount(_ value: Decimal) -> String {
        SupplierFormatting.amountString(value)
    }

    private static func percent(_ value: Decimal) -> String {
        SupplierFormatting.amountString(value)
    }

    private static func columnWidths(for totalWidth: CGFloat) -> [CGFloat] {
        columnWidthFractions.map { totalWidth * $0 }
    }

    @discardableResult
    private static func drawText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        let rect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: .greatestFiniteMagnitude)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        (text as NSString).draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bounding.height), withAttributes: attributes)
        return y + bounding.height + 2
    }

    @discardableResult
    private static func drawCenteredText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        let width = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let rect = CGRect(x: margin, y: y, width: width, height: bounding.height)
        (text as NSString).draw(in: rect, withAttributes: attributes)
        return y + bounding.height + 2
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
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let bounding = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let rect = CGRect(x: margin, y: y, width: width, height: bounding.height)
        (text as NSString).draw(in: rect, withAttributes: attributes)
        return y + bounding.height + 2
    }

    @discardableResult
    private static func drawLines(
        _ lines: [String],
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont
    ) -> CGFloat {
        lines.reduce(y) { current, line in
            drawText(line, at: current, pageWidth: pageWidth, font: font)
        }
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
        let rowHeight = estimatedRowHeight(values: values, columnWidths: columnWidths, font: font, isHeader: isHeader)
        var currentX = x
        for (index, value) in values.enumerated() {
            guard index < columnWidths.count else { break }
            let width = columnWidths[index]
            let rect = CGRect(x: currentX, y: y, width: width, height: rowHeight)
            if isHeader {
                UIColor(white: 0.92, alpha: 1).setFill()
                UIRectFill(rect)
            } else if isAlternateRow {
                UIColor(white: 0.97, alpha: 1).setFill()
                UIRectFill(rect)
            }
            UIColor.lightGray.setStroke()
            UIRectFrame(rect.insetBy(dx: 0.25, dy: 0.25))
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraph
            ]
            let textRect = rect.insetBy(dx: padding, dy: padding)
            (value as NSString).draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            currentX += width
        }
        return y + rowHeight
    }

    private static func estimatedRowHeight(
        values: [String],
        columnWidths: [CGFloat],
        font: UIFont,
        isHeader: Bool
    ) -> CGFloat {
        let padding: CGFloat = 4
        var maxHeight: CGFloat = isHeader ? 14 : 12
        for (index, value) in values.enumerated() {
            guard index < columnWidths.count else { break }
            let width = max(columnWidths[index] - padding * 2, 8)
            let bounding = (value as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            maxHeight = max(maxHeight, ceil(bounding.height) + padding * 2)
        }
        return maxHeight
    }
}
