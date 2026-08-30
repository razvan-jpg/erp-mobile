import Foundation
import PDFKit
import UIKit

enum CashRegisterJournalPDFBuilder {
    static func makePDF(pages: [CashRegisterDailyJournal], templateData: Data) -> Data {
        guard let templateDocument = PDFDocument(data: templateData),
              let templatePage = templateDocument.page(at: 0) else {
            return makeFallbackPDF(pages: pages)
        }

        let pageRect = CGRect(origin: .zero, size: CashRegisterJournalTemplateLayout.pageSize)
        let templateRect = CGRect(origin: .zero, size: CashRegisterJournalTemplateLayout.templateContentSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for journal in pages {
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                let cgContext = context.cgContext
                cgContext.saveGState()
                let scaleX = pageRect.width / templateRect.width
                let scaleY = pageRect.height / templateRect.height
                cgContext.scaleBy(x: scaleX, y: scaleY)
                drawTemplate(templatePage, in: templateRect, context: cgContext)
                drawOverlay(journal: journal, in: templateRect, context: cgContext)
                cgContext.restoreGState()
            }
        }
    }

    static func makePDF(page: CashRegisterDailyJournal, templateData: Data) -> Data {
        makePDF(pages: [page], templateData: templateData)
    }

    private static func drawTemplate(_ templatePage: PDFPage, in pageRect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        templatePage.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }

    private static func drawOverlay(journal: CashRegisterDailyJournal, in pageRect: CGRect, context: CGContext) {
        let bodyFont = UIFont.systemFont(ofSize: CashRegisterJournalTemplateLayout.bodyFontSize)
        let headerFont = UIFont.systemFont(ofSize: CashRegisterJournalTemplateLayout.headerFontSize)
        let pageHeight = pageRect.height

        let dateParts = CashRegisterJournalFormatting.displayDate(journal.date)
        drawText(
            journal.companyName,
            pdfPoint: CashRegisterJournalTemplateLayout.companyName,
            pageHeight: pageHeight,
            font: headerFont,
            context: context
        )
        drawText(
            journal.companyRegistration,
            pdfPoint: CashRegisterJournalTemplateLayout.registration,
            pageHeight: pageHeight,
            font: bodyFont,
            context: context
        )
        if !journal.companyAddress.isEmpty {
            drawText(
                journal.companyAddress,
                pdfPoint: CashRegisterJournalTemplateLayout.address,
                pageHeight: pageHeight,
                font: bodyFont,
                context: context
            )
        }

        drawTextInPdfBox(
            dateParts.day,
            box: CashRegisterJournalTemplateLayout.dateDayBox,
            pageHeight: pageHeight,
            font: bodyFont,
            context: context
        )
        drawTextInPdfBox(
            dateParts.month,
            box: CashRegisterJournalTemplateLayout.dateMonthBox,
            pageHeight: pageHeight,
            font: bodyFont,
            context: context
        )
        drawTextInPdfBox(
            dateParts.year,
            box: CashRegisterJournalTemplateLayout.dateYearBox,
            pageHeight: pageHeight,
            font: bodyFont,
            context: context
        )
        drawTextInPdfBox(
            journal.casaAccount,
            box: CashRegisterJournalTemplateLayout.contCasaBox,
            pageHeight: pageHeight,
            font: bodyFont,
            context: context
        )

        for line in journal.lines {
            draw(line: line, pageHeight: pageHeight, context: context, font: bodyFont)
        }

        let lastOperationRow = journal.lines
            .map(\.rowNumber)
            .filter { (1...15).contains($0) }
            .max() ?? 0
        if lastOperationRow < 14 {
            drawDiagonalEmptyRowsBlock(fromRow: lastOperationRow + 1, toRow: 14, pageHeight: pageHeight, context: context)
        }
    }

    private static func draw(line: CashRegisterJournalLine, pageHeight: CGFloat, context: CGContext, font: UIFont) {
        guard let baselineY = CashRegisterJournalTemplateLayout.rowBaselines[line.rowNumber] else { return }
        let cols = CashRegisterJournalTemplateLayout.columns
        let isTemplateLabelRow = line.rowNumber == 0 || line.rowNumber == 16

        if !isTemplateLabelRow {
            drawText(
                String(line.rowNumber),
                pdfPoint: CGPoint(x: 88, y: baselineY),
                pageHeight: pageHeight,
                font: font,
                context: context,
                alignment: .center,
                maxWidth: 20
            )
        }

        if !line.actCasaNumber.isEmpty {
            drawText(line.actCasaNumber, pdfPoint: CGPoint(x: cols.actCasa, y: baselineY), pageHeight: pageHeight, font: font, context: context, maxWidth: 44)
        }
        if !line.actAnexaNumber.isEmpty {
            drawText(line.actAnexaNumber, pdfPoint: CGPoint(x: cols.anexa, y: baselineY), pageHeight: pageHeight, font: font, context: context, maxWidth: 44)
        }
        if !isTemplateLabelRow, !line.explanation.isEmpty {
            drawText(line.explanation, pdfPoint: CGPoint(x: cols.explicatie, y: baselineY), pageHeight: pageHeight, font: font, context: context, maxWidth: 240)
        }
        if let incasari = line.incasari {
            drawAmount(
                incasari,
                leftEdgeX: cols.incasariLeft,
                rightEdgeX: cols.incasariRight,
                baselinePdfY: baselineY,
                pageHeight: pageHeight,
                font: font,
                context: context
            )
        }
        if let plati = line.plati {
            drawAmount(
                plati,
                leftEdgeX: cols.platiLeft,
                rightEdgeX: cols.platiRight,
                baselinePdfY: baselineY,
                pageHeight: pageHeight,
                font: font,
                context: context
            )
        }
        if let simbol = line.simbolCont {
            drawAmount(
                simbol,
                leftEdgeX: cols.simbolLeft,
                rightEdgeX: cols.simbolRight,
                baselinePdfY: baselineY,
                pageHeight: pageHeight,
                font: font,
                context: context
            )
        }
    }

    private static func drawDiagonalEmptyRowsBlock(
        fromRow: Int,
        toRow: Int,
        pageHeight: CGFloat,
        context: CGContext
    ) {
        guard fromRow <= toRow else { return }

        let start = CGPoint(
            x: CashRegisterJournalTemplateLayout.strikeLineStartX,
            y: pageHeight - CashRegisterJournalTemplateLayout.rowCellTopPdfY(fromRow)
        )
        let end = CGPoint(
            x: CashRegisterJournalTemplateLayout.strikeLineEndX,
            y: pageHeight - CashRegisterJournalTemplateLayout.rowCellBottomPdfY(toRow)
        )

        context.saveGState()
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(0.9)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawAmount(
        _ value: Decimal,
        leftEdgeX: CGFloat,
        rightEdgeX: CGFloat,
        baselinePdfY: CGFloat,
        pageHeight: CGFloat,
        font: UIFont,
        context: CGContext
    ) {
        let padding = CashRegisterJournalTemplateLayout.amountRightPadding
        let maxWidth = max(24, rightEdgeX - leftEdgeX - padding * 2)
        drawText(
            CashRegisterJournalFormatting.amount(value),
            pdfPoint: CGPoint(x: rightEdgeX - padding, y: baselinePdfY),
            pageHeight: pageHeight,
            font: font,
            context: context,
            alignment: .right,
            maxWidth: maxWidth
        )
    }

    private static func drawTextInPdfBox(
        _ text: String,
        box: CGRect,
        pageHeight: CGFloat,
        font: UIFont,
        context: CGContext
    ) {
        guard !text.isEmpty else { return }
        let uiRect = CGRect(
            x: box.minX,
            y: pageHeight - box.minY - box.height,
            width: box.width,
            height: box.height
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.boundingRect(
            with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let centered = CGRect(
            x: uiRect.minX,
            y: uiRect.midY - ceil(size.height) / 2,
            width: uiRect.width,
            height: ceil(size.height)
        )
        UIGraphicsPushContext(context)
        attributed.draw(with: centered, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        UIGraphicsPopContext()
    }

    private static func drawText(
        _ text: String,
        pdfPoint: CGPoint,
        pageHeight: CGFloat,
        font: UIFont,
        context: CGContext,
        alignment: NSTextAlignment = .left,
        maxWidth: CGFloat = 240
    ) {
        guard !text.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let size = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let baselineY = pageHeight - pdfPoint.y
        let originX: CGFloat
        switch alignment {
        case .right:
            originX = pdfPoint.x - maxWidth
        case .center:
            originX = pdfPoint.x - maxWidth / 2
        default:
            originX = pdfPoint.x
        }
        let rect = CGRect(
            x: originX,
            y: baselineY - ceil(size.height) + 2,
            width: maxWidth,
            height: ceil(size.height)
        )
        UIGraphicsPushContext(context)
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        UIGraphicsPopContext()
    }

    private static func makeFallbackPDF(pages: [CashRegisterDailyJournal]) -> Data {
        let pageRect = CGRect(origin: .zero, size: CashRegisterJournalTemplateLayout.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            for journal in pages {
                context.beginPage()
                drawOverlay(journal: journal, in: pageRect, context: context.cgContext)
            }
        }
    }
}
