import Foundation

/// Convertește text din extras bancar PDF/CSV (ING, BCR, BT, account statement etc.) → tranzacții MT940.
enum MT940BankStatementTextParser {
    /// Sume RO (1.234,56) sau EN (1,234.56 / -201.00)
    private static let amountPattern = #"(\(?\-\+?(?:\d{1,3}(?:[.,]\d{3})+|\d{1,3}|\d+)[.,]\d{2}\)?)"#
    private static let romanianDatePattern = #"\b(\d{2}[.\-/]\d{2}[.\-/]\d{2,4})\b"#
    private static let isoDatePattern = #"\b(\d{4}-\d{2}-\d{2})\b"#
    private static let englishDatePattern = #"\b(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\b"#

    private static let headerExactMatches: Set<String> = [
        "data", "date", "transaction date", "booking date", "value date",
        "descriere", "description", "details", "detalii",
        "debit", "credit", "amount", "suma", "sold", "balance",
        "iban", "account number", "currency", "moneda", "valuta",
        "page", "pagina", "continued", "total", "opening balance", "closing balance",
        "account statement", "extras de cont", "statement of account"
    ]

    static func parse(_ text: String) throws -> MT940ParsedStatement {
        if RaiffeisenStatementParser.isRaiffeisenStatement(text) {
            return try RaiffeisenStatementParser.parse(text)
        }

        let lines = preprocess(text)
        var transactions = parseLineOriented(lines)
        if transactions.isEmpty {
            transactions = parseWithGlobalScan(text)
        }
        guard !transactions.isEmpty else {
            throw MT940UtilityError.noTransactions
        }
        return MT940ParsedStatement(
            metadata: buildMetadata(from: transactions, source: "IMPORT/PDF"),
            transactions: transactions
        )
    }

    // MARK: - Line-oriented parser

    private static func parseLineOriented(_ lines: [String]) -> [MT940Transaction] {
        var transactions: [MT940Transaction] = []
        var pendingDate: Date?
        var pendingDescription: [String] = []

        func resetPending() {
            pendingDate = nil
            pendingDescription = []
        }

        func commit(date: Date, description: String, amount: Decimal, isDebit: Bool) {
            let narrative = description.trimmingCharacters(in: .whitespacesAndNewlines)
            transactions.append(
                MT940Transaction(
                    valueDate: date,
                    isDebit: isDebit,
                    amount: amount,
                    field61: buildField61(date: date, isDebit: isDebit, amount: amount),
                    narrative: narrative.isEmpty ? "Tranzactie extras banca" : narrative
                )
            )
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if shouldSkipLine(line) { continue }

            if let date = firstDate(in: line), isStandaloneDateLine(line, date: date) {
                pendingDate = date
                pendingDescription = []
                continue
            }

            if let pending = pendingDate {
                if let parsed = parseAmountsLine(line) {
                    let description = pendingDescription.joined(separator: " ")
                    let isDebit = refineDebitFlag(description: description, amountLine: line, parsedDebit: parsed.isDebit)
                    commit(date: pending, description: description, amount: parsed.amount, isDebit: isDebit)
                    resetPending()
                    continue
                }
                if let split = splitDescriptionAndAmounts(line) {
                    let isDebit = refineDebitFlag(description: split.description, amountLine: line, parsedDebit: split.isDebit)
                    commit(date: pending, description: split.description, amount: split.amount, isDebit: isDebit)
                    resetPending()
                    continue
                }
                pendingDescription.append(line)
                continue
            }

            if let single = parseSingleLineTransaction(line) {
                transactions.append(single)
            }
        }
        return transactions
    }

    // MARK: - Global scan fallback (text fragmentat din PDF)

    private static func parseWithGlobalScan(_ text: String) -> [MT940Transaction] {
        var results: [MT940Transaction] = []
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")

        let patterns = [
            #"(?i)(\d{2}[.\-/]\d{2}[.\-/]\d{2,4})\s+(.{4,140}?)\s+(\(?\-\+?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}\)?)"#,
            #"(?i)(\d{4}-\d{2}-\d{2})\s+(.{4,140}?)\s+(\(?\-\+?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}\)?)"#,
            #"(?i)(\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\s+(.{4,140}?)\s+(\(?\-\+?(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}\)?)"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = normalized as NSString
            let matches = regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length))
            for match in matches where match.numberOfRanges >= 4 {
                let dateRaw = ns.substring(with: match.range(at: 1))
                let desc = ns.substring(with: match.range(at: 2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let amountRaw = ns.substring(with: match.range(at: 3))
                guard let date = parseFlexibleDate(dateRaw),
                      let amount = parseFlexibleAmount(amountRaw),
                      amount.value > 0,
                      !shouldSkipLine(desc) else { continue }
                let isDebit = refineDebitFlag(description: desc, amountLine: amountRaw, parsedDebit: amount.isDebit)
                results.append(
                    MT940Transaction(
                        valueDate: date,
                        isDebit: isDebit,
                        amount: amount.value,
                        field61: buildField61(date: date, isDebit: isDebit, amount: amount.value),
                        narrative: desc
                    )
                )
            }
            if !results.isEmpty { break }
        }
        return dedupeTransactions(results)
    }

    private static func dedupeTransactions(_ items: [MT940Transaction]) -> [MT940Transaction] {
        var seen = Set<String>()
        var output: [MT940Transaction] = []
        for item in items {
            let key = "\(swiftDateCode(item.valueDate))|\(item.isDebit)|\(item.amount)|\(item.narrative.prefix(40))"
            if seen.insert(key).inserted {
                output.append(item)
            }
        }
        return output
    }

    // MARK: - Single line

    private static func parseSingleLineTransaction(_ line: String) -> MT940Transaction? {
        guard let date = firstDate(in: line) else { return nil }
        guard let parsed = parseAmountsLine(line) else { return nil }

        var description = line
        if let dateRange = line.range(of: romanianDatePattern, options: .regularExpression) {
            description.removeSubrange(dateRange)
        } else if let dateRange = line.range(of: isoDatePattern, options: .regularExpression) {
            description.removeSubrange(dateRange)
        } else if let dateRange = line.range(of: englishDatePattern, options: .regularExpression) {
            description.removeSubrange(dateRange)
        }
        description = stripAmounts(from: description).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return nil }

        let isDebit = refineDebitFlag(description: description, amountLine: line, parsedDebit: parsed.isDebit)
        return MT940Transaction(
            valueDate: date,
            isDebit: isDebit,
            amount: parsed.amount,
            field61: buildField61(date: date, isDebit: isDebit, amount: parsed.amount),
            narrative: description
        )
    }

    private static func splitDescriptionAndAmounts(_ line: String) -> (description: String, amount: Decimal, isDebit: Bool)? {
        guard let parsed = parseAmountsLine(line) else { return nil }
        let description = stripAmounts(from: line).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return nil }
        return (description, parsed.amount, parsed.isDebit)
    }

    // MARK: - Amounts

    private static func parseAmountsLine(_ line: String) -> (amount: Decimal, isDebit: Bool)? {
        let amounts = extractAmounts(from: line)
        guard !amounts.isEmpty else { return nil }

        if amounts.count >= 2 {
            let first = amounts[0]
            let second = amounts[1]
            if first.value > 0, second.value == 0 { return (first.value, first.isDebit) }
            if second.value > 0, first.value == 0 { return (second.value, second.isDebit) }
            if amounts.count >= 3 {
                let third = amounts[2]
                if first.value > 0, second.value == 0 { return (first.value, first.isDebit) }
                if second.value > 0, first.value == 0 { return (second.value, second.isDebit) }
                _ = third
            }
        }

        if let nz = amounts.first(where: { $0.value > 0 }) {
            return (nz.value, nz.isDebit)
        }
        return nil
    }

    private struct ParsedAmount {
        let value: Decimal
        let isDebit: Bool
    }

    private static func extractAmounts(from line: String) -> [ParsedAmount] {
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return [] }
        let nsLine = line as NSString
        return regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let raw = nsLine.substring(with: match.range(at: 1))
            guard let parsed = parseFlexibleAmount(raw) else { return nil }
            return ParsedAmount(value: parsed.value, isDebit: parsed.isDebit)
        }
    }

    private static func parseFlexibleAmount(_ raw: String) -> (value: Decimal, isDebit: Bool)? {
        var token = raw
            .replacingOccurrences(of: "(", with: "-")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }

        let negative = token.hasPrefix("-")
        if token.hasPrefix("-") || token.hasPrefix("+") {
            token.removeFirst()
        }

        let decimal: Decimal?
        if let comma = token.lastIndex(of: ","), let dot = token.lastIndex(of: ".") {
            decimal = comma > dot ? parseRomanianAmountToken(token) : parseEnglishAmountToken(token)
        } else if token.contains(",") {
            decimal = parseRomanianAmountToken(token)
        } else {
            decimal = parseEnglishAmountToken(token)
        }

        guard let value = decimal, value != 0 else { return nil }
        return (abs(value), negative || raw.contains("-") || raw.hasPrefix("("))
    }

    private static func parseRomanianAmountToken(_ token: String) -> Decimal? {
        var cleaned = token.replacingOccurrences(of: ".", with: "")
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: cleaned)
    }

    private static func parseEnglishAmountToken(_ token: String) -> Decimal? {
        let cleaned = token.replacingOccurrences(of: ",", with: "")
        return Decimal(string: cleaned)
    }

    private static func stripAmounts(from line: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: amountPattern) else { return line }
        let nsLine = line as NSString
        var result = line
        for match in regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length)).reversed() {
            if let range = Range(match.range, in: line) {
                result.removeSubrange(range)
            }
        }
        return result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
    }

    // MARK: - Dates

    private static func firstDate(in line: String) -> Date? {
        if let regex = try? NSRegularExpression(pattern: romanianDatePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return parseFlexibleDate(String(line[range]))
        }
        if let regex = try? NSRegularExpression(pattern: isoDatePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return parseFlexibleDate(String(line[range]))
        }
        if let regex = try? NSRegularExpression(pattern: englishDatePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return parseFlexibleDate(String(line[range]))
        }
        return nil
    }

    private static func isStandaloneDateLine(_ line: String, date: Date) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if let regex = try? NSRegularExpression(pattern: romanianDatePattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range, in: trimmed) {
            let rest = trimmed.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespaces)
            return rest.isEmpty
        }
        if let regex = try? NSRegularExpression(pattern: isoDatePattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range, in: trimmed) {
            let rest = trimmed.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespaces)
            return rest.isEmpty
        }
        if let regex = try? NSRegularExpression(pattern: englishDatePattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           let range = Range(match.range, in: trimmed) {
            let rest = trimmed.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespaces)
            return rest.isEmpty
        }
        _ = date
        return false
    }

    private static func parseFlexibleDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "dd.MM.yyyy", "dd-MM-yyyy", "dd/MM/yyyy", "yyyy-MM-dd",
            "dd.MM.yy", "dd-MM-yy", "dd/MM/yy", "yyyy/MM/dd",
            "d MMM yyyy", "dd MMM yyyy", "MMM d yyyy", "MMM dd yyyy",
            "d MMMM yyyy", "dd MMMM yyyy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        formatter.locale = Locale(identifier: "ro_RO")
        for format in ["d MMM yyyy", "dd MMM yyyy", "d MMMM yyyy", "dd MMMM yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    // MARK: - Helpers

    private static func preprocess(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression) }
    }

    private static func shouldSkipLine(_ line: String) -> Bool {
        let folded = line
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if headerExactMatches.contains(folded) { return true }
        if folded.hasPrefix("ro") && folded.contains("ingb") && folded.count < 40 { return true }
        if folded.range(of: #"^ro\d{2}[a-z]{4}\d+"#, options: .regularExpression) != nil { return true }
        if folded.contains("account description") && folded.count < 40 { return true }
        return false
    }

    private static func refineDebitFlag(description: String, amountLine: String, parsedDebit: Bool) -> Bool {
        if amountLine.contains("-") || amountLine.contains("(") { return true }
        if amountLine.contains("+") { return false }
        let folded = description
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        if folded.contains("incasare") || folded.contains("incoming") || folded.contains("received")
            || folded.contains("depunere") || folded.contains("credit transfer") {
            return false
        }
        if folded.contains("cumparare") || folded.contains("comision") || folded.contains("plata")
            || folded.contains("payment") || folded.contains("purchase") || folded.contains("fee") {
            return true
        }
        return parsedDebit
    }

    private static func buildField61(date: Date, isDebit: Bool, amount: Decimal) -> String {
        let dc = isDebit ? "D" : "C"
        return ":61:\(swiftDateCode(date))\(dc)\(mt940AmountString(amount))NTRFNONREF//\(UUID().uuidString.prefix(8))"
    }

    private static func buildMetadata(from transactions: [MT940Transaction], source: String) -> MT940StatementMetadata {
        var metadata = MT940StatementMetadata()
        let sortedDays = transactions.map { Calendar.current.startOfDay(for: $0.valueDate) }.sorted()
        let running = transactions.reduce(Decimal.zero) { $0 + ($1.isDebit ? -$1.amount : $1.amount) }
        metadata.openingBalanceDate = sortedDays.first ?? Date()
        metadata.closingBalanceDate = sortedDays.last ?? Date()
        metadata.field20 = ":20:STMT\(swiftDateCode(metadata.openingBalanceDate))"
        metadata.field25 = ":25:\(source)"
        metadata.field28C = ":28C:00001/00001"
        metadata.openingBalanceLine = ":60F:C\(swiftDateCode(metadata.openingBalanceDate))\(metadata.currency)0,00"
        metadata.closingBalanceLine = ":62F:C\(swiftDateCode(metadata.closingBalanceDate))\(metadata.currency)\(mt940AmountString(abs(running)))"
        metadata.closingBalance = running
        return metadata
    }

    private static func swiftDateCode(_ date: Date) -> String {
        let c = Calendar.current
        return String(format: "%02d%02d%02d", c.component(.year, from: date) % 100, c.component(.month, from: date), c.component(.day, from: date))
    }

    private static func mt940AmountString(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "ro_RO")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ""
        return f.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
