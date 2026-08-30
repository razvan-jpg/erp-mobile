import Foundation
import UIKit

struct ClientAccountSnapshot: Sendable {
    let company: Company?
    let client: Client
    let ledgerEntries: [ClientAccountLedgerEntry]
    let soldRestant: Decimal
    let primaScadenta: Date?
    let moneda: String
    let generatedAt: Date
    let partnerRole: PartnerRole
}

enum ClientAccountPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let columnWidthFractions: [CGFloat] = [
        0.05, 0.05, 0.11, 0.09, 0.09, 0.10, 0.10, 0.10, 0.06, 0.15
    ]

    static func makePDF(from snapshot: ClientAccountSnapshot) -> Data {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let sectionFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        var y: CGFloat = margin

        return renderer.pdfData { context in
            context.beginPage()
            let client = snapshot.client
            let headerStartY = y

            if let company = snapshot.company {
                y = drawText(company.denumire, at: y, pageWidth: pageRect.width, font: sectionFont)
                y = drawLines([
                    line(L10n.tr("common.cui"), company.cui),
                    line(L10n.tr("common.field_nr_reg_com"), company.nrRegCom),
                    line(L10n.tr("common.field_address"), company.adresa),
                    line(L10n.tr("common.field_iban"), company.iban),
                    line(L10n.tr("common.field_email"), company.email),
                    line(L10n.tr("common.field_phone"), company.telefon)
                ], at: y, pageWidth: pageRect.width, font: bodyFont)
            } else {
                y = drawText(L10n.tr("common.unknown_company"), at: y, pageWidth: pageRect.width, font: sectionFont)
            }

            let listingDateBlock = [
                L10n.tr("account.listing_date"),
                SupplierFormatting.date(snapshot.generatedAt)
            ]
            var listingY = headerStartY
            for (index, text) in listingDateBlock.enumerated() {
                listingY = drawRightAlignedText(
                    text,
                    at: listingY,
                    pageWidth: pageRect.width,
                    font: index == 0 ? bodyFont : sectionFont,
                    color: index == 0 ? .darkGray : .black
                )
            }

            y = max(y, listingY) + 12

            y = drawText(L10n.tr("account.client_sheet"), at: y, pageWidth: pageRect.width, font: titleFont)
            y = drawText(client.denumire, at: y + 4, pageWidth: pageRect.width, font: sectionFont)
            y += 8

            y = drawSection(L10n.tr("account.client_data"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y = drawLines([
                line(L10n.tr("account.partner_role_label"), snapshot.partnerRole.displayLabel),
                line(L10n.tr("common.cui"), client.cui),
                line(L10n.tr("common.field_nr_reg_com"), client.nrRegCom),
                line(L10n.tr("common.field_address"), client.adresa),
                line(L10n.tr("common.field_iban"), client.iban),
                line(L10n.tr("common.field_email"), client.email),
                line(L10n.tr("common.field_phone"), client.telefon),
                client.nrZileScadenta > 0
                    ? L10n.tr("clients.payment_term_line", client.nrZileScadenta)
                    : L10n.tr("account.no_scadenta_auto"),
                line(
                    L10n.tr("common.field_status"),
                    client.isActive ? L10n.tr("common.active") : L10n.tr("common.inactive")
                )
            ], at: y, pageWidth: pageRect.width, font: bodyFont)
            y += 8

            y = drawSection(L10n.tr("account.financial_situation"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y = drawLines([
                L10n.tr("account.outstanding_line", SupplierFormatting.currency(snapshot.soldRestant, code: snapshot.moneda)),
                L10n.tr("account.first_due_line", SupplierFormatting.date(snapshot.primaScadenta))
            ], at: y, pageWidth: pageRect.width, font: bodyFont)
            y += 8

            y = drawSection(L10n.tr("account.ledger_title"), at: y, pageWidth: pageRect.width, font: sectionFont)
            y = drawLedgerTable(
                entries: snapshot.ledgerEntries,
                moneda: snapshot.moneda,
                at: y,
                pageWidth: pageRect.width,
                pageHeight: pageRect.height,
                context: context
            )

            if let observatii = client.observatii, !observatii.isEmpty {
                y += 8
                if y > pageRect.height - 100 {
                    context.beginPage()
                    y = margin
                }
                y = drawSection(L10n.tr("account.section_notes"), at: y, pageWidth: pageRect.width, font: sectionFont)
                _ = drawText(observatii, at: y, pageWidth: pageRect.width, font: bodyFont)
            }
        }
    }

    static func writeTemporaryPDF(from snapshot: ClientAccountSnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let safeName = snapshot.client.denumire
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Fisa-\(safeName)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static var tableWidth: CGFloat {
        pageSize.width - margin * 2
    }

    private static var ledgerHeaderValues: [String] {
        [
            L10n.tr("account.table_no"),
            L10n.tr("account.table_doc_type"),
            L10n.tr("account.table_doc_number"),
            L10n.tr("account.table_doc_date"),
            L10n.tr("account.table_due_date"),
            L10n.tr("account.table_amount"),
            L10n.tr("account.table_invoice_balance"),
            L10n.tr("account.table_final_balance"),
            L10n.tr("account.table_overdue_days"),
            L10n.tr("account.table_invoice_status")
        ]
    }

    @discardableResult
    private static func drawLedgerTable(
        entries: [ClientAccountLedgerEntry],
        moneda: String,
        at startY: CGFloat,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 7)
        let bodyFont = UIFont.systemFont(ofSize: 7)
        let columnWidths = Self.columnWidths(for: tableWidth)
        var y = startY

        func ensureSpace(for rowHeight: CGFloat) {
            if y + rowHeight > pageHeight - margin {
                context.beginPage()
                y = margin
                y = drawTableRow(
                    values: ledgerHeaderValues,
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
            values: ledgerHeaderValues,
            columnWidths: columnWidths,
            x: margin,
            y: y,
            font: headerFont,
            isHeader: true,
            isAlternateRow: false
        )

        if entries.isEmpty {
            let emptyValues = ["—", "—", L10n.tr("common.no_records"), "", "", "", "", "", "", ""]
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

        for (index, entry) in entries.enumerated() {
            let values = ledgerRowValues(for: entry, moneda: moneda)
            let valueColors = ledgerRowColors(for: entry)
            let rowHeight = estimatedRowHeight(values: values, columnWidths: columnWidths, font: bodyFont, isHeader: false)
            ensureSpace(for: rowHeight)
            y = drawTableRow(
                values: values,
                valueColors: valueColors,
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

    private static func ledgerRowValues(for entry: ClientAccountLedgerEntry, moneda: String) -> [String] {
        [
            "\(entry.nrCrt)",
            entry.tipDocumentScurt,
            entry.nrDocument,
            SupplierFormatting.compactDate(entry.dataDocument),
            SupplierFormatting.compactDate(entry.dataScadenta),
            AccountLedgerDisplay.amountText(suma: entry.suma, isInvoice: entry.isInvoice, moneda: moneda),
            AccountLedgerDisplay.balanceText(entry.soldFactura, moneda: moneda),
            AccountLedgerDisplay.balanceText(entry.soldFinal, moneda: moneda),
            entry.zileIntarziereDisplay,
            entry.statusDisplay
        ]
    }

    private static func ledgerRowColors(for entry: ClientAccountLedgerEntry) -> [UIColor?] {
        var colors = Array<UIColor?>(repeating: nil, count: 10)
        if !entry.isInvoice {
            colors[5] = .systemRed
        }
        return colors
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
        valueColors: [UIColor?]? = nil,
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
            paragraph.alignment = .right
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: isHeader ? UIColor.darkGray : (valueColors?[index] ?? UIColor.black),
                .paragraphStyle: paragraph
            ]
            let textRect = rect.insetBy(dx: padding, dy: padding)
            value.draw(in: textRect, withAttributes: attributes)

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
            measureTextHeight(value, width: width - padding * 2, font: font)
        }
        return max(heights.max() ?? minHeight, minHeight) + padding * 2
    }

    private static func measureTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
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
    private static func drawSection(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont
    ) -> CGFloat {
        drawText(text, at: y, pageWidth: pageWidth, font: font) + 4
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

    @discardableResult
    private static func drawText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        drawAlignedText(
            text,
            at: y,
            pageWidth: pageWidth,
            font: font,
            color: color,
            alignment: .left
        )
    }

    @discardableResult
    private static func drawRightAlignedText(
        _ text: String,
        at y: CGFloat,
        pageWidth: CGFloat,
        font: UIFont,
        color: UIColor = .black
    ) -> CGFloat {
        drawAlignedText(
            text,
            at: y,
            pageWidth: pageWidth,
            font: font,
            color: color,
            alignment: .right
        )
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
