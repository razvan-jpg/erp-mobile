import Foundation

/// Nume de fișiere Zetta din firma citită pe Z (nu din societatea ERP activă).
enum ZettaScanReportBinder {
    nonisolated static func exportBaseName(for reports: [ZReportData]) -> String {
        let firm = FirmaRegistry.displayName(for: reports.first ?? ZReportData())
        return "ZETTA - \(sanitizeFileNameComponent(firm)) - \(dateRangeFilePart(from: reports))"
    }

    nonisolated static func individualPDFFileName(for report: ZReportData, usedNames: inout Set<String>) -> String {
        let datePart = CashRegisterJournalFormatting.fileDate(report.date)
        var name = "Raport_Z_\(max(report.zNumber, 0))_\(datePart).pdf"
        var suffix = 2
        while usedNames.contains(name) {
            name = "Raport_Z_\(max(report.zNumber, 0))_\(datePart)_\(suffix).pdf"
            suffix += 1
        }
        usedNames.insert(name)
        return name
    }

    nonisolated static func dateRangeFilePart(from reports: [ZReportData]) -> String {
        let days = Set(reports.map { Calendar.current.startOfDay(for: $0.date) }).sorted()
        if days.count == 1, let only = days.first {
            return CashRegisterJournalFormatting.fileDate(only)
        }
        if let first = days.first, let last = days.last, days.count > 1 {
            return "\(CashRegisterJournalFormatting.fileDate(first))_\(CashRegisterJournalFormatting.fileDate(last))"
        }
        return CashRegisterJournalFormatting.fileDate(Date())
    }

    nonisolated static func sanitizeFileNameComponent(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:.\n\t")
        var cleaned = raw
            .components(separatedBy: invalid)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        while cleaned.contains("__") {
            cleaned = cleaned.replacingOccurrences(of: "__", with: "_")
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_+"))
        if cleaned.isEmpty { return "Firma" }
        if cleaned.count > 80 {
            cleaned = String(cleaned.prefix(80))
        }
        return cleaned
    }
}
