import UIKit

enum ReorderNeedPDFBuilder {
    private static let pageSize = CGSize(width: 595, height: 842)
    private static let margin: CGFloat = 36
    private static let fractions: [CGFloat] = [0.10, 0.28, 0.07, 0.12, 0.13, 0.14, 0.16]

    static func makePDF(
        companyName: String,
        warehouseName: String,
        rows: [StockReorderRow],
        generatedAt: Date
    ) -> Data {
        let total = max(render(companyName: companyName, warehouseName: warehouseName, rows: rows, generatedAt: generatedAt, totalPages: nil).pageCount, 1)
        return render(companyName: companyName, warehouseName: warehouseName, rows: rows, generatedAt: generatedAt, totalPages: total).data
    }

    static func writeTemporaryPDF(
        companyName: String,
        warehouseName: String,
        rows: [StockReorderRow],
        generatedAt: Date
    ) throws -> URL {
        let data = makePDF(companyName: companyName, warehouseName: warehouseName, rows: rows, generatedAt: generatedAt)
        let safe = warehouseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Necesar-comanda-\(safe)-\(UUID().uuidString.prefix(8)).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    private struct RenderResult {
        let data: Data
        let pageCount: Int
    }

    private static func render(
        companyName: String,
        warehouseName: String,
        rows: [StockReorderRow],
        generatedAt: Date,
        totalPages: Int?
    ) -> RenderResult {
        let pageRect = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let headerFont = UIFont.boldSystemFont(ofSize: 9)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        let contentWidth = pageRect.width - margin * 2
        let headers = [
            L10n.tr("inventory.reorder_pdf_code"),
            L10n.tr("inventory.reorder_pdf_name"),
            L10n.tr("inventory.reorder_pdf_unit"),
            L10n.tr("inventory.reorder_current"),
            L10n.tr("inventory.reorder_needed"),
            L10n.tr("inventory.reorder_price"),
            L10n.tr("inventory.reorder_line_total")
        ]
        var pageCount = 0
        var currentPage = 0
        let data = renderer.pdfData { context in
            func beginPage() {
                if currentPage > 0, let totalPages {
                    drawFooter(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
                }
                context.beginPage()
                currentPage += 1
                pageCount = currentPage
            }

            beginPage()
            var y = margin
            y = draw(companyName, at: y, width: contentWidth, font: titleFont, pageWidth: pageRect.width)
            y = draw(L10n.tr("module.inventory.tab_reorder"), at: y + 4, width: contentWidth, font: titleFont, pageWidth: pageRect.width)
            y = draw(
                L10n.tr("inventory.field_warehouse") + ": " + warehouseName,
                at: y + 2,
                width: contentWidth,
                font: bodyFont,
                pageWidth: pageRect.width
            )
            y = draw(SupplierFormatting.date(generatedAt), at: y + 2, width: contentWidth, font: bodyFont, pageWidth: pageRect.width)
            y += 10
            y = drawRow(headers, at: y, contentWidth: contentWidth, font: headerFont, bold: true)
            let bottom = pageRect.height - margin - 28
            var lastCategory: ProductKind?
            for row in rows {
                if y > bottom - 32 {
                    beginPage()
                    y = margin
                    y = drawRow(headers, at: y, contentWidth: contentWidth, font: headerFont, bold: true)
                    lastCategory = nil
                }
                if row.tip != lastCategory {
                    lastCategory = row.tip
                    y = draw(row.tip.label, at: y + 4, width: contentWidth, font: headerFont, pageWidth: pageRect.width)
                }
                let values = [
                    row.cod ?? "",
                    row.denumire,
                    row.unitateMasura,
                    SupplierFormatting.stockQuantityString(row.cantitateCurenta),
                    SupplierFormatting.stockQuantityString(row.cantitateNecesara),
                    row.pretCuTva.map { SupplierFormatting.amountString($0) } ?? "—",
                    row.pretCuTva.map { SupplierFormatting.amountString(SupplierFormatting.roundAmount($0 * row.cantitateNecesara)) } ?? "—"
                ]
                y = drawRow(values, at: y, contentWidth: contentWidth, font: bodyFont, bold: false)
            }
            let orderTotal = rows.reduce(Decimal.zero) { partial, row in
                guard let price = row.pretCuTva else { return partial }
                return partial + SupplierFormatting.roundAmount(price * row.cantitateNecesara)
            }
            if y > bottom - 24 {
                beginPage()
                y = margin
            }
            y = drawRow(
                ["", L10n.tr("inventory.reorder_order_total_label"), "", "", "", "", SupplierFormatting.amountString(orderTotal) + " lei"],
                at: y + 6,
                contentWidth: contentWidth,
                font: headerFont,
                bold: true
            )
            if let totalPages {
                drawFooter(page: currentPage, total: totalPages, pageWidth: pageRect.width, pageHeight: pageRect.height)
            }
        }
        return RenderResult(data: data, pageCount: pageCount)
    }

    private static func drawFooter(page: Int, total: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let font = UIFont.systemFont(ofSize: 8)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = L10n.tr("inventory.stock_control_page", page, total) + "  ·  Document generat cu ERP Mobile by DateConta"
        let rect = CGRect(x: margin, y: pageHeight - margin - 10, width: pageWidth - margin * 2, height: 12)
        text.draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraph
        ])
    }

    @discardableResult
    private static func draw(_ text: String, at y: CGFloat, width: CGFloat, font: UIFont, pageWidth: CGFloat) -> CGFloat {
        let rect = CGRect(x: margin, y: y, width: width, height: 22)
        text.draw(in: rect, withAttributes: [.font: font, .foregroundColor: UIColor.black])
        return y + font.lineHeight + 2
    }

    private static func drawRow(_ values: [String], at y: CGFloat, contentWidth: CGFloat, font: UIFont, bold: Bool) -> CGFloat {
        var x = margin
        let height = font.lineHeight + 6
        for (index, value) in values.enumerated() {
            let width = contentWidth * fractions[index]
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            paragraph.alignment = index == 1 ? .left : .right
            if index == 0 || index == 2 { paragraph.alignment = .left }
            value.draw(in: CGRect(x: x, y: y, width: width - 4, height: height), withAttributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: font.pointSize) : font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ])
            x += width
        }
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y + height))
        line.addLine(to: CGPoint(x: margin + contentWidth, y: y + height))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.4
        line.stroke()
        return y + height
    }
}
