import Foundation
import UIKit

struct StockControlWarehouseSection: Sendable {
    let warehouseId: UUID?
    let warehouseName: String
    let rows: [ProductStockRow]
}

struct StockControlSnapshot: Sendable {
    let company: Company?
    let warehouseName: String
    let sections: [StockControlWarehouseSection]
    let generatedAt: Date
    var groupByCategory: Bool = true

    var rows: [ProductStockRow] { sections.flatMap(\.rows) }

    init(
        company: Company?,
        warehouseName: String,
        sections: [StockControlWarehouseSection],
        generatedAt: Date,
        groupByCategory: Bool = true
    ) {
        self.company = company
        self.warehouseName = warehouseName
        self.sections = sections
        self.generatedAt = generatedAt
        self.groupByCategory = groupByCategory
    }

    /// Compat: o singură listă de rânduri (o gestiune / total).
    init(
        company: Company?,
        warehouseName: String,
        rows: [ProductStockRow],
        generatedAt: Date,
        groupByCategory: Bool = true
    ) {
        self.init(
            company: company,
            warehouseName: warehouseName,
            sections: [StockControlWarehouseSection(warehouseId: nil, warehouseName: warehouseName, rows: rows)],
            generatedAt: generatedAt,
            groupByCategory: groupByCategory
        )
    }
}

enum StockControlPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let footerReserve: CGFloat = 28
    private static let columnWidthFractions: [CGFloat] = [0.06, 0.38, 0.14, 0.18, 0.08, 0.16]

    static func makePDF(from snapshot: StockControlSnapshot) -> Data {
        let totalPages = render(snapshot: snapshot, totalPages: nil).pageCount
        return render(snapshot: snapshot, totalPages: max(totalPages, 1)).data
    }

    static func writeTemporaryPDF(from snapshot: StockControlSnapshot) throws -> URL {
        let data = makePDF(from: snapshot)
        let safeName = snapshot.warehouseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Control-stoc-\(safeName)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func groupedRows(from rows: [ProductStockRow]) -> [(group: PhysicalInventoryCategoryGroup, rows: [ProductStockRow])] {
        var buckets: [String: [ProductStockRow]] = [:]
        for row in rows {
            let group = PhysicalInventoryCategoryGroup.group(for: row.product?.tip)
            buckets[group.id, default: []].append(row)
        }
        return PhysicalInventoryCategoryGroup.displayOrder.compactMap { group in
            guard var items = buckets[group.id], !items.isEmpty else { return nil }
            items = sortedRows(items)
            return (group, items)
        }
    }

    private struct RenderResult {
        let data: Data
        let pageCount: Int
    }

    private static func render(snapshot: StockControlSnapshot, totalPages: Int?) -> RenderResult {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 18)
        let sectionFont = UIFont.boldSystemFont(ofSize: 13)
        let bodyFont = UIFont.systemFont(ofSize: 11)
        var pageCount = 0
        var currentPage = 0

        let data = renderer.pdfData { context in
            func beginContentPage() {
                if currentPage > 0, let totalPages {
                    drawPageNumber(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
                }
                context.beginPage()
                currentPage += 1
                pageCount = max(pageCount, currentPage)
            }

            beginContentPage()
            var y: CGFloat = margin
            let headerStartY = y

            if let company = snapshot.company {
                y = drawText(company.denumire, at: y, pageWidth: pageRect.width, font: sectionFont)
                y = drawLines([
                    detailLine(L10n.tr("common.cui"), company.cui),
                    detailLine(L10n.tr("common.field_address"), company.adresa)
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
            y = drawText(L10n.tr("inventory.stock_control_pdf_title"), at: y, pageWidth: pageRect.width, font: titleFont)
            y = drawLines([
                L10n.tr("inventory.field_warehouse") + ": " + snapshot.warehouseName,
                L10n.tr("inventory.stock_control_pdf_total", snapshot.rows.count)
            ], at: y + 4, pageWidth: pageRect.width, font: bodyFont)
            y += 8

            let contentBottom = pageRect.height - margin - footerReserve
            for (sectionIndex, section) in snapshot.sections.enumerated() {
                if snapshot.sections.count > 1 {
                    if y > contentBottom - 80 {
                        beginContentPage()
                        y = margin
                    }
                    y = drawSection(section.warehouseName, at: y, pageWidth: pageRect.width, font: sectionFont)
                }

                if snapshot.groupByCategory {
                    y = drawGroupedTables(
                        rows: section.rows,
                        at: y,
                        pageWidth: pageRect.width,
                        contentBottom: contentBottom,
                        beginPage: beginContentPage,
                        sectionFont: sectionFont
                    )
                } else {
                    if sectionIndex == 0 && snapshot.sections.count == 1 {
                        y = drawSection(L10n.tr("inventory.stocks_section"), at: y, pageWidth: pageRect.width, font: sectionFont)
                    }
                    y = drawRowsTable(
                        rows: sortedRows(section.rows),
                        at: y,
                        contentBottom: contentBottom,
                        beginPage: beginContentPage
                    )
                }
                y += 10
            }

            if let totalPages {
                drawPageNumber(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
            }
        }

        return RenderResult(data: data, pageCount: pageCount)
    }

    private static func drawPageNumber(page: Int, total: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let text = L10n.tr("inventory.stock_control_page", page, total)
        let font = UIFont.systemFont(ofSize: 9)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraph
        ]
        let rect = CGRect(x: margin, y: pageHeight - margin - 12, width: pageWidth - margin * 2, height: 14)
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func sortedRows(_ rows: [ProductStockRow]) -> [ProductStockRow] {
        rows.sorted {
            ($0.product?.denumire ?? "").localizedStandardCompare($1.product?.denumire ?? "") == .orderedAscending
        }
    }

    @discardableResult
    private static func drawGroupedTables(
        rows: [ProductStockRow],
        at startY: CGFloat,
        pageWidth: CGFloat,
        contentBottom: CGFloat,
        beginPage: () -> Void,
        sectionFont: UIFont
    ) -> CGFloat {
        var y = startY
        let groups = groupedRows(from: rows)
        if groups.isEmpty {
            y = drawSection(L10n.tr("inventory.stocks_section"), at: y, pageWidth: pageWidth, font: sectionFont)
            return drawRowsTable(rows: [], at: y, contentBottom: contentBottom, beginPage: beginPage)
        }
        for (group, groupRows) in groups {
            if y > contentBottom - 80 {
                beginPage()
                y = margin
            }
            let title = L10n.tr("inventory.physical_category_section", group.label, groupRows.count)
            y = drawSection(title, at: y, pageWidth: pageWidth, font: sectionFont)
            y = drawRowsTable(rows: groupRows, at: y, contentBottom: contentBottom, beginPage: beginPage)
            y += 10
        }
        return y
    }

    private static var tableWidth: CGFloat { pageSize.width - margin * 2 }

    private static var tableHeaderValues: [String] {
        [
            L10n.tr("inventory.physical_pdf_col_no"),
            L10n.tr("inventory.physical_product"),
            L10n.tr("inventory.physical_field_code"),
            L10n.tr("inventory.physical_field_barcode"),
            L10n.tr("inventory.field_unit"),
            L10n.tr("inventory.field_quantity")
        ]
    }

    @discardableResult
    private static func drawRowsTable(
        rows: [ProductStockRow],
        at startY: CGFloat,
        contentBottom: CGFloat,
        beginPage: () -> Void
    ) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 8)
        let bodyFont = UIFont.systemFont(ofSize: 8)
        let widths = columnWidths(for: tableWidth)
        var y = startY

        func ensureSpace(for rowHeight: CGFloat) {
            if y + rowHeight > contentBottom {
                beginPage()
                y = margin
                y = drawTableRow(values: tableHeaderValues, columnWidths: widths, y: y, font: headerFont, isHeader: true, isAlternateRow: false)
            }
        }

        y = drawTableRow(values: tableHeaderValues, columnWidths: widths, y: y, font: headerFont, isHeader: true, isAlternateRow: false)

        if rows.isEmpty {
            let empty = ["—", L10n.tr("common.no_records"), "", "", "", ""]
            ensureSpace(for: 14)
            return drawTableRow(values: empty, columnWidths: widths, y: y, font: bodyFont, isHeader: false, isAlternateRow: false)
        }

        for (index, row) in rows.enumerated() {
            let values = [
                "\(index + 1)",
                row.product?.denumire ?? L10n.tr("inventory.unknown_product"),
                row.product?.cod ?? "",
                row.product?.codBare ?? "",
                row.product?.unitateMasura ?? "buc",
                SupplierFormatting.stockQuantityString(row.cantitate)
            ]
            let height = estimatedRowHeight(values: values, columnWidths: widths, font: bodyFont)
            ensureSpace(for: height)
            y = drawTableRow(
                values: values,
                columnWidths: widths,
                y: y,
                font: bodyFont,
                isHeader: false,
                isAlternateRow: !index.isMultiple(of: 2)
            )
        }
        return y
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
        y: CGFloat,
        font: UIFont,
        isHeader: Bool,
        isAlternateRow: Bool
    ) -> CGFloat {
        let padding: CGFloat = 2
        let rowHeight = estimatedRowHeight(values: values, columnWidths: columnWidths, font: font)
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
            UIColor.separator.setStroke()
            path.stroke()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = index == 1 ? .left : .right
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

    private static func estimatedRowHeight(values: [String], columnWidths: [CGFloat], font: UIFont) -> CGFloat {
        let padding: CGFloat = 2
        let minHeight: CGFloat = 12
        let heights = zip(values, columnWidths).enumerated().map { index, pair in
            measureTextHeight(pair.0, width: pair.1 - padding * 2, font: font, alignLeft: index == 1)
        }
        return max(heights.max() ?? minHeight, minHeight) + padding * 2
    }

    private static func measureTextHeight(_ text: String, width: CGFloat, font: UIFont, alignLeft: Bool) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignLeft ? .left : .right
        paragraph.lineBreakMode = .byWordWrapping
        return ceil(
            text.boundingRect(
                with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            ).height
        )
    }

    private static func detailLine(_ label: String, _ value: String?) -> String {
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
    private static func drawText(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont, color: UIColor = .black) -> CGFloat {
        drawAlignedText(text, at: y, pageWidth: pageWidth, font: font, color: color, alignment: .left)
    }

    @discardableResult
    private static func drawRightAlignedText(_ text: String, at y: CGFloat, pageWidth: CGFloat, font: UIFont, color: UIColor) -> CGFloat {
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
        text.draw(in: CGRect(x: margin, y: y, width: maxWidth, height: ceil(height)), withAttributes: attributes)
        return y + ceil(height) + 4
    }
}
