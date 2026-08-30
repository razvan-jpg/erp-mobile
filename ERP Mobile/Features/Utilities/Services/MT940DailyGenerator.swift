import Foundation

enum MT940DailyGenerator {
    struct DailyFile: Identifiable, Sendable {
        let id: String
        let date: Date
        let fileName: String
        let content: String
    }

    static func generateDailyFiles(
        statement: MT940ParsedStatement,
        templateText: String,
        companyName: String
    ) -> [DailyFile] {
        let firmPart = sanitizeFileNameComponent(companyName)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: statement.transactions) {
            calendar.startOfDay(for: $0.valueDate)
        }

        let sortedDays = grouped.keys.sorted()
        var runningBalance = statement.metadata.openingBalance
        var files: [DailyFile] = []

        for day in sortedDays {
            guard let dayTransactions = grouped[day]?.sorted(by: { $0.field61 < $1.field61 }) else { continue }
            let opening = runningBalance
            for tx in dayTransactions {
                if tx.isDebit {
                    runningBalance -= tx.amount
                } else {
                    runningBalance += tx.amount
                }
            }
            let closing = runningBalance
            let content = buildDailyContent(
                templateText: templateText,
                metadata: statement.metadata,
                day: day,
                opening: opening,
                closing: closing,
                transactions: dayTransactions
            )
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            let dayCode = formatter.string(from: day)
            let fileName = suggestedDailyFileName(firmPart: firmPart, dayCode: dayCode)
            files.append(
                DailyFile(
                    id: dayCode,
                    date: day,
                    fileName: fileName,
                    content: content
                )
            )
        }

        return files
    }

    private static func buildDailyContent(
        templateText: String,
        metadata: MT940StatementMetadata,
        day: Date,
        opening: Decimal,
        closing: Decimal,
        transactions: [MT940Transaction]
    ) -> String {
        let dateCode = swiftDateCode(day)
        var lines: [String] = []

        if !metadata.field20.isEmpty {
            lines.append(replaceDateCode(in: metadata.field20, with: dateCode, prefix: ":20:"))
        } else {
            lines.append(":20:STMT\(dateCode)")
        }

        lines.append(metadata.field25.isEmpty ? ":25:IMPORT/BANK" : metadata.field25)
        lines.append(metadata.field28C.isEmpty ? ":28C:00001/00001" : metadata.field28C)

        let openingLine = ":60F:C\(dateCode)\(metadata.currency)\(mt940AmountString(opening))"
        lines.append(openingLine)

        for tx in transactions {
            lines.append(tx.field61)
            lines.append(":86:\(tx.narrative)")
        }

        lines.append(":62F:C\(dateCode)\(metadata.currency)\(mt940AmountString(closing))")
        lines.append(":64:C\(dateCode)\(metadata.currency)\(mt940AmountString(closing))")

        lines.append(contentsOf: accountFooterLines(from: metadata))

        return lines.joined(separator: "\n") + "\n"
    }

    private static func accountFooterLines(from metadata: MT940StatementMetadata) -> [String] {
        if !metadata.accountFooterLines.isEmpty {
            return metadata.accountFooterLines
        }

        var footer: [String] = []
        let holder = metadata.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !holder.isEmpty {
            footer.append(":86:NAME ACCOUNT OWNER: \(holder)")
        }
        if let iban = ibanFromField25(metadata.field25) {
            footer.append("IBAN NO: \(iban)")
        }
        return footer
    }

    private static func ibanFromField25(_ field25: String) -> String? {
        let body = field25.hasPrefix(":25:") ? String(field25.dropFirst(4)) : field25
        let cleaned = body
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: #"^RO\d{2}[A-Z0-9]+$"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return cleaned.uppercased()
    }

    private static func replaceDateCode(in line: String, with dateCode: String, prefix: String) -> String {
        guard line.hasPrefix(prefix) else { return line }
        let body = String(line.dropFirst(prefix.count))
        if body.count >= 6, body.prefix(6).allSatisfy(\.isNumber) {
            return prefix + dateCode + String(body.dropFirst(6))
        }
        return prefix + "STMT" + dateCode
    }

    private static func swiftDateCode(_ date: Date) -> String {
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date) % 100
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%02d%02d%02d", y, m, d)
    }

    private static func mt940AmountString(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: abs(amount))
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        let value = formatter.string(from: number) ?? "0,00"
        return amount < 0 ? "-\(value)" : value
    }

    static func suggestedDailyFileName(firmPart: String, dayCode: String) -> String {
        guard !firmPart.isEmpty else { return "MT940_\(dayCode).txt" }
        return "MT940_\(firmPart)_\(dayCode).txt"
    }

    static func suggestedArchiveName(companyName: String, files: [DailyFile]) -> String {
        let firm = sanitizeFileNameComponent(companyName)
        let period = periodPart(from: files.map(\.date))
        guard !firm.isEmpty else { return "MT940_\(period).zip" }
        return "MT940_\(firm)_\(period).zip"
    }

    private static func periodPart(from dates: [Date]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let sorted = dates.sorted()
        guard let first = sorted.first else { return formatter.string(from: Date()) }
        guard let last = sorted.last, sorted.count > 1, first != last else {
            return formatter.string(from: first)
        }
        return "\(formatter.string(from: first))_\(formatter.string(from: last))"
    }

    private static func sanitizeFileNameComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return trimmed
            .components(separatedBy: forbidden)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}

enum MT940ArchiveExporter {
    static func createArchive(dailyFiles: [MT940DailyGenerator.DailyFile]) throws -> Data {
        var payload: [String: Data] = [:]
        for file in dailyFiles {
            payload[file.fileName] = Data(file.content.utf8)
        }
        return try ZipWriter.create(files: payload)
    }

    static func writeArchive(dailyFiles: [MT940DailyGenerator.DailyFile], to url: URL) throws {
        try createArchive(dailyFiles: dailyFiles).write(to: url, options: .atomic)
    }
}
