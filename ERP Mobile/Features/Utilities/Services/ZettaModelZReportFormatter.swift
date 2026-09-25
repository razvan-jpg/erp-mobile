import Foundation

/// Completează layout-ul din `Raport_Z_model.pdf` cu valorile citite de pe Z.
enum ZettaModelZReportFormatter {
    static func modelText(for report: ZReportData) -> String {
        rebuiltModelText(for: report, companyName: nil, addressLine: nil)
    }

    static func rebuiltModelText(
        for report: ZReportData,
        companyName: String? = nil,
        addressLine: String?
    ) -> String {
        var model = visualModel(for: report)
        if let companyName, !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.companyName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let addressLine, !addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.companyAddress = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text(from: model)
    }

    static func makePDF(for report: ZReportData) -> Data {
        CashRegisterZReportBinaLayout.makePDF(from: visualModel(for: report))
    }

    static func visualModel(for report: ZReportData) -> BinaZReportVisualModel {
        let fromText = CashRegisterZReportBinaLayout.build(
            from: report.ocrText,
            fallbackZNumber: report.zNumber > 0 ? "\(report.zNumber)" : nil
        )
        var model = fromText

        let printed = printedCompanyName(from: report)
        if !printed.isEmpty { model.companyName = printed }
        let address = printedAddress(from: report)
        if !address.isEmpty { model.companyAddress = address }

        if model.zNumber.isEmpty {
            model.zNumber = "\(max(report.zNumber, 0))"
        }
        if model.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let location = report.locatieLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            model.location = location.isEmpty ? report.punctLucru.shortName.uppercased() : location
        }

        let closing = report.printDateTime ?? report.date
        if model.toDate.isEmpty {
            model.toDate = digitalDateTime(closing)
        }
        if model.fromDate.isEmpty {
            model.fromDate = model.toDate
        }

        if model.total.isEmpty {
            model.total = amountRON(report.totalVanzari)
        }
        if model.paymentSectionTotal.isEmpty {
            model.paymentSectionTotal = model.total
        }
        if model.totalSales.isEmpty {
            model.totalSales = amount(report.totalVanzari)
        }

        model.payments = filledPayments(existing: model.payments, report: report)
        model.vatGroups = filledVATGroups(existing: model.vatGroups, report: report)
        model.vatLines = filledVATLines(existing: model.vatLines, report: report)

        let totalTVA = report.tva21 + report.tva11 + report.tva11C
        if model.totalVAT.isEmpty {
            model.totalVAT = amount(totalTVA)
        }

        return model
    }

    nonisolated static func text(from model: BinaZReportVisualModel) -> String {
        var lines: [String] = []
        if !model.companyName.isEmpty { lines.append(model.companyName) }
        if !model.companyAddress.isEmpty { lines.append(model.companyAddress) }
        lines.append("Z report Număr \(model.zNumber)")
        lines.append("Locaţia \t\(model.location)")
        lines.append("Număr POS \t\(model.posNumber)")
        lines.append("Utilizator \t\(model.user)")
        lines.append("De la \t\(model.fromDate)")
        lines.append("Până la \t\(model.toDate)")
        lines.append("Documente \t\(model.documents)")
        lines.append("Total \t\(model.total)")
        lines.append("Metode de Plată")
        for row in model.payments {
            if let amount = row.amount, !amount.isEmpty {
                lines.append("\(row.label) \t\(amount)")
            } else {
                lines.append(row.label)
            }
        }
        lines.append("Total \t\(model.paymentSectionTotal)")
        lines.append("TVA")
        for row in model.vatGroups {
            lines.append("\(row.label) \t\(row.amount)")
        }
        for row in model.vatLines {
            lines.append("\(row.label) \t\(row.amount)")
        }
        lines.append("Total TVA \t\(model.totalVAT)")
        lines.append("Total vânzări \t\(model.totalSales)")
        return lines.joined(separator: "\n")
    }

    nonisolated private static func printedCompanyName(from report: ZReportData) -> String {
        if let first = headerLines(from: report.ocrText).first, !isLayoutLabel(first) {
            return first
        }
        return report.firma.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func printedAddress(from report: ZReportData) -> String {
        let lines = headerLines(from: report.ocrText)
        guard lines.count >= 2 else { return "" }
        let second = lines[1]
        return isLayoutLabel(second) ? "" : second
    }

    nonisolated private static func headerLines(from ocrText: String) -> [String] {
        ocrText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    nonisolated private static func isLayoutLabel(_ line: String) -> Bool {
        let folded = fold(line)
        return folded.hasPrefix("Z REPORT")
            || folded.hasPrefix("LOCAT")
            || folded.hasPrefix("LOCATION")
            || folded.hasPrefix("METODE")
            || folded.hasPrefix("PAYMENT")
            || folded.hasPrefix("NUMAR POS")
            || folded.hasPrefix("POS NUMBER")
            || folded.hasPrefix("UTILIZATOR")
            || folded.hasPrefix("USER")
            || folded.hasPrefix("DE LA")
            || folded.hasPrefix("PANA LA")
            || folded.hasPrefix("DOCUMENTE")
    }

    nonisolated private static func filledPayments(
        existing: [BinaZReportPaymentRow],
        report: ZReportData
    ) -> [BinaZReportPaymentRow] {
        let moderna = report.plataModerna > 0 ? report.plataModerna : report.altePlati
        return [
            paymentRow("Numerar", amount: existingAmount(existing, labels: ["Numerar"]) ?? ronIfPositive(report.numerar)),
            paymentRow("Credit cards", amount: existingAmount(existing, labels: ["Credit cards"]) ?? ronIfPositive(report.card)),
            paymentRow("Credit", amount: existingAmount(existing, labels: ["Credit"])),
            paymentRow("Bon masă", amount: existingAmount(existing, labels: ["Bon masă", "Bon masa"])),
            paymentRow("Jeton", amount: existingAmount(existing, labels: ["Jeton"])),
            paymentRow("Card masă", amount: existingAmount(existing, labels: ["Card masă", "Card masa"])),
            paymentRow("Plata moderna", amount: existingAmount(existing, labels: ["Plata moderna"]) ?? ronIfPositive(moderna)),
            paymentRow("Voucher", amount: existingAmount(existing, labels: ["Voucher"])),
        ]
    }

    nonisolated private static func filledVATGroups(
        existing: [BinaZReportValueRow],
        report: ZReportData
    ) -> [BinaZReportValueRow] {
        var rows = [
            vatRow(existing, label: "BRUT A TVA 21%", fallback: report.vanzari21),
            vatRow(existing, label: "BRUT B TVA 11%", fallback: report.vanzari11),
        ]
        if report.vanzari11C > 0 || report.tva11C > 0 {
            rows.append(vatRow(existing, label: "BRUT C TVA 11%", fallback: report.vanzari11C))
        }
        rows.append(vatRow(existing, label: "BRUT D TVA 0%", fallback: report.vanzari0))
        return rows
    }

    nonisolated private static func filledVATLines(
        existing: [BinaZReportValueRow],
        report: ZReportData
    ) -> [BinaZReportValueRow] {
        var rows = [
            vatRow(existing, label: "TVA A 21%", fallback: report.tva21),
            vatRow(existing, label: "TVA B 11%", fallback: report.tva11),
        ]
        if report.vanzari11C > 0 || report.tva11C > 0 {
            rows.append(vatRow(existing, label: "TVA C 11%", fallback: report.tva11C))
        }
        rows.append(vatRow(existing, label: "TVA D 0%", fallback: 0))
        return rows
    }

    nonisolated private static func vatRow(
        _ existing: [BinaZReportValueRow],
        label: String,
        fallback: Decimal
    ) -> BinaZReportValueRow {
        if let found = existing.first(where: { fold($0.label) == fold(label) }), !found.amount.isEmpty {
            return BinaZReportValueRow(label: label, amount: found.amount)
        }
        return BinaZReportValueRow(label: label, amount: amount(fallback))
    }

    nonisolated private static func paymentRow(_ label: String, amount: String?) -> BinaZReportPaymentRow {
        let trimmed = amount?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return BinaZReportPaymentRow(label: label, amount: trimmed.isEmpty ? nil : trimmed)
    }

    nonisolated private static func existingAmount(
        _ rows: [BinaZReportPaymentRow],
        labels: [String]
    ) -> String? {
        let keys = Set(labels.map(fold))
        guard let found = rows.first(where: { keys.contains(fold($0.label)) })?.amount,
              !found.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return found
    }

    nonisolated private static func ronIfPositive(_ value: Decimal) -> String? {
        value > 0 ? amountRON(value) : nil
    }

    nonisolated private static func amountRON(_ value: Decimal) -> String {
        "\(amount(value)) RON"
    }

    nonisolated private static func digitalDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }

    nonisolated private static func amount(_ value: Decimal) -> String {
        var rounded = value
        var output = Decimal()
        NSDecimalRound(&output, &rounded, 2, .plain)
        let number = NSDecimalNumber(decimal: output)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? CashRegisterJournalFormatting.amount(value)
    }

    nonisolated private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
