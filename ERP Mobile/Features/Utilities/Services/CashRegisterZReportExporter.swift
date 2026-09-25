import Foundation
import UIKit
#if canImport(PDFKit)
import PDFKit
#endif


// MARK: - BINA Z report PDF layout (eu.pdf: A4, 2 columns)

struct BinaZReportVisualModel: Sendable {
    var companyName: String = ""
    var companyAddress: String = ""
    var zNumber: String = ""
    var location: String = ""
    var posNumber: String = ""
    var user: String = ""
    var fromDate: String = ""
    var toDate: String = ""
    var documents: String = ""
    var total: String = ""
    var payments: [BinaZReportPaymentRow] = []
    var paymentSectionTotal: String = ""
    var vatGroups: [BinaZReportValueRow] = []
    var vatLines: [BinaZReportValueRow] = []
    var totalVAT: String = ""
    var totalSales: String = ""
}

struct BinaZReportPaymentRow: Sendable {
    let label: String
    let amount: String?
}

struct BinaZReportValueRow: Sendable {
    let label: String
    let amount: String
}

enum CashRegisterZReportBinaLayout {
    private struct PaymentSpec {
        let label: String
        let markers: [String]
    }

    private static let paymentSpecs: [PaymentSpec] = [
        PaymentSpec(label: "Numerar", markers: ["CASH", "NUMERAR"]),
        PaymentSpec(label: "Credit cards", markers: ["CREDIT CARDS"]),
        PaymentSpec(label: "Credit", markers: ["CREDIT"]),
        PaymentSpec(label: "Bon masă", markers: ["MEAL TICKET", "BON MASA", "BON MAS"]),
        PaymentSpec(label: "Jeton", markers: ["JETON"]),
        PaymentSpec(label: "Card masă", markers: ["MEAL CARD", "CARD MASA", "CARD MAS"]),
        PaymentSpec(label: "Plata moderna", markers: ["PLATA MODERNA"]),
        PaymentSpec(label: "Voucher", markers: ["VOUCHER"]),
    ]

    static func build(from text: String, fallbackZNumber: String? = nil) -> BinaZReportVisualModel {
        let normalized = BinaPosZReportTextNormalizer.preservedLines(text)
        let rawLines = normalized.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var model = BinaZReportVisualModel()
        model.companyName = companyName(from: rawLines)
        model.companyAddress = companyAddress(from: rawLines)
        model.zNumber = zNumber(from: rawLines, fallback: fallbackZNumber)
        model.location = fieldValue(in: rawLines, labels: ["LOCATION", "LOCATIA", "LOCAŢIA", "LOCAȚIA"])
        model.posNumber = fieldValue(in: rawLines, labels: ["POS NUMBER", "NUMAR POS", "NUMĂR POS"])
        model.user = fieldValue(in: rawLines, labels: ["USER", "UTILIZATOR"])
        model.fromDate = fieldValue(in: rawLines, labels: ["FROM", "DE LA"])
        model.toDate = fieldValue(in: rawLines, labels: ["TO", "PANA LA", "PÂNĂ LA"])
        model.documents = fieldValue(in: rawLines, labels: ["DOCUMENTS", "DOCUMENTE"])
        model.total = amountValue(in: rawLines, labels: ["TOTAL"], skipPaymentSection: false)
        model.payments = paymentRows(from: rawLines)
        model.paymentSectionTotal = paymentSectionTotal(from: rawLines) ?? model.total
        model.vatGroups = vatGroups(from: rawLines)
        model.vatLines = vatLines(from: rawLines)
        model.totalVAT = fieldValue(in: rawLines, labels: ["TOTAL VAT", "TOTAL TVA"])
        model.totalSales = amountValue(in: rawLines, labels: ["TOTAL SOLD", "TOTAL VANZARI", "TOTAL VÂNZĂRI", "TOTAL VANZĂRI"], skipPaymentSection: true)

        return model
    }

    static func plainText(from model: BinaZReportVisualModel) -> String {
        var lines: [String] = []
        if !model.companyName.isEmpty { lines.append(model.companyName) }
        if !model.companyAddress.isEmpty { lines.append(model.companyAddress) }
        lines.append("Z report Numar \(model.zNumber)")
        lines.append("Locatia \(model.location)")
        lines.append("POS number \(model.posNumber)")
        lines.append("User \(model.user)")
        lines.append("Dela \(model.fromDate)")
        lines.append("Pana la \(model.toDate)")
        lines.append("Documents \(model.documents)")
        lines.append("Total \(model.total)")
        lines.append("Metode de Plata")
        for row in model.payments {
            if let amount = row.amount, !amount.isEmpty {
                lines.append("\(row.label) \(amount)")
            } else {
                lines.append(row.label)
            }
        }
        lines.append("Total \(model.paymentSectionTotal)")
        lines.append("TVA")
        for row in model.vatGroups {
            lines.append("\(row.label) \(row.amount)")
        }
        for row in model.vatLines {
            lines.append("\(row.label) \(row.amount)")
        }
        lines.append("Total TVA \(model.totalVAT)")
        lines.append("Total vanzari \(model.totalSales)")
        return lines.joined(separator: "\n")
    }

    private static func companyName(from lines: [String]) -> String {
        guard let index = lines.firstIndex(where: { isZHeaderLine(folded($0)) }) else {
            return lines.first(where: { !$0.isEmpty }) ?? ""
        }
        let candidates = lines.prefix(index).filter { !$0.isEmpty }
        return candidates.first ?? ""
    }

    private static func companyAddress(from lines: [String]) -> String {
        guard let index = lines.firstIndex(where: { isZHeaderLine(folded($0)) }) else {
            return lines.dropFirst().first(where: { !$0.isEmpty }) ?? ""
        }
        let candidates = lines.prefix(index).filter { !$0.isEmpty }
        return candidates.dropFirst().first ?? ""
    }

    private static func zNumber(from lines: [String], fallback: String?) -> String {
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            if upper.hasPrefix("Z REPORT NO") || upper.hasPrefix("Z REPORT NUMAR") || upper.hasPrefix("Z REPORT NUMĂR") {
                if let inline = inlineNumber(from: line, after: "Z REPORT") { return inline }
                if let next = nextMeaningfulLine(in: lines, start: index + 1),
                   next.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil {
                    return next
                }
            }
        }
        if let fallback, !fallback.isEmpty { return fallback.filter(\.isNumber) }
        return ""
    }

    private static func fieldValue(in lines: [String], labels: [String]) -> String {
        let markers = Set(labels.map { folded($0) })
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            if markers.contains(upper) {
                if let inline = valueAfterLabel(line, knownLabels: labels) { return inline }
                return nextMeaningfulLine(in: lines, start: index + 1) ?? ""
            }
            for label in labels {
                if upper.hasPrefix(folded(label) + " ") {
                    return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return ""
    }

    private static func amountValue(in lines: [String], labels: [String], skipPaymentSection: Bool) -> String {
        let markers = Set(labels.map { folded($0) })
        var inPayments = false
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            if upper.contains("PAYMENT") || upper.contains("METODE DE PLAT") { inPayments = true }
            if upper.contains("VAT GROUP") || upper == "TVA" { inPayments = false }
            if skipPaymentSection && inPayments { continue }
            if markers.contains(upper) {
                if let inline = valueAfterLabel(line, knownLabels: labels) {
                    return formatRON(inline)
                }
                if let amount = nextAmountLine(in: lines, start: index + 1) {
                    return formatRON(amount)
                }
            }
        }
        return ""
    }

    private static func paymentRows(from lines: [String]) -> [BinaZReportPaymentRow] {
        var extracted: [String: String] = [:]
        var inPayments = false
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            if upper.contains("PAYMENT TYPES") || upper.contains("METODE DE PLAT") {
                inPayments = true
                continue
            }
            if !inPayments { continue }
            if upper == "TOTAL" || upper.contains("VAT GROUP") || upper == "TVA" { break }

            for spec in paymentSpecs {
                if upper == spec.markers.first || spec.markers.contains(upper) {
                    if let inline = inlineAmount(from: line, afterLabel: spec.markers[0]) {
                        extracted[spec.label] = formatRON(inline)
                    } else if let amount = nextAmountLine(in: lines, start: index + 1) {
                        extracted[spec.label] = formatRON(amount)
                    }
                    break
                }
            }
        }

        return paymentSpecs.map { spec in
            BinaZReportPaymentRow(label: spec.label, amount: extracted[spec.label])
        }
    }

    private static func paymentSectionTotal(from lines: [String]) -> String? {
        var inPayments = false
        var sawPaymentHeader = false
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            if upper.contains("PAYMENT TYPES") || upper.contains("METODE DE PLAT") {
                inPayments = true
                sawPaymentHeader = true
                continue
            }
            if !inPayments { continue }
            if upper.contains("VAT GROUP") || upper == "TVA" { break }
            if upper == "TOTAL" && sawPaymentHeader {
                if let inline = inlineAmount(from: line, afterLabel: "Total") { return formatRON(inline) }
                if let amount = nextAmountLine(in: lines, start: index + 1) { return formatRON(amount) }
            }
        }
        return nil
    }

    private static func vatGroups(from lines: [String]) -> [BinaZReportValueRow] {
        [
            mergedBrutRow(in: lines, category: "A", rate: "21", label: "BRUT A TVA 21%"),
            mergedBrutRow(in: lines, category: "B", rate: "11", label: "BRUT B TVA 11%"),
            mergedBrutRow(in: lines, category: "D", rate: "0", label: "BRUT D TVA 0%"),
        ].compactMap { $0 }
    }

    private static func mergedBrutRow(
        in lines: [String],
        category: String,
        rate: String,
        label: String
    ) -> BinaZReportValueRow? {
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            guard upper.hasPrefix("BRUT \(category)") || upper == "BRUT \(category)" else { continue }
            if let inline = inlineAmount(from: line, afterLabel: "BRUT \(category) VAT \(rate)%") {
                return BinaZReportValueRow(label: label, amount: inline)
            }
            if let inline = inlineAmount(from: line, afterLabel: "BRUT \(category) TVA \(rate)%") {
                return BinaZReportValueRow(label: label, amount: inline)
            }
            var amountIndex = index + 1
            while amountIndex < lines.count {
                let candidate = folded(lines[amountIndex])
                if candidate.hasPrefix("VAT \(rate)") || candidate.hasPrefix("TVA \(rate)") {
                    amountIndex += 1
                    continue
                }
                if let amount = nextAmountLine(in: lines, start: amountIndex) {
                    return BinaZReportValueRow(label: label, amount: amount)
                }
                break
            }
        }
        return nil
    }

    private static func vatLines(from lines: [String]) -> [BinaZReportValueRow] {
        collectValueRows(from: lines, prefixes: [
            ("VAT A 21%", "TVA A 21%"),
            ("TVA A 21%", "TVA A 21%"),
            ("VAT B 11%", "TVA B 11%"),
            ("TVA B 11%", "TVA B 11%"),
            ("VAT D 0%", "TVA D 0%"),
            ("TVA D 0%", "TVA D 0%"),
        ])
    }

    private static func collectValueRows(from lines: [String], prefixes: [(String, String)]) -> [BinaZReportValueRow] {
        var rows: [BinaZReportValueRow] = []
        var seen = Set<String>()
        for (index, line) in lines.enumerated() {
            let upper = folded(line)
            for (marker, label) in prefixes {
                guard !seen.contains(label), upper.hasPrefix(folded(marker)) else { continue }
                if let inline = inlineAmount(from: line, afterLabel: marker) {
                    rows.append(BinaZReportValueRow(label: label, amount: inline))
                    seen.insert(label)
                } else if let amount = nextAmountLine(in: lines, start: index + 1) {
                    rows.append(BinaZReportValueRow(label: label, amount: amount))
                    seen.insert(label)
                }
            }
        }
        return rows
    }

    private static func isZHeaderLine(_ upper: String) -> Bool {
        upper.hasPrefix("Z REPORT")
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US")).uppercased()
    }

    private static func nextMeaningfulLine(in lines: [String], start: Int) -> String? {
        var index = start
        while index < lines.count {
            let line = lines[index]
            if !line.isEmpty { return line }
            index += 1
        }
        return nil
    }

    private static func nextAmountLine(in lines: [String], start: Int) -> String? {
        var index = start
        while index < lines.count {
            let line = lines[index]
            if line.isEmpty {
                index += 1
                continue
            }
            if folded(line) == "RON" {
                index += 1
                continue
            }
            if line.range(of: #"\d"#, options: .regularExpression) != nil {
                return stripRON(from: line)
            }
            return nil
        }
        return nil
    }

    private static func inlineNumber(from line: String, after prefix: String) -> String? {
        let pattern = #"(?i)Z\s*report\s*(?:No\.?|Num[aă]r)\s*(\d{1,4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }

    private static func valueAfterLabel(_ line: String, knownLabels: [String]) -> String? {
        for label in knownLabels {
            let foldedLabel = folded(label)
            let foldedLine = folded(line)
            if foldedLine == foldedLabel { return nil }
            if foldedLine.hasPrefix(foldedLabel + " ") {
                return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func inlineAmount(from line: String, afterLabel: String) -> String? {
        let foldedLine = folded(line)
        let foldedLabel = folded(afterLabel)
        guard foldedLine.hasPrefix(foldedLabel) else { return nil }
        let remainder = line.dropFirst(afterLabel.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.range(of: #"\d"#, options: .regularExpression) != nil else { return nil }
        return stripRON(from: remainder)
    }

    private static func stripRON(from text: String) -> String {
        text.replacingOccurrences(of: "(?i)\\s*RON\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatRON(_ amount: String) -> String {
        let trimmed = stripRON(from: amount)
        guard !trimmed.isEmpty else { return "" }
        return trimmed + " RON"
    }

    // MARK: PDF layout (eu.pdf)

    private static let pdfPageSize = CGSize(width: 595, height: 842)
    private static let pdfLabelX: CGFloat = 42.4
    private static let pdfValueX: CGFloat = 324.2
    private static let pdfTopY: CGFloat = 22
    private static let pdfHeaderStep: CGFloat = 13.5
    private static let pdfRowStep: CGFloat = 11.5
    private static let pdfSectionGap: CGFloat = 22.7

    static func makePDF(from model: BinaZReportVisualModel) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pdfPageSize))
        return renderer.pdfData { context in
            context.beginPage()
            var y = pdfTopY

            y = pdfDraw(text: model.companyName, at: CGPoint(x: pdfLabelX, y: y), font: pdfBoldFont(size: 9.6))
            y += pdfHeaderStep
            y = pdfDraw(text: model.companyAddress, at: CGPoint(x: pdfLabelX, y: y), font: pdfRegularFont(size: 7.7), maxWidth: 520)
            y += pdfHeaderStep + 8

            y = pdfDraw(text: "Z report Număr \(model.zNumber)", at: CGPoint(x: pdfLabelX, y: y), font: pdfBoldFont(size: 9.6))
            y += pdfRowStep + 2

            y = pdfDrawRow(label: "Locaţia", value: model.location, y: y)
            y = pdfDrawRow(label: "Număr POS", value: model.posNumber, y: y)
            y = pdfDrawRow(label: "Utilizator", value: model.user, y: y)
            y = pdfDrawRow(label: "De la", value: model.fromDate, y: y)
            y = pdfDrawRow(label: "Până la", value: model.toDate, y: y)
            y = pdfDrawRow(label: "Documente", value: model.documents, y: y)
            y = pdfDrawRow(label: "Total", value: formatRON(model.total), y: y, boldValue: true)

            y += pdfSectionGap - pdfRowStep
            y = pdfDraw(text: "Metode de Plată", at: CGPoint(x: pdfLabelX, y: y), font: pdfRegularFont(size: 9.0))
            y += pdfRowStep + 2

            for payment in model.payments {
                if let amount = payment.amount, !amount.isEmpty {
                    y = pdfDrawRow(label: payment.label, value: formatRON(amount), y: y)
                } else {
                    y = pdfDraw(text: payment.label, at: CGPoint(x: pdfLabelX, y: y), font: pdfRegularFont(size: 7.7))
                    y += pdfRowStep
                }
            }
            y = pdfDrawRow(label: "Total", value: formatRON(model.paymentSectionTotal), y: y, boldValue: true)

            y += pdfSectionGap - pdfRowStep
            y = pdfDraw(text: "TVA", at: CGPoint(x: pdfLabelX, y: y), font: pdfRegularFont(size: 9.0))
            y += pdfRowStep + 2

            for row in model.vatGroups {
                y = pdfDrawRow(label: row.label, value: row.amount, y: y)
            }
            for row in model.vatLines {
                y = pdfDrawRow(label: row.label, value: row.amount, y: y)
            }
            y = pdfDrawRow(label: "Total TVA", value: model.totalVAT, y: y)
            y = pdfDrawRow(label: "Total vânzări", value: stripRON(from: model.totalSales), y: y, boldValue: true)
            _ = y
        }
    }

    private static func pdfRegularFont(size: CGFloat) -> UIFont {
        UIFont(name: "Helvetica", size: size) ?? UIFont.systemFont(ofSize: size)
    }

    private static func pdfBoldFont(size: CGFloat) -> UIFont {
        UIFont(name: "Helvetica-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
    }

    private static func pdfDrawRow(label: String, value: String, y: CGFloat, boldValue: Bool = false) -> CGFloat {
        _ = pdfDraw(text: label, at: CGPoint(x: pdfLabelX, y: y), font: pdfRegularFont(size: 7.7))
        let font = boldValue ? pdfBoldFont(size: 7.7) : pdfRegularFont(size: 7.7)
        _ = pdfDraw(text: value, at: CGPoint(x: pdfValueX, y: y), font: font)
        return y + pdfRowStep
    }

    @discardableResult
    private static func pdfDraw(text: String, at origin: CGPoint, font: UIFont, maxWidth: CGFloat? = nil) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        if let maxWidth {
            let rect = CGRect(x: origin.x, y: origin.y, width: maxWidth, height: 1000)
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            return origin.y + ceil(bounding.height)
        }
        (text as NSString).draw(at: origin, withAttributes: attrs)
        return origin.y + font.lineHeight
    }
}



/// Detectează PDF-ul original BINA (wkhtmltopdf) vs. PDF reconstruit în app (Quartz).
enum CashRegisterZReportPDFSource {
    nonisolated static func isValidPDF(_ data: Data) -> Bool {
        data.starts(with: [0x25, 0x50, 0x44, 0x46])
    }

    nonisolated static func isAppGeneratedPDF(_ data: Data) -> Bool {
        guard isValidPDF(data) else { return false }
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { return false }
        let producer = (document.documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String) ?? ""
        return producer.localizedCaseInsensitiveContains("Quartz PDFContext")
        #else
        return false
        #endif
    }

    nonisolated static func isBinaOriginalPDF(_ data: Data) -> Bool {
        guard isValidPDF(data), !isAppGeneratedPDF(data) else { return false }
        #if canImport(PDFKit)
        if let document = PDFDocument(data: data) {
            let producer = (document.documentAttributes?[PDFDocumentAttribute.producerAttribute] as? String) ?? ""
            let creator = (document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String) ?? ""
            let title = (document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String) ?? ""
            if creator.localizedCaseInsensitiveContains("wkhtmltopdf") { return true }
            if producer.localizedCaseInsensitiveContains("Qt") { return true }
            if title.localizedCaseInsensitiveContains("BinaSmartBusiness") { return true }
        }
        #endif
        if containsUTF16LE(data, ascii: "wkhtmltopdf") { return true }
        if containsUTF16LE(data, ascii: "BinaSmartBusiness") { return true }
        if let header = String(data: data.prefix(16384), encoding: .isoLatin1) {
            if header.localizedCaseInsensitiveContains("wkhtmltopdf") { return true }
            if header.localizedCaseInsensitiveContains("BinaSmartBusiness") { return true }
        }
        return false
    }

    nonisolated private static func containsUTF16LE(_ data: Data, ascii: String) -> Bool {
        var pattern = Data()
        for scalar in ascii.unicodeScalars {
            pattern.append(UInt8(scalar.value))
            pattern.append(0)
        }
        return data.range(of: pattern) != nil
    }

    nonisolated static func pdfDataLooksEnglish(_ data: Data) -> Bool {
        if containsUTF16LE(data, ascii: "Location") || containsUTF16LE(data, ascii: "Payment types") { return true }
        if containsUTF16LE(data, ascii: "Total Sold") || containsUTF16LE(data, ascii: "BRUT A VAT") { return true }
        if let latin = String(data: data, encoding: .isoLatin1) {
            if latin.contains("Location") || latin.contains("Payment types") { return true }
        }
        return false
    }

    nonisolated static func pdfDataLooksRomanian(_ data: Data) -> Bool {
        if containsUTF16LE(data, ascii: "Loca") || containsUTF16LE(data, ascii: "Metode de Plat") { return true }
        if containsUTF16LE(data, ascii: "De la") || containsUTF16LE(data, ascii: "Num") { return true }
        if let latin = String(data: data, encoding: .isoLatin1) {
            if latin.contains("Loca") || latin.contains("Metode de Plat") { return true }
        }
        return false
    }
}

@MainActor
enum CashRegisterZReportPDFBuilder {
    /// Lățime tip bon POS (~80mm), ca la PDF-urile BINA (wkhtmltopdf).
    private static let receiptWidth: CGFloat = 227
    private static let margin: CGFloat = 14
    private static let lineHeight: CGFloat = 11
    private static let fontSize: CGFloat = 9

    static func makePDF(text: String) -> Data {
        makePDF(lines: linePreservingLines(from: text))
    }

    /// A4 ca PDF-urile BINA descărcate manual din browser.
    static func makeA4PDF(text: String) -> Data {
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let margin: CGFloat = 48
        let lineHeight: CGFloat = 14
        let lines = linePreservingLines(from: text)
        let contentHeight = margin * 2 + CGFloat(max(lines.count, 1)) * lineHeight
        let pageSize = CGSize(width: 595, height: max(contentHeight, 842))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin
            for line in lines {
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: font])
                y += lineHeight
            }
        }
    }

    static func makeCombinedPDF(texts: [String]) -> Data {
        var allLines: [String] = []
        for (index, text) in texts.enumerated() {
            if index > 0 {
                allLines.append("")
                allLines.append("")
            }
            allLines.append(contentsOf: linePreservingLines(from: text))
        }
        return makePDF(lines: allLines)
    }

    private static func makePDF(lines: [String]) -> Data {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let contentHeight = margin * 2 + CGFloat(max(lines.count, 1)) * lineHeight
        let pageSize = CGSize(width: receiptWidth, height: max(contentHeight, 640))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))

        return renderer.pdfData { context in
            context.beginPage()
            var y = margin

            for line in lines {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
                y += lineHeight
            }
        }
    }

    private static func linePreservingLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    static func makeCombinedPDF(fromOriginalPDFs pdfDatas: [Data]) -> Data {
        #if canImport(PDFKit)
        let output = PDFDocument()
        var pageIndex = 0
        for data in pdfDatas {
            guard let document = PDFDocument(data: data) else { continue }
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                output.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }
        return output.dataRepresentation() ?? Data()
        #else
        return Data()
        #endif
    }
}

@MainActor
enum CashRegisterZReportExporter {
    static func fileNameIndividual(for report: ExtractedCashRegisterZReport) -> String {
        "Raport_Z_\(zNumberPart(for: report))_\(datePart(report.reportDate)).pdf"
    }

    static func fileNameCombined(dates: [Date]) -> String {
        "Rapoarte_Z_\(periodPart(dates)).pdf"
    }

    static func pdfData(for report: ExtractedCashRegisterZReport) -> Data {
        if let existing = report.pdfData, !existing.isEmpty,
           CashRegisterZReportPDFSource.isValidPDF(existing),
           CashRegisterZReportPDFSource.isBinaOriginalPDF(existing) {
            return existing
        }
        return binaStyledPDF(for: report)
    }

    private static func binaStyledPDF(for report: ExtractedCashRegisterZReport) -> Data {
        if let pdfData = report.pdfData, !pdfData.isEmpty,
           CashRegisterZReportPDFSource.isBinaOriginalPDF(pdfData) {
            return pdfData
        }
        let exportText = BinaPosZReportTextNormalizer.romanianExportLayout(from: report.textContent)
        return CashRegisterZReportPDFBuilder.makeA4PDF(text: exportText)
    }

    static func exportIndividualReports(
        _ reports: [ExtractedCashRegisterZReport],
        to directory: URL
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for report in reports.sorted(by: { $0.reportDate < $1.reportDate }) {
            let name = fileNameIndividual(for: report)
            let url = uniqueURL(in: directory, preferredName: name)
            try pdfData(for: report).write(to: url, options: .atomic)
            urls.append(url)
        }
        return urls
    }

    static func exportCombinedReport(
        _ reports: [ExtractedCashRegisterZReport],
        to directory: URL
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sorted = reports.sorted(by: { $0.reportDate < $1.reportDate })
        if sorted.allSatisfy({ $0.pdfData?.isEmpty == false }) {
            let data = CashRegisterZReportPDFBuilder.makeCombinedPDF(fromOriginalPDFs: sorted.compactMap(\.pdfData))
            let name = fileNameCombined(dates: sorted.map(\.reportDate))
            let url = uniqueURL(in: directory, preferredName: name)
            try data.write(to: url, options: .atomic)
            return url
        }

        let texts = sorted.map {
            BinaPosZReportTextNormalizer.romanianExportLayout(from: $0.textContent)
        }
        let data = CashRegisterZReportPDFBuilder.makeCombinedPDF(texts: texts)
        let name = fileNameCombined(dates: sorted.map(\.reportDate))
        let url = uniqueURL(in: directory, preferredName: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        var url = directory.appendingPathComponent(preferredName)
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base)-\(counter).\(ext)")
            counter += 1
        }
        return url
    }

    private static func zNumberPart(for report: ExtractedCashRegisterZReport) -> String {
        if let reportNumber = report.reportNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
           !reportNumber.isEmpty {
            let digits = reportNumber.filter(\.isNumber)
            if !digits.isEmpty { return digits }
        }

        let parseText = BinaPosZReportTextNormalizer.normalizeIfNeeded(report.textContent)
        let parsed = ZParser.parse(ocrText: parseText)
        if parsed.zNumber > 0 { return String(parsed.zNumber) }

        return "0000"
    }

    private static func datePart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func periodPart(_ dates: [Date]) -> String {
        let sorted = dates.sorted()
        guard let first = sorted.first else { return datePart(Date()) }
        guard let last = sorted.last, sorted.count > 1, first != last else {
            return datePart(first)
        }
        return "\(datePart(first))_\(datePart(last))"
    }
}

@MainActor
enum CashRegisterZReportProcessor {
    /// Pregătește rapoartele pentru export Zetta: metadata + PDF/text în română (layout BINA manual).
    static func normalize(_ reports: [ExtractedCashRegisterZReport]) -> [ExtractedCashRegisterZReport] {
        var prepared: [ExtractedCashRegisterZReport] = []
        prepared.reserveCapacity(reports.count)
        for report in reports {
            prepared.append(prepareForExport(report))
        }
        return prepared
    }

    static func prepareForExport(_ report: ExtractedCashRegisterZReport) -> ExtractedCashRegisterZReport {
        let sourceText = report.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let parseText = BinaPosZReportTextNormalizer.normalizeIfNeeded(sourceText)
        let parsed = ZParser.parse(ocrText: parseText)
        let resolvedDate = parsed.zNumber > 0 || parsed.totalVanzari > 0 ? parsed.date : report.reportDate
        let resolvedNumber = report.reportNumber ?? (parsed.zNumber > 0 ? String(parsed.zNumber) : nil)

        // Păstrează wkhtmltopdf BINA dacă nu e clar englez — identic cu eu.pdf.
        if let pdfData = report.pdfData, !pdfData.isEmpty,
           CashRegisterZReportPDFSource.isValidPDF(pdfData),
           CashRegisterZReportPDFSource.isBinaOriginalPDF(pdfData),
           !BinaPosZReportTextNormalizer.looksLikeEnglishBinaPOS(sourceText) {
            return ExtractedCashRegisterZReport(
                id: report.id,
                reportDate: resolvedDate,
                reportNumber: resolvedNumber,
                textContent: sourceText,
                pdfData: pdfData
            )
        }

        // Fallback: fără PDF BINA (import manual text).
        let exportText = BinaPosZReportTextNormalizer.romanianExportLayout(from: sourceText)
        let exportPDF = CashRegisterZReportPDFBuilder.makeA4PDF(text: exportText)
        return ExtractedCashRegisterZReport(
            id: report.id,
            reportDate: resolvedDate,
            reportNumber: resolvedNumber,
            textContent: exportText,
            pdfData: exportPDF
        )
    }
}

// MARK: - Backward compatibility (nume vechi din refactorizări anterioare)

enum BinaZReportPDFRenderer {
    static func makePDF(from model: BinaZReportVisualModel) -> Data {
        CashRegisterZReportBinaLayout.makePDF(from: model)
    }
}

enum BinaZReportVisualModelBuilder {
    static func build(from text: String, fallbackZNumber: String? = nil) -> BinaZReportVisualModel {
        CashRegisterZReportBinaLayout.build(from: text, fallbackZNumber: fallbackZNumber)
    }

    static func plainText(from model: BinaZReportVisualModel) -> String {
        CashRegisterZReportBinaLayout.plainText(from: model)
    }

    static func makePDF(from model: BinaZReportVisualModel) -> Data {
        CashRegisterZReportBinaLayout.makePDF(from: model)
    }
}

