import Foundation
import UIKit

enum StockSheetPDFBuilder {
    private static let portraitSize = CGSize(width: 595, height: 842)
    private static let landscapeSize = CGSize(width: 842, height: 595)
    private static let margin: CGFloat = 36

    static func writeTemporaryPDF(from snapshot: StockSheetSnapshot) throws -> URL {
        try write(data: makeDetailPDF(from: snapshot), fileName: "Fisa-stoc-\(sanitized(snapshot.product.denumire))")
    }

    static func writeTemporaryListingPDF(from snapshot: StockSheetListingSnapshot) throws -> URL {
        try write(data: makeListingPDF(from: snapshot), fileName: "Fisa-stoc-lista")
    }

    private static func write(data: Data, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func makeListingPDF(from snapshot: StockSheetListingSnapshot) -> Data {
        let pageRect = CGRect(origin: .zero, size: portraitSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let sectionFont = UIFont.boldSystemFont(ofSize: 12)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let fractions: [CGFloat] = [0.08, 0.38, 0.10, 0.14, 0.14, 0.16]

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin
            y = drawHeader(company: snapshot.company, generatedAt: snapshot.generatedAt, pageWidth: pageRect.width, y: y)
            y = drawText(L10n.tr("stock_sheet.title"), at: y + 8, pageWidth: pageRect.width, font: titleFont)
            y += 8

            let widths = columnWidths(fractions, total: pageRect.width - margin * 2)
            let headers = [
                L10n.tr("stock_sheet.col_no"),
                L10n.tr("stock_sheet.col_name"),
                L10n.tr("stock_sheet.col_unit"),
                L10n.tr("stock_sheet.col_quantity"),
                L10n.tr("stock_sheet.col_avg_cost"),
                L10n.tr("stock_sheet.col_value")
            ]
            y = drawTableRow(headers, widths: widths, x: margin, y: y, font: sectionFont, isHeader: true, isAlternate: false)

            if snapshot.rows.isEmpty {
                y = drawTableRow(
                    [L10n.tr("stock_sheet.empty"), "", "", "", "", ""],
                    widths: widths,
                    x: margin,
                    y: y,
                    font: bodyFont,
                    isHeader: false,
                    isAlternate: false
                )
            } else {
                for (index, row) in snapshot.rows.enumerated() {
                    if y > pageRect.height - margin - 28 {
                        context.beginPage()
                        y = margin
                        y = drawTableRow(headers, widths: widths, x: margin, y: y, font: sectionFont, isHeader: true, isAlternate: false)
                    }
                    y = drawTableRow(
                        [
                            "\(index + 1)",
                            row.product.denumire,
                            row.unit,
                            SupplierFormatting.amountString(row.cantitate),
                            row.pretMediu.map { SupplierFormatting.amountString($0) } ?? "—",
                            SupplierFormatting.currency(row.valoare)
                        ],
                        widths: widths,
                        x: margin,
                        y: y,
                        font: bodyFont,
                        isHeader: false,
                        isAlternate: !index.isMultiple(of: 2)
                    )
                }
            }

            _ = drawTableRow(
                [
                    "",
                    L10n.tr("stock_sheet.total"),
                    "",
                    "",
                    "",
                    SupplierFormatting.currency(snapshot.totalValue)
                ],
                widths: widths,
                x: margin,
                y: y + 4,
                font: sectionFont,
                isHeader: true,
                isAlternate: false
            )
        }
    }

    private static func makeDetailPDF(from snapshot: StockSheetSnapshot) -> Data {
        let pageRect = CGRect(origin: .zero, size: landscapeSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let sectionFont = UIFont.boldSystemFont(ofSize: 11)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        let fractions: [CGFloat] = [0.10, 0.16, 0.10, 0.12, 0.10, 0.12, 0.14, 0.16]

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin
            y = drawHeader(company: snapshot.company, generatedAt: snapshot.generatedAt, pageWidth: pageRect.width, y: y)
            y = drawText(L10n.tr("stock_sheet.detail_title"), at: y + 6, pageWidth: pageRect.width, font: titleFont)
            y = drawText(snapshot.product.denumire, at: y, pageWidth: pageRect.width, font: sectionFont)
            var summaryLines: [String] = []
            if let cod = snapshot.product.cod, !cod.isEmpty {
                summaryLines.append(L10n.tr("common.detail_line", L10n.tr("module.products.field_code"), cod))
            }
            summaryLines.append(L10n.tr("common.detail_line", L10n.tr("inventory.field_unit"), snapshot.product.unitateMasura))
            summaryLines.append(
                L10n.tr(
                    "common.detail_line",
                    L10n.tr("inventory.field_quantity"),
                    "\(SupplierFormatting.amountString(snapshot.cantitate)) \(snapshot.product.unitateMasura)"
                )
            )
            summaryLines.append(
                L10n.tr(
                    "common.detail_line",
                    L10n.tr("inventory.weighted_average_cost"),
                    snapshot.pretMediu.map { SupplierFormatting.amountString($0) } ?? "—"
                )
            )
            summaryLines.append(
                L10n.tr(
                    "common.detail_line",
                    L10n.tr("stock_sheet.col_value"),
                    SupplierFormatting.currency(snapshot.valoare)
                )
            )
            y = drawText(summaryLines.joined(separator: "   "), at: y, pageWidth: pageRect.width, font: bodyFont)
            y += 8

            let widths = columnWidths(fractions, total: pageRect.width - margin * 2)
            let headers = [
                L10n.tr("stock_sheet.col_date"),
                L10n.tr("stock_sheet.col_document"),
                L10n.tr("stock_sheet.col_in_qty"),
                L10n.tr("stock_sheet.col_in_value"),
                L10n.tr("stock_sheet.col_out_qty"),
                L10n.tr("stock_sheet.col_out_value"),
                L10n.tr("stock_sheet.col_stock_qty"),
                L10n.tr("stock_sheet.col_stock_value")
            ]
            y = drawTableRow(headers, widths: widths, x: margin, y: y, font: sectionFont, isHeader: true, isAlternate: false)

            if snapshot.entries.isEmpty {
                _ = drawTableRow(
                    [L10n.tr("stock_sheet.ledger_empty"), "", "", "", "", "", "", ""],
                    widths: widths,
                    x: margin,
                    y: y,
                    font: bodyFont,
                    isHeader: false,
                    isAlternate: false
                )
            } else {
                for (index, entry) in snapshot.entries.enumerated() {
                    if y > pageRect.height - margin - 24 {
                        context.beginPage()
                        y = margin
                        y = drawTableRow(headers, widths: widths, x: margin, y: y, font: sectionFont, isHeader: true, isAlternate: false)
                    }
                    y = drawTableRow(
                        rowValues(for: entry),
                        widths: widths,
                        x: margin,
                        y: y,
                        font: bodyFont,
                        isHeader: false,
                        isAlternate: !index.isMultiple(of: 2)
                    )
                }
            }
        }
    }

    private static func rowValues(for entry: StockSheetLedgerEntry) -> [String] {
        [
            SupplierFormatting.compactDate(entry.dataTranzactie),
            entry.numarDocument,
            blankIfZero(entry.cantitateIntrare),
            blankIfZero(entry.valoareIntrare, currency: true),
            blankIfZero(entry.cantitateIesire),
            blankIfZero(entry.valoareIesire, currency: true),
            SupplierFormatting.amountString(entry.stocCantitate),
            SupplierFormatting.currency(entry.stocValoare)
        ]
    }

    private static func blankIfZero(_ value: Decimal, currency: Bool = false) -> String {
        value == 0 ? "" : (currency ? SupplierFormatting.currency(value) : SupplierFormatting.amountString(value))
    }

    private static func drawHeader(company: Company?, generatedAt: Date, pageWidth: CGFloat, y: CGFloat) -> CGFloat {
        let sectionFont = UIFont.boldSystemFont(ofSize: 12)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        var nextY = y
        if let company {
            nextY = drawText(company.denumire, at: nextY, pageWidth: pageWidth, font: sectionFont)
            let details = [
                company.cui.map { L10n.tr("common.cui_label", $0) },
                company.adresa
            ].compactMap { $0 }.filter { !$0.isEmpty }
            if !details.isEmpty {
                nextY = drawText(details.joined(separator: "  ·  "), at: nextY, pageWidth: pageWidth, font: bodyFont)
            }
        }
        nextY = drawText(
            L10n.tr("common.detail_line", L10n.tr("account.listing_date"), SupplierFormatting.date(generatedAt)),
            at: nextY,
            pageWidth: pageWidth,
            font: bodyFont
        )
        return nextY
    }

    @discardableResult
    private static func drawText(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont) -> CGFloat {
        let maxWidth = pageWidth - margin * 2
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let height = ceil(
            text.boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            ).height
        )
        text.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: height), withAttributes: attributes)
        return y + height + 3
    }

    @discardableResult
    private static func drawTableRow(
        _ values: [String],
        widths: [CGFloat],
        x: CGFloat,
        y: CGFloat,
        font: UIFont,
        isHeader: Bool,
        isAlternate: Bool
    ) -> CGFloat {
        let padding: CGFloat = 3
        let minHeight: CGFloat = isHeader ? 18 : 16
        let heights = zip(values, widths).map { value, width -> CGFloat in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            paragraph.lineBreakMode = .byWordWrapping
            return ceil(
                value.boundingRect(
                    with: CGSize(width: max(width - padding * 2, 1), height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .paragraphStyle: paragraph],
                    context: nil
                ).height
            )
        }
        let rowHeight = max(heights.max() ?? minHeight, minHeight) + padding * 2
        let rowWidth = widths.reduce(0, +)
        let rowRect = CGRect(x: x, y: y, width: rowWidth, height: rowHeight)
        if isHeader {
            UIColor(white: 0.92, alpha: 1).setFill()
        } else if isAlternate {
            UIColor(white: 0.96, alpha: 1).setFill()
        } else {
            UIColor.white.setFill()
        }
        UIBezierPath(rect: rowRect).fill()

        var cellX = x
        for (index, value) in values.enumerated() {
            let width = widths[index]
            let rect = CGRect(x: cellX, y: y, width: width, height: rowHeight)
            let path = UIBezierPath(rect: rect)
            path.lineWidth = 0.4
            UIColor.separator.setStroke()
            path.stroke()
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = index == 1 && !isHeader ? .left : .right
            paragraph.lineBreakMode = .byWordWrapping
            value.draw(
                in: rect.insetBy(dx: padding, dy: padding),
                withAttributes: [
                    .font: font,
                    .foregroundColor: isHeader ? UIColor.darkGray : UIColor.black,
                    .paragraphStyle: paragraph
                ]
            )
            cellX += width
        }
        return y + rowHeight
    }

    private static func columnWidths(_ fractions: [CGFloat], total: CGFloat) -> [CGFloat] {
        var widths = fractions.map { floor(total * $0) }
        let used = widths.reduce(0, +)
        if !widths.isEmpty {
            widths[widths.count - 1] += total - used
        }
        return widths
    }

    private static func sanitized(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }
}
