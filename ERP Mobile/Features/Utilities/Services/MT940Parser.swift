import Foundation

struct MT940Transaction: Identifiable, Hashable, Sendable {
    let id = UUID()
    let valueDate: Date
    let isDebit: Bool
    let amount: Decimal
    let field61: String
    let narrative: String
}

struct MT940StatementMetadata: Sendable {
    var field20: String = ""
    var field25: String = ""
    var field28C: String = ""
    var openingBalanceLine: String = ""
    var openingBalance: Decimal = 0
    var openingBalanceDate: Date = Date()
    var currency: String = "RON"
    var closingBalanceLine: String = ""
    var closingBalance: Decimal = 0
    var closingBalanceDate: Date = Date()
    var accountFooterLines: [String] = []
    var accountHolderName: String = ""
}

struct MT940ParsedStatement: Sendable {
    let metadata: MT940StatementMetadata
    let transactions: [MT940Transaction]
}

enum MT940Parser {
    static func parse(text: String) throws -> MT940ParsedStatement {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        guard normalized.contains(":61:") else {
            throw MT940UtilityError.unsupportedFormat
        }

        var metadata = MT940StatementMetadata()
        var transactions: [MT940Transaction] = []
        var pending61: String?
        var footerStarted = false

        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix(":20:") {
                metadata.field20 = line
                continue
            }
            if line.hasPrefix(":25:") {
                metadata.field25 = line
                continue
            }
            if line.hasPrefix(":28C:") {
                metadata.field28C = line
                continue
            }
            if line.hasPrefix(":60F:") {
                metadata.openingBalanceLine = line
                if let parsed = parseBalanceLine(line) {
                    metadata.openingBalance = parsed.amount
                    metadata.openingBalanceDate = parsed.date
                    metadata.currency = parsed.currency
                }
                continue
            }
            if line.hasPrefix(":62F:") {
                metadata.closingBalanceLine = line
                if let parsed = parseBalanceLine(line) {
                    metadata.closingBalance = parsed.amount
                    metadata.closingBalanceDate = parsed.date
                    metadata.currency = parsed.currency
                }
                continue
            }
            if line.hasPrefix(":64:") {
                continue
            }
            if line.hasPrefix(":61:") {
                pending61 = line
                footerStarted = false
                continue
            }
            if line.hasPrefix(":86:") {
                let body = String(line.dropFirst(4))
                if let field61 = pending61, let tx = parseTransaction(field61: field61, narrative: body) {
                    transactions.append(tx)
                    pending61 = nil
                } else if footerStarted || metadata.accountFooterLines.isEmpty, body.contains("ACCOUNT") || body.contains("IBAN") {
                    footerStarted = true
                    metadata.accountFooterLines.append(line)
                } else if let field61 = pending61 {
                    if let tx = parseTransaction(field61: field61, narrative: body) {
                        transactions.append(tx)
                        pending61 = nil
                    }
                } else {
                    metadata.accountFooterLines.append(line)
                }
                continue
            }

            if pending61 != nil {
                metadata.accountFooterLines.append(line)
            }
        }

        guard !transactions.isEmpty else {
            throw MT940UtilityError.noTransactions
        }

        if metadata.accountHolderName.isEmpty,
           let holder = MT940StatementLabelExtractor.extract(from: normalized) {
            metadata.accountHolderName = holder
        }

        return MT940ParsedStatement(metadata: metadata, transactions: transactions)
    }

    static func parseUploadedFile(data: Data, fileName: String) throws -> MT940ParsedStatement {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".pdf") {
            let candidates = try PDFTextExtractor.extractTextCandidates(from: data)
            let combinedText = candidates.joined(separator: "\n")
            let statement: MT940ParsedStatement
            if candidates.contains(where: { RaiffeisenStatementParser.isRaiffeisenStatement($0) }) {
                statement = try RaiffeisenStatementParser.parseBest(from: candidates)
            } else if combinedText.contains(":61:") {
                statement = try parse(text: combinedText)
            } else {
                do {
                    statement = try MT940BankStatementTextParser.parse(combinedText)
                } catch MT940UtilityError.noTransactions {
                    if combinedText.contains(";") || combinedText.contains(",") {
                        statement = try parseCSV(text: combinedText)
                    } else {
                        throw MT940UtilityError.noTransactions
                    }
                }
            }
            return enrich(statement, text: combinedText, fileName: fileName)
        }

        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw MT940UtilityError.unsupportedFormat
        }

        let statement: MT940ParsedStatement
        if text.contains(":61:") {
            statement = try parse(text: text)
        } else if lower.hasSuffix(".csv") || text.contains(";") || text.contains(",") {
            statement = try parseCSV(text: text)
        } else if lower.hasSuffix(".mt940") || lower.hasSuffix(".940") || lower.hasSuffix(".sta") {
            statement = try MT940BankStatementTextParser.parse(text)
        } else {
            throw MT940UtilityError.unsupportedFormat
        }
        return enrich(statement, text: text, fileName: fileName)
    }

    private static func enrich(
        _ statement: MT940ParsedStatement,
        text: String,
        fileName: String
    ) -> MT940ParsedStatement {
        var metadata = statement.metadata
        if metadata.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            metadata.accountHolderName = MT940StatementLabelExtractor.resolveCompanyName(
                metadata: metadata,
                sourceTexts: [text],
                fileNames: [fileName]
            )
        }
        return MT940ParsedStatement(metadata: metadata, transactions: statement.transactions)
    }

    private static func parseCSV(text: String) throws -> MT940ParsedStatement {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { throw MT940UtilityError.noTransactions }

        let delimiter: Character = lines[0].contains(";") ? ";" : ","
        let headers = lines[0].split(separator: delimiter).map { normalizeHeader(String($0)) }

        let dateIndex = headers.firstIndex(where: { $0.contains("data") || $0.contains("date") }) ?? 0
        let amountIndex = headers.firstIndex(where: { $0.contains("sum") || $0.contains("amount") || $0.contains("valoare") }) ?? 1
        let detailsIndex = headers.firstIndex(where: { $0.contains("desc") || $0.contains("detal") || $0.contains("explic") }) ?? min(2, headers.count - 1)

        var metadata = MT940StatementMetadata()
        var transactions: [MT940Transaction] = []
        var runningBalance = Decimal.zero

        for line in lines.dropFirst() {
            let cols = line.split(separator: delimiter, omittingEmptySubsequences: false).map(String.init)
            guard cols.count > max(dateIndex, amountIndex) else { continue }

            guard let date = parseFlexibleDate(cols[dateIndex]) else { continue }
            guard let parsedAmount = parseAmount(cols[amountIndex]) else { continue }
            let details = cols.indices.contains(detailsIndex) ? cols[detailsIndex] : ""

            let isDebit = parsedAmount < 0
            let amount = abs(parsedAmount)
            runningBalance += parsedAmount

            let yyMMdd = swiftDateCode(date)
            let amountText = mt940AmountString(amount)
            let dc = isDebit ? "D" : "C"
            let field61 = ":61:\(yyMMdd)\(dc)\(amountText)NTRFNONREF//\(UUID().uuidString.prefix(8))"
            transactions.append(
                MT940Transaction(
                    valueDate: date,
                    isDebit: isDebit,
                    amount: amount,
                    field61: field61,
                    narrative: details
                )
            )
        }

        guard !transactions.isEmpty else { throw MT940UtilityError.noTransactions }

        let sortedDays = transactions.map { Calendar.current.startOfDay(for: $0.valueDate) }.sorted()
        metadata.openingBalanceDate = sortedDays.first ?? Date()
        metadata.closingBalanceDate = sortedDays.last ?? Date()
        metadata.openingBalance = 0
        metadata.closingBalance = runningBalance
        metadata.field20 = ":20:STMT\(swiftDateCode(metadata.openingBalanceDate))"
        metadata.field25 = ":25:IMPORT/CSV"
        metadata.field28C = ":28C:00001/00001"
        metadata.openingBalanceLine = ":60F:C\(swiftDateCode(metadata.openingBalanceDate))\(metadata.currency)0,00"
        metadata.closingBalanceLine = ":62F:C\(swiftDateCode(metadata.closingBalanceDate))\(metadata.currency)\(mt940AmountString(abs(runningBalance)))"
        if metadata.accountHolderName.isEmpty,
           let holder = MT940StatementLabelExtractor.extract(from: text) {
            metadata.accountHolderName = holder
        }

        return MT940ParsedStatement(metadata: metadata, transactions: transactions)
    }

    private static func parseTransaction(field61: String, narrative: String) -> MT940Transaction? {
        let body = field61.hasPrefix(":61:") ? String(field61.dropFirst(4)) : field61
        guard body.count >= 10 else { return nil }

        let dateCode = String(body.prefix(6))
        guard let valueDate = parseSwiftDateCode(dateCode) else { return nil }

        let remainder = String(body.dropFirst(6))
        guard let dcIndex = remainder.firstIndex(where: { $0 == "C" || $0 == "D" }) else { return nil }
        let isDebit = remainder[dcIndex] == "D"

        let afterDC = String(remainder[remainder.index(after: dcIndex)...])
        guard let amountEnd = afterDC.firstIndex(where: { !($0.isNumber || $0 == ",") }) else { return nil }
        let amountPart = String(afterDC[..<amountEnd])
        guard let amount = parseAmount(amountPart) else { return nil }

        return MT940Transaction(
            valueDate: valueDate,
            isDebit: isDebit,
            amount: amount,
            field61: field61.hasPrefix(":61:") ? field61 : ":61:\(field61)",
            narrative: narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func parseBalanceLine(_ line: String) -> (date: Date, currency: String, amount: Decimal)? {
        let body = line.hasPrefix(":60F:") || line.hasPrefix(":62F:") || line.hasPrefix(":64:")
            ? String(line.split(separator: ":", maxSplits: 2).last ?? "")
            : line
        guard body.count >= 10 else { return nil }

        let mark = body.first
        let dateCode = String(body.dropFirst().prefix(6))
        guard let date = parseSwiftDateCode(dateCode) else { return nil }

        let tail = String(body.dropFirst(7))
        guard let currencyRange = tail.range(of: #"^[A-Z]{3}"#, options: .regularExpression) else { return nil }
        let currency = String(tail[currencyRange])
        let amountPart = String(tail[currencyRange.upperBound...])
        guard var amount = parseAmount(amountPart) else { return nil }
        if mark == "D" { amount = -amount }
        return (date, currency, amount)
    }

    private static func parseSwiftDateCode(_ code: String) -> Date? {
        guard code.count == 6, let year = Int(code.prefix(2)), let month = Int(code.dropFirst(2).prefix(2)), let day = Int(code.suffix(2)) else {
            return nil
        }
        var components = DateComponents()
        components.year = 2000 + year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }

    private static func swiftDateCode(_ date: Date) -> String {
        let calendar = Calendar.current
        let y = calendar.component(.year, from: date) % 100
        let m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        return String(format: "%02d%02d%02d", y, m, d)
    }

    private static func parseFlexibleDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy", "yyyy/MM/dd", "dd-MM-yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    private static func parseAmount(_ raw: String) -> Decimal? {
        let cleaned = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Decimal(string: cleaned)
    }

    private static func mt940AmountString(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ""
        return formatter.string(from: number) ?? "\(amount)"
    }

    private static func normalizeHeader(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MT940UtilityError: LocalizedError {
    case unsupportedFormat
    case pdfNoExtractableText
    case noTransactions
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return L10n.tr("utilities.mt940.error_unsupported")
        case .pdfNoExtractableText:
            return L10n.tr("utilities.mt940.error_pdf_no_text")
        case .noTransactions:
            return L10n.tr("utilities.mt940.error_no_transactions")
        case .exportFailed:
            return L10n.tr("utilities.mt940.error_export")
        }
    }
}

#if canImport(PDFKit)
import PDFKit

enum PDFTextExtractor {
    static func extractTextCandidates(from data: Data) throws -> [String] {
        guard let document = PDFDocument(data: data) else {
            throw MT940UtilityError.unsupportedFormat
        }

        var candidates: [String] = []

        var parts: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                parts.append(text)
                continue
            }
            if let attributed = page.attributedString?.string.trimmingCharacters(in: .whitespacesAndNewlines),
               !attributed.isEmpty {
                parts.append(attributed)
                continue
            }
            let bounds = page.bounds(for: .mediaBox)
            if let selection = page.selection(for: bounds),
               let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                parts.append(text)
            }
        }

        let plainText = parts.joined(separator: "\n")
        if !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(plainText)
        }

        let structured = PDFStructuredLineExtractor.extractLines(from: document)
        let structuredText = structured.joined(separator: "\n")
        if !structuredText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append(structuredText)
        }

        guard !candidates.isEmpty else {
            throw MT940UtilityError.pdfNoExtractableText
        }
        return candidates
    }

    static func extractText(from data: Data) throws -> String {
        let candidates = try extractTextCandidates(from: data)
        return candidates.max {
            RaiffeisenStatementParser.previewTransactionCount(in: $0)
                < RaiffeisenStatementParser.previewTransactionCount(in: $1)
        } ?? candidates[0]
    }
}
#else
enum PDFTextExtractor {
    static func extractTextCandidates(from data: Data) throws -> [String] {
        throw MT940UtilityError.pdfNoExtractableText
    }

    static func extractText(from data: Data) throws -> String {
        throw MT940UtilityError.pdfNoExtractableText
    }
}
#endif
