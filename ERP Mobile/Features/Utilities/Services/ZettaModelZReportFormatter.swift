import Foundation

/// Reconstructs Raport Z text in the bundled `Raport_Z_model.pdf` layout.
enum ZettaModelZReportFormatter {
    nonisolated static func modelText(for report: ZReportData) -> String {
        rebuiltModelText(for: report, companyName: nil, addressLine: nil)
    }

    /// Layout pe model. `companyName` (societatea activă) înlocuiește tot timpul firma de pe scan.
    nonisolated static func rebuiltModelText(
        for report: ZReportData,
        companyName: String? = nil,
        addressLine: String?
    ) -> String {
        buildFromParsedFields(report, companyName: companyName, addressLine: addressLine)
    }

    nonisolated private static func buildFromParsedFields(
        _ report: ZReportData,
        companyName: String? = nil,
        addressLine: String? = nil
    ) -> String {
        let location = report.locatieLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationLine = location.isEmpty ? report.punctLucru.shortName.uppercased() : location
        let closing = report.printDateTime ?? report.date
        let dateTime = digitalDateTime(closing)
        var lines: [String] = []
        let explicit = companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fromReport = report.firma.trimmingCharacters(in: .whitespacesAndNewlines)
        let firm = explicit.isEmpty ? fromReport : explicit
        lines.append(firm.isEmpty ? "FIRMA" : firm)
        if let address = addressLine?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            lines.append(address)
        }
        lines.append("Z report Număr \(max(report.zNumber, 0))")
        lines.append("Locaţia \t\(locationLine)")
        lines.append("De la \t\(dateTime)")
        lines.append("Până la \t\(dateTime)")
        lines.append("Total \t\(amount(report.totalVanzari)) RON")
        lines.append("Metode de Plată")
        lines.append("Numerar \t\(amount(report.numerar)) RON")
        lines.append("Credit cards \t\(amount(report.card)) RON")
        lines.append("Credit")
        lines.append("Bon masă")
        lines.append("Jeton")
        lines.append("Card masă")
        if report.plataModerna > 0 || report.altePlati > 0 {
            lines.append("Plata moderna \t\(amount(report.plataModerna > 0 ? report.plataModerna : report.altePlati)) RON")
        } else {
            lines.append("Plata moderna")
        }
        lines.append("Voucher")
        lines.append("Total \t\(amount(report.totalVanzari)) RON")
        lines.append("TVA")
        if report.vanzari21 > 0 || report.tva21 > 0 {
            lines.append("BRUT A TVA 21% \t\(amount(report.vanzari21))")
        }
        if report.vanzari11 > 0 || report.tva11 > 0 {
            lines.append("BRUT B TVA 11% \t\(amount(report.vanzari11))")
        }
        if report.vanzari11C > 0 || report.tva11C > 0 {
            lines.append("BRUT C TVA 11% \t\(amount(report.vanzari11C))")
        }
        if report.vanzari0 > 0 {
            lines.append("BRUT D TVA 0% \t\(amount(report.vanzari0))")
        }
        if report.tva21 > 0 {
            lines.append("TVA A 21% \t\(amount(report.tva21))")
        }
        if report.tva11 > 0 {
            lines.append("TVA B 11% \t\(amount(report.tva11))")
        }
        if report.tva11C > 0 {
            lines.append("TVA C 11% \t\(amount(report.tva11C))")
        }
        if report.vanzari0 > 0 {
            lines.append("TVA D 0% \t\(amount(0))")
        }
        let totalTVA = report.tva21 + report.tva11 + report.tva11C
        lines.append("Total TVA \t\(amount(totalTVA))")
        lines.append("Total vânzări \t\(amount(report.totalVanzari))")
        return lines.joined(separator: "\n")
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
}
