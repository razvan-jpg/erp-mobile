import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

enum HRJournalNotePDFParser {
    struct ParsedNote: Sendable {
        var entries: [HRJournalEntry]
        var companyName: String?
        var dateYYYYMMDD: Int
        var journal: String
    }

    enum ParseError: LocalizedError {
        case invalidPDF
        case noText
        case noEntries

        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return L10n.tr("utilities.payroll_nc.error_invalid_pdf")
            case .noText:
                return L10n.tr("utilities.payroll_nc.error_no_text")
            case .noEntries:
                return L10n.tr("utilities.payroll_nc.error_no_entries")
            }
        }
    }

    static func parse(
        pdfData: Data,
        defaultNoteNumber: Int = 1,
        defaultJournal: String = "OD"
    ) throws -> ParsedNote {
        let candidates = try textCandidates(from: pdfData)
        var best: ParsedNote?
        for candidate in candidates {
            let parsed = parse(
                lines: candidate,
                defaultNoteNumber: defaultNoteNumber,
                defaultJournal: defaultJournal
            )
            if parsed.entries.count > (best?.entries.count ?? 0) {
                best = parsed
            }
        }
        guard let best, !best.entries.isEmpty else {
            throw ParseError.noEntries
        }
        return best
    }

    static func parse(
        lines: [String],
        defaultNoteNumber: Int = 1,
        defaultJournal: String = "OD"
    ) -> ParsedNote {
        let cleaned = lines
            .map { $0.replacingOccurrences(of: "\u{00A0}", with: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let dateYYYYMMDD = extractedDate(from: cleaned) ?? todayYYYYMMDD()
        let journal = extractedJournal(from: cleaned) ?? defaultJournal
        let companyName = extractedCompany(from: cleaned)
        let sagaEntries = looksLikeSaga(cleaned)
            ? parseSagaEntries(
                from: cleaned,
                defaultNoteNumber: defaultNoteNumber,
                journal: journal,
                dateYYYYMMDD: dateYYYYMMDD
            )
            : []
        if !sagaEntries.isEmpty {
            return ParsedNote(
                entries: sagaEntries,
                companyName: companyName,
                dateYYYYMMDD: dateYYYYMMDD,
                journal: journal
            )
        }

        var entries: [HRJournalEntry] = []
        for line in cleaned {
            if isHeaderOrNoise(line) { continue }
            if let entry = parseRow(
                line,
                defaultNoteNumber: defaultNoteNumber,
                defaultJournal: journal,
                dateYYYYMMDD: dateYYYYMMDD
            ) {
                entries.append(entry)
            }
        }

        return ParsedNote(
            entries: entries,
            companyName: companyName,
            dateYYYYMMDD: dateYYYYMMDD,
            journal: journal
        )
    }

    static func remapped(_ entries: [HRJournalEntry], startingAt firstNumber: Int) -> [HRJournalEntry] {
        guard firstNumber >= 1 else { return entries }
        var map: [Int: Int] = [:]
        var next = firstNumber
        return entries.map { entry in
            var copy = entry
            if map[entry.number] == nil {
                map[entry.number] = next
                next += 1
            }
            copy.number = map[entry.number] ?? firstNumber
            if entry.documentNumber == "\(entry.number)" {
                copy.documentNumber = "\(copy.number)"
            }
            return copy
        }
    }

    private static func looksLikeSaga(_ lines: [String]) -> Bool {
        lines.contains { line in
            let folded = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            return (folded.contains("cont debitor") && folded.contains("cont creditor"))
                || folded.contains("sagaweb")
        }
    }

    /// Saga / SagaWEB: `Nr. crt. Explicatie Cont debitor Cont creditor Suma Nr. doc Tip`
    /// Sumele sunt `66 660.00`; `%` înseamnă înregistrare compusă (următoarele rânduri cu un singur cont).
    private static func parseSagaEntries(
        from lines: [String],
        defaultNoteNumber: Int,
        journal: String,
        dateYYYYMMDD: Int
    ) -> [HRJournalEntry] {
        let sources: [String] = [lines.joined(separator: "\n")] + lines
        var rows: [SagaRow] = []
        var seen = Set<String>()
        for source in sources {
            for row in sagaRows(in: source) where seen.insert(row.fingerprint).inserted {
                rows.append(row)
            }
        }
        rows.sort { $0.crt < $1.crt }
        guard !rows.isEmpty else { return [] }

        var entries: [HRJournalEntry] = []
        /// NextUp nu acceptă notă compusă: un debit cu mai multe credite se sparge în perechi 1:1.
        var compoundCounterpart: (account: String, side: String)?
        for row in rows {
            let document = row.documentNumber.isEmpty ? "\(defaultNoteNumber)" : row.documentNumber
            if let debit = row.debitAccount, let credit = row.creditAccount {
                entries.append(makeEntry(note: defaultNoteNumber, journal: journal, dateYYYYMMDD: dateYYYYMMDD, document: document, account: debit, explanation: row.explanation, amount: row.amount, debitCredit: "D"))
                entries.append(makeEntry(note: defaultNoteNumber, journal: journal, dateYYYYMMDD: dateYYYYMMDD, document: document, account: credit, explanation: row.explanation, amount: row.amount, debitCredit: "C"))
                compoundCounterpart = nil
            } else if let debit = row.debitAccount, row.creditIsCompound {
                compoundCounterpart = (debit, "D")
            } else if row.debitIsCompound, let credit = row.creditAccount {
                compoundCounterpart = (credit, "C")
            } else if let only = row.debitAccount ?? row.creditAccount {
                if let counterpart = compoundCounterpart {
                    let debitAccount = counterpart.side == "D" ? counterpart.account : only
                    let creditAccount = counterpart.side == "C" ? counterpart.account : only
                    entries.append(makeEntry(note: defaultNoteNumber, journal: journal, dateYYYYMMDD: dateYYYYMMDD, document: document, account: debitAccount, explanation: row.explanation, amount: row.amount, debitCredit: "D"))
                    entries.append(makeEntry(note: defaultNoteNumber, journal: journal, dateYYYYMMDD: dateYYYYMMDD, document: document, account: creditAccount, explanation: row.explanation, amount: row.amount, debitCredit: "C"))
                } else {
                    entries.append(makeEntry(note: defaultNoteNumber, journal: journal, dateYYYYMMDD: dateYYYYMMDD, document: document, account: only, explanation: row.explanation, amount: row.amount, debitCredit: "D"))
                }
            }
        }
        return entries
    }

    private static func sagaRows(in text: String) -> [SagaRow] {
        let pattern = #"(\d+)\s+(.+?)\s+(\d{3,4}|%)(?:\s+(\d{3,4}|%))?\s+(\d{1,3}(?:[ \u00A0]\d{3})*\.\d{2})\s+(\d+)\s+(\S+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges >= 8 else { return nil }
            func group(_ index: Int) -> String {
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
            let amountText = group(5).replacingOccurrences(of: "\u{00A0}", with: " ")
            guard let amount = SupplierFormatting.parseAmount(amountText), amount > 0 else { return nil }
            let first = group(3)
            let second = group(4)
            return SagaRow(
                crt: Int(group(1)) ?? 0,
                explanation: group(2).trimmingCharacters(in: .whitespacesAndNewlines),
                debitToken: first,
                creditToken: second,
                amount: amount,
                documentNumber: group(6)
            )
        }
    }

    private struct SagaRow {
        var crt: Int
        var explanation: String
        var debitToken: String
        var creditToken: String
        var amount: Decimal
        var documentNumber: String

        var fingerprint: String { "\(crt)|\(debitToken)|\(creditToken)|\(amount)|\(documentNumber)" }

        var debitIsCompound: Bool { debitToken == "%" }
        var creditIsCompound: Bool { creditToken == "%" }
        var debitAccount: String? { sagaAccount(debitToken) }
        var creditAccount: String? { sagaAccount(creditToken) }
    }

    private static func sagaAccount(_ token: String) -> String? {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != "%", !value.isEmpty, isAccount(value) else { return nil }
        return value
    }

    private static func makeEntry(
        note: Int,
        journal: String,
        dateYYYYMMDD: Int,
        document: String,
        account: String,
        explanation: String,
        amount: Decimal,
        debitCredit: String
    ) -> HRJournalEntry {
        HRJournalEntry(
            number: note,
            journal: journal,
            dateYYYYMMDD: dateYYYYMMDD,
            documentNumber: document,
            account: account,
            accountTitle: explanation,
            explanation: explanation,
            amount: amount,
            debitCredit: debitCredit,
            employeeCode: ""
        )
    }

    private static func parseRow(
        _ line: String,
        defaultNoteNumber: Int,
        defaultJournal: String,
        dateYYYYMMDD: Int
    ) -> HRJournalEntry? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 3 else { return nil }

        var note = defaultNoteNumber
        var journal = defaultJournal
        var start = 0
        if let first = Int(tokens[0]), first > 0, first < 1_000_000, !isAccount(tokens[0]) {
            let nextIsUseful = tokens.count > 1 && (isJournalToken(tokens[1]) || isAccount(tokens[1]))
            if nextIsUseful {
                note = first
                start = 1
            }
        }
        if start < tokens.count, isJournalToken(tokens[start]) {
            journal = tokens[start].uppercased()
            start += 1
        }
        guard start < tokens.count, isAccount(tokens[start]) else { return nil }
        let account = tokens[start]
        start += 1

        var debitCredit: String?
        var marca = ""
        if start < tokens.count, let dc = debitCreditToken(tokens[start]) {
            debitCredit = dc
            start += 1
        }
        if start < tokens.count, isMarca(tokens[start]) {
            marca = tokens[start]
            start += 1
        }
        if debitCredit == nil, start < tokens.count, let dc = debitCreditToken(tokens[start]) {
            debitCredit = dc
            start += 1
        }

        guard let amountIndex = lastAmountIndex(in: tokens) else { return nil }
        guard amountIndex >= start, let amount = SupplierFormatting.parseAmount(stripCurrency(tokens[amountIndex])), amount > 0 else {
            return nil
        }

        var explanationTokens = Array(tokens[start..<amountIndex])
        if debitCredit == nil, let last = explanationTokens.last, let dc = debitCreditToken(last) {
            debitCredit = dc
            explanationTokens.removeLast()
        }
        let explanation = explanationTokens.joined(separator: " ")
        guard let debitCredit else { return nil }

        return HRJournalEntry(
            number: note,
            journal: journal,
            dateYYYYMMDD: dateYYYYMMDD,
            documentNumber: "\(note)",
            account: account,
            accountTitle: "",
            explanation: explanation,
            amount: amount,
            debitCredit: debitCredit,
            employeeCode: marca
        )
    }

    private static func isHeaderOrNoise(_ line: String) -> Bool {
        let folded = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
        if folded.contains("numar inregistrare") { return true }
        if folded.contains("debit/credit") && folded.localizedCaseInsensitiveContains("cont") { return true }
        if folded.hasPrefix("nr.") && folded.contains("jurnal") { return true }
        if folded.contains("nota contabila") || folded.contains("stat de plata") { return true }
        if folded.contains("cui:") { return true }
        if folded.contains("cont debitor") && folded.contains("cont creditor") { return true }
        if folded.hasPrefix("total:") || folded.hasPrefix("intocmit") || folded.contains("sagaweb") {
            return true
        }
        return false
    }

    private static func isAccount(_ token: String) -> Bool {
        let value = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        guard let match = value.range(of: #"^\d{3,4}(?:\.\d{1,4})?$"#, options: .regularExpression) else {
            return false
        }
        _ = match
        if let year = Int(value), (2000...2100).contains(year) { return false }
        let digits = value.split(separator: ".").first.map(String.init) ?? value
        guard let first = digits.first, let cls = Int(String(first)), (1...8).contains(cls) else { return false }
        return (3...4).contains(digits.count)
    }

    private static func isJournalToken(_ token: String) -> Bool {
        let value = token.uppercased()
        return ["OD", "NC", "JV", "RC", "RF", "LN"].contains(value)
    }

    private static func debitCreditToken(_ token: String) -> String? {
        let value = token.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:")).uppercased()
        if value == "D" || value == "DEBIT" { return "D" }
        if value == "C" || value == "CREDIT" { return "C" }
        return nil
    }

    private static func isMarca(_ token: String) -> Bool {
        if debitCreditToken(token) != nil { return false }
        if isJournalToken(token) { return false }
        if SupplierFormatting.parseAmount(stripCurrency(token)) != nil, token.contains(",") || token.contains(".") {
            return false
        }
        let allowed = token.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) }
        return allowed && (2...12).contains(token.count)
    }

    private static func lastAmountIndex(in tokens: [String]) -> Int? {
        for index in tokens.indices.reversed() {
            let raw = stripCurrency(tokens[index])
            if SupplierFormatting.parseAmount(raw) != nil, raw.rangeOfCharacter(from: .decimalDigits) != nil {
                if raw.contains(",") || raw.contains(".") || raw.count >= 2 {
                    return index
                }
            }
        }
        return nil
    }

    private static func stripCurrency(_ token: String) -> String {
        var value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["lei", "RON", "ron"] where value.lowercased().hasSuffix(suffix.lowercased()) {
            value.removeLast(suffix.count)
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: ";").union(.whitespaces))
    }

    private static func extractedDate(from lines: [String]) -> Int? {
        let joined = lines.joined(separator: " ")
        if let match = firstMatch(#"\b(\d{2})[./-](\d{2})[./-](\d{4})\b"#, in: joined) {
            let day = Int(match[1]) ?? 0
            let month = Int(match[2]) ?? 0
            let year = Int(match[3]) ?? 0
            if (1...31).contains(day), (1...12).contains(month), year >= 2000 {
                return year * 10_000 + month * 100 + day
            }
        }
        if let match = firstMatch(#"\b(\d{4})(\d{2})(\d{2})\b"#, in: joined) {
            let year = Int(match[1]) ?? 0
            let month = Int(match[2]) ?? 0
            let day = Int(match[3]) ?? 0
            if (1...12).contains(month), (1...31).contains(day), (2000...2100).contains(year) {
                return year * 10_000 + month * 100 + day
            }
        }
        if let match = firstMatch(#"\b(\d{2})\s*/\s*(\d{4})\b"#, in: joined) {
            let month = Int(match[1]) ?? 0
            let year = Int(match[2]) ?? 0
            if (1...12).contains(month), year >= 2000 {
                return year * 10_000 + month * 100 + 1
            }
        }
        return nil
    }

    private static func extractedJournal(from lines: [String]) -> String? {
        for line in lines {
            let folded = line.uppercased()
            for token in ["OD", "NC", "JV"] where folded.contains("JURNAL") && folded.contains(token) {
                return token
            }
        }
        return nil
    }

    private static func extractedCompany(from lines: [String]) -> String? {
        for line in lines.prefix(8) {
            let folded = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            guard folded.contains("s.r.l") || folded.contains("srl") || folded.contains("s.a.") else { continue }
            var name = line
            for marker in ["c.f.", "c.f ", "CUI:", "CUI ", "r.c.", "R.C."] {
                if let range = name.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) {
                    name = String(name[..<range.lowerBound])
                    break
                }
            }
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? line : name
        }
        return nil
    }

    private static func todayYYYYMMDD() -> Int {
        HRPayrollJournalBuilder.yyyymmdd(Date())
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        var parts: [String] = []
        parts.reserveCapacity(match.numberOfRanges)
        for index in 0..<match.numberOfRanges {
            let nsRange = match.range(at: index)
            guard nsRange.location != NSNotFound, let range = Range(nsRange, in: text) else { return nil }
            parts.append(String(text[range]))
        }
        return parts
    }

    private static func textCandidates(from data: Data) throws -> [[String]] {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: data) else { throw ParseError.invalidPDF }
        var candidates: [[String]] = []
        var pageLines: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pageLines.append(contentsOf: text.components(separatedBy: .newlines))
            }
        }
        if !pageLines.isEmpty { candidates.append(pageLines) }
        let structured = PDFStructuredLineExtractor.extractLines(from: document)
        if !structured.isEmpty { candidates.append(structured) }
        if candidates.isEmpty { throw ParseError.noText }
        return candidates
        #else
        throw ParseError.invalidPDF
        #endif
    }
}
