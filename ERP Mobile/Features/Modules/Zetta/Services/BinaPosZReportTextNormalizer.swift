import Foundation

/// Convertește textul extras din PDF-urile BINA Smart Business (format englez POS)
/// în etichetele așteptate de `ZParser` (format român Nectarie / POS digital).
enum BinaPosZReportTextNormalizer {
    nonisolated static func prepareOCRTextForZParser(_ text: String) -> String {
        normalizeForParser(normalizeIfNeeded(text))
    }

    nonisolated static func normalizeIfNeeded(_ text: String) -> String {
        guard looksLikeEnglishBinaPOS(text) else { return text }
        return normalizeForParser(text)
    }

    /// Layout ca la descărcarea manuală din BINA (eu.pdf): etichete RO, valori pe rând separat.
    nonisolated static func romanianExportLayout(from text: String) -> String {
        let preserved = preservedLines(text)
        if isAlreadyRomanianBinaLayout(preserved) {
            return preserved
        }
        return buildRomanianExportLayout(from: preserved)
    }

    nonisolated static func preservedLines(_ text: String) -> String {
        preserveOriginalLineBreaks(text)
    }

    /// Etichete RO fără diacritice — pentru export Zetta după descărcare EN de la BINA.
    nonisolated static func romanianExportLayoutWithoutDiacritics(from text: String) -> String {
        withoutDiacritics(romanianExportLayout(from: text))
    }

    nonisolated static func withoutDiacritics(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "ro_RO"))
    }

    nonisolated private static func buildRomanianExportLayout(from text: String) -> String {
        let rawLines = expandInlineEnglishLabels(text).components(separatedBy: "\n")
        var lines: [String] = []
        var index = 0

        func appendLabel(_ label: String, value: String?, trailingRON: Bool = false) {
            lines.append(label)
            if let value, !value.isEmpty {
                lines.append(value + (trailingRON ? " " : ""))
                if trailingRON { lines.append("RON") }
            } else {
                lines.append("")
            }
        }

        while index < rawLines.count {
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = folded(trimmed)

            if upper == "Z REPORT NO." || upper == "Z REPORT NO" {
                if let number = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Z report Număr", value: number)
                    index += 2
                    continue
                }
            }

            if upper == "LOCATION" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Locaţia", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "POS NUMBER" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Număr POS", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "USER" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Utilizator", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "FROM" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("De la", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "TO" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Până la", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "DOCUMENTS" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    appendLabel("Documente", value: value)
                    index += 2
                    continue
                }
            }

            if upper == "TOTAL" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Total", value: amount.text, trailingRON: true)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "PAYMENT TYPES" {
                lines.append("Metode de Plată")
                index += 1
                continue
            }

            if upper == "CASH" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Numerar", value: amount.text, trailingRON: true)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "CREDIT CARDS" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Credit cards", value: amount.text, trailingRON: true)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "PLATA MODERNA" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Plata moderna", value: amount.text, trailingRON: true)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "VAT GROUP BREAKDOWN" {
                lines.append("TVA")
                index += 1
                continue
            }

            if upper.hasPrefix("BRUT A") {
                if let merged = mergeBrutLine(category: "A", rate: "21", from: rawLines, start: index) {
                    lines.append("BRUT A ")
                    lines.append("TVA 21%")
                    lines.append(merged.amount)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("BRUT B") {
                if let merged = mergeBrutLine(category: "B", rate: "11", from: rawLines, start: index) {
                    lines.append("BRUT B ")
                    lines.append("TVA 11%")
                    lines.append(merged.amount)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("BRUT D") {
                if let merged = mergeBrutLine(category: "D", rate: "0", from: rawLines, start: index) {
                    lines.append("BRUT D ")
                    lines.append("TVA 0%")
                    lines.append(merged.amount)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT A") || upper.hasPrefix("TVA A") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA A 21%")
                    lines.append(amount.text)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT B") || upper.hasPrefix("TVA B") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA B 11%")
                    lines.append(amount.text)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT D") || upper.hasPrefix("TVA D") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA D 0%")
                    lines.append(amount.text)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "TOTAL VAT" || upper == "TOTAL TVA" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Total TVA", value: amount.text)
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "TOTAL SOLD" || upper == "TOTAL VANZARI" || upper == "TOTAL VÂNZĂRI" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    appendLabel("Total vânzări", value: amount.text)
                    index = amount.nextIndex
                    continue
                }
            }

            if !trimmed.isEmpty {
                lines.append(trimmed)
            }
            index += 1
        }

        return lines.joined(separator: "\n")
    }

    nonisolated static func looksLikeEnglishBinaPOS(_ text: String) -> Bool {
        let folded = folded(text)
        guard folded.contains("Z REPORT") else { return false }
        return folded.contains("LOCATION")
            || folded.contains("PAYMENT TYPES")
            || folded.contains("TOTAL SOLD")
            || folded.contains("BRUT A VAT")
            || (folded.contains("BRUT A") && folded.contains("VAT 21"))
    }

    nonisolated static func isAlreadyRomanianBinaLayout(_ text: String) -> Bool {
        let foldedText = folded(text)
        let hasZ = foldedText.contains("Z REPORT") && foldedText.contains("NUMAR")
        let hasLoc = foldedText.contains("LOCATIA") || foldedText.contains("LOCATIE")
        let hasPay = foldedText.contains("METODE DE PLATA") || foldedText.contains("METODE DE PLAT")
        return hasZ && hasLoc && hasPay
    }

    nonisolated static func hasRomanianBinaMarkers(_ text: String) -> Bool {
        let foldedText = folded(text)
        return foldedText.contains("LOCATIA")
            || foldedText.contains("LOCATIE")
            || foldedText.contains("PANA LA")
            || foldedText.contains("METODE DE PLAT")
            || foldedText.contains("DE LA")
    }

    nonisolated static func isRomanianBinaPDFText(_ text: String) -> Bool {
        if isAlreadyRomanianBinaLayout(text) { return true }
        if looksLikeEnglishBinaPOS(text) { return false }
        return hasRomanianBinaMarkers(text)
    }

    nonisolated static func normalizeForParser(_ text: String) -> String {
        let rawLines = expandInlineEnglishLabels(preserveOriginalLineBreaks(text))
            .components(separatedBy: "\n")

        var lines: [String] = []
        var index = 0
        while index < rawLines.count {
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = folded(trimmed)

            if upper == "Z REPORT NO." || upper == "Z REPORT NO" || upper == "Z REPORT NUMAR" || upper == "Z REPORT NUMĂR" {
                if let number = nextMeaningfulLine(from: rawLines, start: index + 1),
                   number.range(of: #"^\d{1,4}$"#, options: .regularExpression) != nil {
                    lines.append("Z report Numar \(number)")
                    index += 2
                    continue
                }
            }

            if upper == "LOCATION" || upper == "LOCAŢIA" || upper == "LOCATIA" || upper == "LOCAȚIA" {
                if let location = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("Localia \(location)")
                    index += 2
                    continue
                }
            }

            if upper == "POS NUMBER" || upper == "NUMAR POS" || upper == "NUMĂR POS" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("POS number \(value)")
                    index += 2
                    continue
                }
            }

            if upper == "USER" || upper == "UTILIZATOR" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("User \(value)")
                    index += 2
                    continue
                }
            }

            if upper == "FROM" || upper == "DE LA" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("Dela \(value)")
                    index += 2
                    continue
                }
            }

            if upper == "TO" || upper == "PANA LA" || upper == "PÂNĂ LA" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("Pana la \(value)")
                    index += 2
                    continue
                }
            }

            if upper == "DOCUMENTS" || upper == "DOCUMENTE" {
                if let value = nextMeaningfulLine(from: rawLines, start: index + 1) {
                    lines.append("Documents \(value)")
                    index += 2
                    continue
                }
            }

            if upper == "PAYMENT TYPES" || upper == "METODE DE PLATA" || upper == "METODE DE PLATĂ" {
                lines.append("Metode de Plata")
                index += 1
                continue
            }

            if upper == "CASH" || upper == "NUMERAR" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Numerar \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
                lines.append("Numerar")
                index += 1
                continue
            }

            if upper == "CREDIT CARDS" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Credit cards \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "PLATA MODERNA" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Plata moderna \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "VAT GROUP BREAKDOWN" || upper == "TVA" {
                lines.append("TVA")
                index += 1
                continue
            }

            if upper.hasPrefix("BRUT A") {
                if let merged = mergeBrutLine(category: "A", rate: "21", from: rawLines, start: index) {
                    lines.append(merged.line)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("BRUT B") {
                if let merged = mergeBrutLine(category: "B", rate: "11", from: rawLines, start: index) {
                    lines.append(merged.line)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("BRUT D") {
                if let merged = mergeBrutLine(category: "D", rate: "0", from: rawLines, start: index) {
                    lines.append(merged.line)
                    index = merged.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT A") || upper.hasPrefix("TVA A") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA A 21% \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT B") || upper.hasPrefix("TVA B") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA B 11% \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper.hasPrefix("VAT D") || upper.hasPrefix("TVA D") {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("TVA D 0% \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "TOTAL SOLD" || upper == "TOTAL VANZARI" || upper == "TOTAL VÂNZĂRI" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Total vanzari \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
                lines.append("Total vanzari")
                index += 1
                continue
            }

            if upper == "TOTAL VAT" || upper == "TOTAL TVA" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Total TVA \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            if upper == "TOTAL" {
                if let amount = nextAmountLine(from: rawLines, start: index + 1) {
                    lines.append("Total \(amount.text)")
                    index = amount.nextIndex
                    continue
                }
            }

            lines.append(trimmed)
            index += 1
        }

        return lines.joined(separator: "\n")
    }

    nonisolated private static func preserveOriginalLineBreaks(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Desface etichete engleze lipite pe același rând (PDF reconstruit de aplicație).
    nonisolated private static func expandInlineEnglishLabels(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                lines.append("")
                continue
            }

            if let expanded = expandSingleInlineEnglishLine(line) {
                lines.append(contentsOf: expanded)
            } else {
                lines.append(rawLine)
            }
        }
        return lines.joined(separator: "\n")
    }

    nonisolated private static func expandSingleInlineEnglishLine(_ line: String) -> [String]? {
        let patterns: [(String, (NSTextCheckingResult, String) -> [String]?)] = [
            (#"(?i)^Z report No\.\s*(\d+)\s*$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Z report No.", String(source[range])]
            }),
            (#"(?i)^Location\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Location", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^POS number\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["POS number", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^User\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["User", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^From\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["From", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^To\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["To", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Documents\s+(.+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Documents", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Cash\s+([\d\.,]+)(?:\s+RON)?$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Cash", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Credit cards\s+([\d\.,]+)(?:\s+RON)?$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Credit cards", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Plata moderna\s+([\d\.,]+)(?:\s+RON)?$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Plata moderna", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Total\s+([\d\.,]+)(?:\s+RON)?$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Total", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^BRUT A VAT 21%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["BRUT A", "VAT 21%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^BRUT B VAT 11%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["BRUT B", "VAT 11%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^BRUT D VAT 0%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["BRUT D", "VAT 0%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^VAT A 21%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["VAT A 21%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^VAT B 11%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["VAT B 11%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^VAT D 0%\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["VAT D 0%", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Total Sold\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Total Sold", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
            (#"(?i)^Total VAT\s+([\d\.,]+)$"# , { match, source in
                guard let range = Range(match.range(at: 1), in: source) else { return nil }
                return ["Total VAT", String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)]
            }),
        ]

        for (pattern, builder) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let expanded = builder(match, line) else { continue }
            return expanded
        }
        return nil
    }

    private struct AmountLine {
        let text: String
        let nextIndex: Int
    }

    private struct MergedLine {
        let line: String
        let amount: String
        let nextIndex: Int
    }

    nonisolated private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US")).uppercased()
    }

    nonisolated private static func nextMeaningfulLine(from lines: [String], start: Int) -> String? {
        var index = start
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
            index += 1
        }
        return nil
    }

    nonisolated private static func nextAmountLine(from lines: [String], start: Int) -> AmountLine? {
        var index = start
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            if folded(trimmed) == "RON" {
                index += 1
                continue
            }
            if trimmed.range(of: #"\d"#, options: .regularExpression) != nil {
                return AmountLine(text: trimmed, nextIndex: index + 1)
            }
            return nil
        }
        return nil
    }

    nonisolated private static func isStandaloneVatRateLabel(_ folded: String) -> Bool {
        folded.range(of: #"^(VAT|TVA)\s+\d+%"#, options: .regularExpression) != nil
    }

    nonisolated private static func mergeBrutLine(
        category: String,
        rate: String,
        from lines: [String],
        start: Int
    ) -> MergedLine? {
        var index = start + 1
        var amount: String?
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            let upper = folded(trimmed)
            if upper == "RON" {
                index += 1
                continue
            }
            // "VAT 21%" / "TVA 11%" sunt eticheta cotei, nu următorul grup — suma e pe rândul de după.
            if isStandaloneVatRateLabel(upper) {
                index += 1
                continue
            }
            if upper.hasPrefix("BRUT ") || upper.hasPrefix("VAT A") || upper.hasPrefix("VAT B")
                || upper.hasPrefix("VAT C") || upper.hasPrefix("VAT D")
                || upper.hasPrefix("TVA A") || upper.hasPrefix("TVA B")
                || upper.hasPrefix("TVA C") || upper.hasPrefix("TVA D")
                || upper == "TOTAL SOLD" || upper == "TOTAL VAT" || upper == "TOTAL VANZARI" {
                break
            }
            if trimmed.range(of: #"\d"#, options: .regularExpression) != nil {
                amount = trimmed
                index += 1
                break
            }
            index += 1
        }
        guard let amount else { return nil }
        return MergedLine(
            line: "BRUT \(category) TVA \(rate)% \(amount)",
            amount: amount,
            nextIndex: index
        )
    }
}
