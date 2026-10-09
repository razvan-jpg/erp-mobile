import Foundation
import UIKit

/// PDF tip BINA Customer Invoice Receipt (bon fiscal duplicat).
enum FiscalSaleReceiptPDFBuilder {
    private static let pageWidth: CGFloat = 226 // ~80mm thermal-ish width at 72dpi scaled

    static func makePDF(
        receipt: FiscalSaleReceipt,
        lines: [FiscalSaleReceiptLine],
        companyName: String,
        companyAddress: String,
        companyCUI: String?,
        locationName: String?,
        cashierLabel: String?
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: 900))
        return renderer.pdfData { context in
            var y: CGFloat = 16
            let margin: CGFloat = 10
            let contentWidth = pageWidth - margin * 2

            context.beginPage()

            func draw(_ text: String, font: UIFont, x: CGFloat? = nil, width: CGFloat? = nil, align: NSTextAlignment = .left) -> CGFloat {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = align
                paragraph.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraph
                ]
                let w = width ?? contentWidth
                let originX = x ?? margin
                let rect = CGRect(x: originX, y: y, width: w, height: 400)
                let bound = (text as NSString).boundingRect(
                    with: CGSize(width: w, height: 400),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                )
                (text as NSString).draw(in: rect, withAttributes: attrs)
                return ceil(bound.height)
            }

            let titleFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 8)
            let smallFont = UIFont.systemFont(ofSize: 7)
            let mono = UIFont.monospacedDigitSystemFont(ofSize: 8, weight: .regular)

            if let cashierLabel, !cashierLabel.isEmpty {
                y += draw(cashierLabel, font: titleFont, align: .center)
            }
            y += draw(companyName, font: titleFont, align: .center) + 2
            if !companyAddress.isEmpty {
                y += draw(companyAddress, font: smallFont, align: .center) + 2
            }
            if let companyCUI, !companyCUI.isEmpty {
                y += draw("Cod fiscal: \(companyCUI)", font: smallFont, align: .center) + 4
            }

            y += draw(dateTimeString(receipt.issuedAt), font: bodyFont, align: .center) + 2
            let numberLine = receipt.receiptNumber.isEmpty
                ? L10n.tr("module.sales.cash_sale.receipt_untitled")
                : receipt.receiptNumber
            y += draw(numberLine, font: titleFont, align: .center) + 8

            if lines.isEmpty {
                y += draw(L10n.tr("module.sales.cash_sale.receipt_pdf_no_lines"), font: smallFont, align: .center) + 6
            } else {
                for line in lines {
                    let qty = amountString(line.cantitate)
                    let unit = amountString(line.pretUnitar)
                    y += draw("\(qty) x  \(unit)", font: mono) + 1
                    y += draw(line.denumire, font: bodyFont) + 1
                    let gross = amountString(line.lineGross)
                    y += draw(gross, font: mono, align: .right) + 2
                    if line.discountAmount > 0 {
                        y += draw(
                            L10n.tr("module.sales.cash_sale.receipt_pdf_discount", amountString(line.discountAmount)),
                            font: smallFont
                        ) + 2
                    }
                }
            }

            y += 6
            y += draw(L10n.tr("module.sales.cash_sale.receipt_pdf_total", amountString(receipt.totalAmount)), font: titleFont) + 6

            let vatBuckets = vatBuckets(from: lines)
            for bucket in vatBuckets {
                y += draw("\(bucket.label)  \(amountString(bucket.brut))", font: smallFont) + 1
                y += draw("\(bucket.vatLabel)  \(amountString(bucket.tva))", font: smallFont) + 2
            }

            y += 4
            if receipt.numerar > 0 {
                y += draw(L10n.tr("module.sales.cash_sale.receipt_pdf_cash", amountString(receipt.numerar)), font: bodyFont) + 1
            }
            if receipt.card > 0 {
                y += draw(L10n.tr("module.sales.cash_sale.receipt_pdf_card", amountString(receipt.card)), font: bodyFont) + 1
            }
            if receipt.plataModerna > 0 {
                y += draw(L10n.tr("module.sales.cash_sale.receipt_pdf_moderna", amountString(receipt.plataModerna)), font: bodyFont) + 1
            }

            if let locationName, !locationName.isEmpty {
                y += 6
                y += draw(locationName, font: smallFont, align: .center)
            }
            y += 4
            y += draw("* DUPLICAT *", font: titleFont, align: .center)
        }
    }

    private struct VATBucket {
        let label: String
        let vatLabel: String
        let brut: Decimal
        let tva: Decimal
    }

    private static func vatBuckets(from lines: [FiscalSaleReceiptLine]) -> [VATBucket] {
        let groups = Dictionary(grouping: lines) { normalizedVAT($0.cotaTva) }
        let order: [Decimal] = [21, 11, 0]
        var result: [VATBucket] = []
        for rate in order {
            guard let group = groups[rate], !group.isEmpty else { continue }
            let brut = group.reduce(Decimal.zero) { $0 + $1.lineGross }
            let tva = vatFromGross(brut, rate: rate)
            let letter: String
            switch rate {
            case 21: letter = "A"
            case 11: letter = "B"
            default: letter = "D"
            }
            result.append(VATBucket(
                label: "BRUT \(letter)",
                vatLabel: "TVA \(letter) \(NSDecimalNumber(decimal: rate).stringValue)%",
                brut: brut,
                tva: tva
            ))
        }
        return result
    }

    private static func normalizedVAT(_ rate: Decimal) -> Decimal {
        if rate >= 20 { return 21 }
        if rate >= 5 { return 11 }
        return 0
    }

    private static func vatFromGross(_ gross: Decimal, rate: Decimal) -> Decimal {
        guard rate > 0 else { return 0 }
        let divisor = 1 + rate / 100
        let net = gross / divisor
        return (gross - net as NSDecimalNumber).rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )) as Decimal
    }

    private static func amountString(_ value: Decimal) -> String {
        SupplierFormatting.amountString(value)
    }

    private static func dateTimeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ro_RO")
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}
