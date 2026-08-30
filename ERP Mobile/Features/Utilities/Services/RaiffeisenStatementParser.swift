import Foundation

/// Parser pentru extrasul Raiffeisen (`account_statement.pdf`, Extras de cont din eBanking).
enum RaiffeisenStatementParser {
    private static let parsingLocale = Locale(identifier: "ro_RO")
    private static let parsingCalendar = Calendar(identifier: .gregorian)
    private static let amountSuffixPattern = #"(\d{1,3}(?:,\d{3})*\.\d{2}|\d+[.,]\d{2})$"#
    private static let dualDateSpacedPattern = #"^(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})\s+(.+?)\s+(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})$"#
    private static let dualDateCompactPattern = #"^(\d{2}\.\d{2}\.\d{4})(\d{2}\.\d{2}\.\d{4})(.+?)(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})$"#
    private static let dualDateStartSpacedPattern = #"^(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})\s+(.+)$"#
    private static let dualDateStartCompactPattern = #"^(\d{2}\.\d{2}\.\d{4})(\d{2}\.\d{2}\.\d{4})(.+)$"#
    /// PDFKit structured extraction: `03072026 03072026 AK20TR... 520515`
    private static let dualDateEightDigitPattern = #"^(\d{8})\s+(\d{8})\s+(.+?)\s+(\d{1,9})$"#
    private static let dualDateEightDigitStartPattern = #"^(\d{8})\s+(\d{8})\s+(.+)$"#
    private static let dualDatePairPattern = #"\d{2}\.\d{2}\.\d{4}\s+\d{2}\.\d{2}\.\d{4}"#
    private static let amountOnlyPattern = #"^(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})$"#
    private static let ibanPattern = #"^RO\d{2}\s"#

    static func isRaiffeisenStatement(_ text: String) -> Bool {
        let folded = text
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()
        if folded.contains("raiffeisen") || folded.contains("rzbrrobu") || folded.contains("rzbr ro") {
            return true
        }
        if folded.contains("extras de cont"), folded.contains("descrierea tranz") || folded.contains("suma debit") {
            return true
        }
        return estimateTransactionCount(in: text) >= 3
    }

    /// Estimează câte tranzacții ar putea fi extrase — util la alegerea textului PDF.
    static func previewTransactionCount(in text: String) -> Int {
        estimateTransactionCount(in: text)
    }

    private static func estimateTransactionCount(in text: String) -> Int {
        let lines = preprocess(text)
        var count = 0
        for rawLine in lines {
            let line = normalizeLine(rawLine)
            if shouldSkip(line) { continue }
            if parseSingleLine(line) != nil {
                count += 1
                continue
            }
            if isDualDateLine(line),
               let started = parseMultiLineStart(line),
               isMultiLinePaymentStart(started.description) {
                count += 1
            }
        }
        count += parseColumnarBlocks(from: preprocessRaw(text)).count
        if count > 0 { return count }

        let normalized = lines.map { normalizeLine($0) }.joined(separator: "\n")
        for pattern in [
            #"(?m)^(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})\s+(.+?)\s+(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})$"#,
            #"(?m)^(\d{8})\s+(\d{8})\s+(.+?)\s+(\d{1,9})$"#
        ] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            count += regex.numberOfMatches(
                in: normalized,
                range: NSRange(location: 0, length: (normalized as NSString).length)
            )
        }
        return count
    }

    /// Parsează mai multe extrageri PDF (plain + structured) și combină rezultatul.
    static func parseBest(from candidates: [String]) throws -> MT940ParsedStatement {
        var merged: [MT940Transaction] = []
        var combinedText = ""
        for text in candidates {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            combinedText += trimmed + "\n"
            if let result = try? parse(trimmed) {
                merged = dedupeTransactions(merged + result.transactions)
            }
        }
        guard !merged.isEmpty else {
            throw MT940UtilityError.noTransactions
        }
        return MT940ParsedStatement(
            metadata: buildMetadata(from: merged, source: "IMPORT/RAIFFEISEN/PDF", text: combinedText),
            transactions: merged
        )
    }

    static func parse(_ text: String) throws -> MT940ParsedStatement {
        let lines = preprocess(text)
        var transactions: [MT940Transaction] = []
        var pendingDate: Date?
        var pendingDescription: [String] = []

        func resetPending() {
            pendingDate = nil
            pendingDescription = []
        }

        func commit(date: Date, description: String, amount: Decimal) {
            let narrative = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDebit = classifyDebit(description: narrative)
            transactions.append(
                MT940Transaction(
                    valueDate: date,
                    isDebit: isDebit,
                    amount: amount,
                    field61: buildField61(date: date, isDebit: isDebit, amount: amount),
                    narrative: narrative.isEmpty ? "Tranzactie Raiffeisen" : narrative
                )
            )
        }

        for rawLine in lines {
            let line = normalizeLine(rawLine)
            if shouldSkip(line) { continue }

            if let parsed = parseSingleLine(line) {
                resetPending()
                commit(date: parsed.date, description: parsed.description, amount: parsed.amount)
                continue
            }

            if isDualDateLine(line) {
                resetPending()
                if let started = parseMultiLineStart(line), isMultiLinePaymentStart(started.description) {
                    pendingDate = started.date
                    pendingDescription = [started.description]
                }
                continue
            }

            if pendingDate != nil, isAmountOnlyLine(line), let amount = parseEnglishAmount(line) {
                let description = pendingDescription.joined(separator: " ")
                commit(date: pendingDate!, description: description, amount: amount)
                resetPending()
                continue
            }

            if pendingDate != nil {
                if shouldSkipDetailLine(line) { continue }
                pendingDescription.append(line)
            }
        }

        let scanned = parseGlobalScan(text)
        let columnar = parseColumnarBlocks(from: preprocessRaw(text))
        transactions = dedupeTransactions(transactions + scanned + columnar)

        guard !transactions.isEmpty else {
            throw MT940UtilityError.noTransactions
        }

        return MT940ParsedStatement(
            metadata: buildMetadata(from: transactions, source: "IMPORT/RAIFFEISEN/PDF", text: text),
            transactions: transactions
        )
    }

    // MARK: - Line parsing

    private struct ParsedLine {
        let date: Date
        let description: String
        let amount: Decimal
    }

    private static func parseSingleLine(_ line: String) -> ParsedLine? {
        if let parsed = parseComisionOPIBCompactLine(line) {
            return parsed
        }
        for pattern in [dualDateSpacedPattern, dualDateCompactPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges >= 5,
                  let dateRange = Range(match.range(at: 2), in: line),
                  let descRange = Range(match.range(at: 3), in: line),
                  let amountRange = Range(match.range(at: 4), in: line),
                  let date = parseDate(String(line[dateRange])),
                  let amount = parseEnglishAmount(String(line[amountRange])) else { continue }
            let description = String(line[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { continue }
            return ParsedLine(date: date, description: description, amount: amount)
        }
        guard let regex = try? NSRegularExpression(pattern: dualDateEightDigitPattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 5,
              let dateRange = Range(match.range(at: 2), in: line),
              let descRange = Range(match.range(at: 3), in: line),
              let amountRange = Range(match.range(at: 4), in: line),
              let date = parseCompactDateToken(String(line[dateRange])),
              let amount = parseCompactAmount(String(line[amountRange])) else { return nil }
        let description = String(line[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return nil }
        return ParsedLine(date: date, description: description, amount: amount)
    }

    private static func parseMultiLineStart(_ line: String) -> (date: Date, description: String)? {
        for pattern in [dualDateStartSpacedPattern, dualDateStartCompactPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges >= 4,
                  let dateRange = Range(match.range(at: 2), in: line),
                  let descRange = Range(match.range(at: 3), in: line),
                  let date = parseDate(String(line[dateRange])) else { continue }
            let description = String(line[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty, !isAmountOnlyLine(description) else { continue }
            return (date, description)
        }
        guard let regex = try? NSRegularExpression(pattern: dualDateEightDigitStartPattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4,
              let dateRange = Range(match.range(at: 2), in: line),
              let descRange = Range(match.range(at: 3), in: line),
              let date = parseCompactDateToken(String(line[dateRange])) else { return nil }
        let description = String(line[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty, !isAmountOnlyLine(description) else { return nil }
        return (date, description)
    }

    private static func parseComisionOPIBCompactLine(_ line: String) -> ParsedLine? {
        let pattern = #"^(\d{8})\s+(\d{8})\s+[Cc]omision\s*OPIB\s*[Ii]nterbancar(\d{1,9})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4,
              let dateRange = Range(match.range(at: 2), in: line),
              let amountRange = Range(match.range(at: 3), in: line),
              let date = parseCompactDateToken(String(line[dateRange])),
              let amount = parseCompactAmount(String(line[amountRange])) else { return nil }
        return ParsedLine(date: date, description: "Comision OPIB Interbancar", amount: amount)
    }

    private static func isMultiLinePaymentStart(_ description: String) -> Bool {
        let folded = description
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()
        return folded.hasPrefix("opib") || folded.hasPrefix("oph/")
    }

    private static func parseGlobalScan(_ text: String) -> [MT940Transaction] {
        var results: [MT940Transaction] = []
        let normalized = preprocess(text).map { normalizeLine($0) }.joined(separator: "\n")
        for pattern in [
            #"(?m)^(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})\s+(.+?)\s+(\d{1,3}(?:,\d{3})*\.\d{2}|\d+\.\d{2})$"#,
            #"(?m)^(\d{8})\s+(\d{8})\s+(.+?)\s+(\d{1,9})$"#
        ] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = normalized as NSString
            for match in regex.matches(in: normalized, range: NSRange(location: 0, length: ns.length)) {
                guard match.numberOfRanges >= 5,
                      let dateRange = Range(match.range(at: 2), in: normalized),
                      let descRange = Range(match.range(at: 3), in: normalized),
                      let amountRange = Range(match.range(at: 4), in: normalized) else { continue }
                let dateToken = String(normalized[dateRange])
                let amountToken = String(normalized[amountRange])
                let date = parseDate(dateToken) ?? parseCompactDateToken(dateToken)
                let amount = parseEnglishAmount(amountToken) ?? parseCompactAmount(amountToken)
                guard let date, let amount else { continue }
                let description = String(normalized[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !description.isEmpty, !shouldSkip(description) else { continue }
                let isDebit = classifyDebit(description: description)
                results.append(
                    MT940Transaction(
                        valueDate: date,
                        isDebit: isDebit,
                        amount: amount,
                        field61: buildField61(date: date, isDebit: isDebit, amount: amount),
                        narrative: description
                    )
                )
            }
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

    private static func isDualDateLine(_ line: String) -> Bool {
        if line.range(of: #"^\d{2}\.\d{2}\.\d{4}"#, options: .regularExpression) != nil,
           line.range(of: #"\d{2}\.\d{2}\.\d{4}"#, options: .regularExpression) != nil {
            return true
        }
        return line.range(of: #"^\d{8}\s+\d{8}\b"#, options: .regularExpression) != nil
    }

    // MARK: - Columnar PDF layout (PDFKit reads columns vertically)

    private struct ColumnarTransaction {
        let bookingDate: String
        let valueDate: String
        let description: String
    }

    private static func parseColumnarBlocks(from lines: [String]) -> [MT940Transaction] {
        var results: [MT940Transaction] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let dualCount = countDualDatePairs(in: line)
            guard dualCount >= 2, looksLikeDescriptionBlock(line) else {
                index += 1
                continue
            }

            let items = splitDescriptionBlock(line)
            guard !items.isEmpty else {
                index += 1
                continue
            }
            var debits: [String] = []
            var credits: [String] = []
            var cursor = index + 1
            while cursor < lines.count {
                let next = lines[cursor]
                if isAmountOnlyLine(next) {
                    debits.append(next)
                    cursor += 1
                    continue
                }
                if isSumColumnHeader(next, kind: "debit") {
                    cursor += 1
                    continue
                }
                if isSumColumnHeader(next, kind: "credit") {
                    cursor += 1
                    while cursor < lines.count, isAmountOnlyLine(lines[cursor]) {
                        credits.append(lines[cursor])
                        cursor += 1
                    }
                    break
                }
                break
            }

            var debitIndex = 0
            var creditIndex = 0
            for item in items {
                let isDebit = classifyDebit(description: item.description)
                let amountToken: String?
                if isDebit, debitIndex < debits.count {
                    amountToken = debits[debitIndex]
                    debitIndex += 1
                } else if !isDebit, creditIndex < credits.count {
                    amountToken = credits[creditIndex]
                    creditIndex += 1
                } else {
                    amountToken = nil
                }
                guard let amountToken,
                      let date = parseDate(item.valueDate),
                      let amount = parseEnglishAmount(amountToken) else { continue }
                results.append(
                    MT940Transaction(
                        valueDate: date,
                        isDebit: isDebit,
                        amount: amount,
                        field61: buildField61(date: date, isDebit: isDebit, amount: amount),
                        narrative: item.description
                    )
                )
            }
            index = max(cursor, index + 1)
        }
        return dedupeTransactions(results)
    }

    private static func countDualDatePairs(in line: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: dualDatePairPattern) else { return 0 }
        return regex.numberOfMatches(in: line, range: NSRange(line.startIndex..., in: line))
    }

    private static func looksLikeDescriptionBlock(_ line: String) -> Bool {
        let folded = line
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()
        return folded.contains("ak-") || (folded.contains("ak") && folded.contains("tr"))
            || folded.contains("comis") || folded.contains("opib") || folded.contains("abonament")
    }

    private static func splitDescriptionBlock(_ line: String) -> [ColumnarTransaction] {
        guard let regex = try? NSRegularExpression(pattern: #"(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})\s+"#) else {
            return []
        }
        let ns = line as NSString
        let lineLength = ns.length
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: lineLength))
        guard !matches.isEmpty else { return [] }

        var items: [ColumnarTransaction] = []
        for (offset, match) in matches.enumerated() {
            guard match.numberOfRanges >= 3,
                  let bookingRange = Range(match.range(at: 1), in: line),
                  let valueRange = Range(match.range(at: 2), in: line) else { continue }

            let fullMatch = match.range(at: 0)
            guard fullMatch.location != NSNotFound,
                  fullMatch.length > 0,
                  fullMatch.location + fullMatch.length <= lineLength else { continue }

            let descStart = fullMatch.location + fullMatch.length
            let descEnd = offset + 1 < matches.count ? matches[offset + 1].range.location : lineLength
            guard descStart >= 0, descEnd >= descStart, descEnd <= lineLength else { continue }

            var description = ns.substring(with: NSRange(location: descStart, length: descEnd - descStart))
            description = description.replacingOccurrences(
                of: #"[Ss]um[`']?\s*(debit|credit).*$"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { continue }
            items.append(
                ColumnarTransaction(
                    bookingDate: String(line[bookingRange]),
                    valueDate: String(line[valueRange]),
                    description: description
                )
            )
        }
        return items
    }

    private static func isSumColumnHeader(_ line: String, kind: String) -> Bool {
        let folded = line
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()
        if kind == "credit" {
            return folded.contains("sum") && folded.contains("credit")
        }
        return folded.contains("sum") && folded.contains("debit")
    }

    // MARK: - Normalization

    private static func preprocessRaw(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func preprocess(_ text: String) -> [String] {
        preprocessRaw(text)
    }

    private static func normalizeLine(_ line: String) -> String {
        var result = line
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let regex = try? NSRegularExpression(pattern: #"(\d{2}\.\d{2}\.\d{4})(\d{2}\.\d{2}\.\d{4})"#) {
            let ns = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: "$1 $2"
            )
        }

        if let regex = try? NSRegularExpression(pattern: #"(\d{2}\.\d{2}\.\d{4})\s+(\d{2}\.\d{2}\.\d{4})([A-Za-z])"#) {
            let ns = result as NSString
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: "$1 $2 $3"
            )
        }

        if let regex = try? NSRegularExpression(pattern: #"^(.+?)(\d{1,3}(?:,\d{3})*\.\d{2})$"#),
           let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           match.numberOfRanges >= 3,
           let bodyRange = Range(match.range(at: 1), in: result),
           let amountRange = Range(match.range(at: 2), in: result) {
            let body = String(result[bodyRange])
            let amount = String(result[amountRange])
            if let last = body.last, last.isLetter {
                result = "\(body) \(amount)"
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"^(.+?)(\d+\.\d{2})$"#),
           let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           match.numberOfRanges >= 3,
           let bodyRange = Range(match.range(at: 1), in: result),
           let amountRange = Range(match.range(at: 2), in: result) {
            let body = String(result[bodyRange])
            let amount = String(result[amountRange])
            if let last = body.last, last.isLetter, !body.hasSuffix(" ") {
                result = "\(body) \(amount)"
            }
        }

        return result
    }

    // MARK: - Classification

    private static func classifyDebit(description: String) -> Bool {
        let folded = description
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()

        if folded.hasPrefix("comis") || folded.contains("comision") || folded.hasPrefix("opib")
            || folded.contains("abonament") {
            return true
        }
        if folded.hasPrefix("ak-") || folded.hasPrefix("oph/") {
            return false
        }
        if folded.contains("pos restaurant") || folded.contains("pos ") {
            return false
        }
        return true
    }

    private static func shouldSkip(_ line: String) -> Bool {
        let folded = line
            .folding(options: .diacriticInsensitive, locale: parsingLocale)
            .lowercased()
        let skipKeywords = [
            "extras de cont", "perioada:", "data generare", "sold initial", "sold final",
            "rulaj debitor", "rulaj creditor", "descrierea tranz", "suma debit", "suma credit",
            "data tranz", "inregistrare", "numar client", "cod unic", "cod bic",
            "unitate bancara", "tip cont:", "valuta:", "pagina", "raiffeisen bank s.a",
            "soldul creditor", "prelucreaza datele", "www.raiffeisen",
            "suma debit", "suma credit", "sum` debit", "sum` credit"
        ]
        if skipKeywords.contains(where: { folded.contains($0) }) { return true }
        if folded == "data" || folded == "adresa" { return true }
        if line.range(of: ibanPattern, options: .regularExpression) != nil { return true }
        if folded.range(of: #"^\d{1,3}(?:,\d{3})*\.\d{2}\s+\d{1,3}(?:,\d{3})*\.\d{2}"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func shouldSkipDetailLine(_ line: String) -> Bool {
        let folded = line.folding(options: .diacriticInsensitive, locale: parsingLocale).lowercased()
        if line.range(of: ibanPattern, options: .regularExpression) != nil { return true }
        if folded.contains(" bank") || folded.hasSuffix(" s.a.") || folded.hasSuffix(" s.a") { return true }
        if folded.contains("branch") { return true }
        return false
    }

    private static func isAmountOnlyLine(_ line: String) -> Bool {
        line.range(of: amountOnlyPattern, options: .regularExpression) != nil
    }

    // MARK: - Amounts & dates

    private static func parseEnglishAmount(_ raw: String) -> Decimal? {
        let cleaned = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned), value > 0 else { return nil }
        return value
    }

    private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dotted = parseDottedDateComponents(trimmed) {
            return parsingCalendar.date(from: dotted)
        }
        return parseCompactDateToken(trimmed)
    }

    private static func parseCompactDateToken(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 8, trimmed.allSatisfy(\.isNumber) else { return nil }
        guard let day = Int(trimmed.prefix(2)),
              let month = Int(trimmed.dropFirst(2).prefix(2)),
              let year = Int(trimmed.suffix(4)) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return parsingCalendar.date(from: components)
    }

    private static func parseDottedDateComponents(_ raw: String) -> DateComponents? {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return components
    }

    private static func parseCompactAmount(_ raw: String) -> Decimal? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 3, let value = Decimal(string: digits) else { return nil }
        let divisor = Decimal(100)
        let amount = value / divisor
        guard amount > 0 else { return nil }
        return amount
    }

    // MARK: - MT940 helpers

    private static func buildField61(date: Date, isDebit: Bool, amount: Decimal) -> String {
        let dc = isDebit ? "D" : "C"
        return ":61:\(swiftDateCode(date))\(dc)\(mt940AmountString(amount))NTRFNONREF//\(UUID().uuidString.prefix(8))"
    }

    private static func buildMetadata(from transactions: [MT940Transaction], source: String, text: String) -> MT940StatementMetadata {
        var metadata = MT940StatementMetadata()
        let sortedDays = transactions.map { parsingCalendar.startOfDay(for: $0.valueDate) }.sorted()
        let running = transactions.reduce(Decimal.zero) { $0 + ($1.isDebit ? -$1.amount : $1.amount) }
        metadata.openingBalanceDate = sortedDays.first ?? Date()
        metadata.closingBalanceDate = sortedDays.last ?? Date()
        metadata.field20 = ":20:STMT\(swiftDateCode(metadata.openingBalanceDate))"
        metadata.field25 = ":25:\(extractIBAN(from: text) ?? source)"
        metadata.field28C = ":28C:00001/00001"
        metadata.openingBalanceLine = ":60F:C\(swiftDateCode(metadata.openingBalanceDate))\(metadata.currency)0,00"
        metadata.closingBalanceLine = ":62F:C\(swiftDateCode(metadata.closingBalanceDate))\(metadata.currency)\(mt940AmountString(abs(running)))"
        metadata.closingBalance = running
        if metadata.accountHolderName.isEmpty,
           let holder = MT940StatementLabelExtractor.extract(from: text) {
            metadata.accountHolderName = holder
        }
        return metadata
    }

    private static func extractIBAN(from text: String) -> String? {
        let pattern = #"RO\d{2}\s?[A-Z]{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range]).replacingOccurrences(of: " ", with: "")
    }

    private static func swiftDateCode(_ date: Date) -> String {
        let c = parsingCalendar
        return String(format: "%02d%02d%02d", c.component(.year, from: date) % 100, c.component(.month, from: date), c.component(.day, from: date))
    }

    private static func mt940AmountString(_ amount: Decimal) -> String {
        var value = amount
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        let numeric = NSDecimalNumber(decimal: rounded).stringValue
        return numeric.replacingOccurrences(of: ".", with: ",")
    }
}
