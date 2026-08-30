import Foundation

/// Extrage titularul contului din extras (PDF/MT940/CSV) — fără legătură cu firma activă din ERP.
enum MT940StatementLabelExtractor {
    static func extract(from text: String) -> String? {
        if let raiffeisen = extractRaiffeisenAccountHolder(from: text) {
            return raiffeisen
        }
        if let mt940 = extractMT940AccountHolder(from: text) {
            return mt940
        }
        if let generic = extractGenericAccountHolder(from: text) {
            return generic
        }
        return nil
    }

    static func extract(fromFileName fileName: String) -> String? {
        let base = (fileName as NSString).deletingPathExtension
        guard base.lowercased().hasPrefix("extrase_") else { return nil }

        let parts = base.split(separator: "_").map(String.init)
        guard parts.count >= 4 else { return nil }

        let tail = parts.dropFirst(3).joined(separator: " ")
        let cleaned = tail
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    static func resolveCompanyName(
        metadata: MT940StatementMetadata,
        sourceTexts: [String],
        fileNames: [String]
    ) -> String {
        if !metadata.accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return metadata.accountHolderName
        }
        for text in sourceTexts {
            if let name = extract(from: text) {
                return name
            }
        }
        for fileName in fileNames {
            if let name = extract(fromFileName: fileName) {
                return name
            }
        }
        return "Export"
    }

    // MARK: - Raiffeisen PDF

    private static func extractRaiffeisenAccountHolder(from text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, line) in lines.enumerated() {
            let folded = line
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
            if folded == "adresa" || folded.hasPrefix("adresa ") {
                if index > 0, looksLikeCompanyName(lines[index - 1]) {
                    return lines[index - 1]
                }
            }
        }

        for line in lines {
            if looksLikeCompanyName(line), line.contains(" SRL") || line.contains(" SA")
                || line.contains(" S.R.L") || line.contains(" S.A") {
                return line
            }
        }
        return nil
    }

    // MARK: - MT940 nativ

    private static func extractMT940AccountHolder(from text: String) -> String? {
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.uppercased().hasPrefix(":86:NAME") {
                let name = line
                    .replacingOccurrences(of: ":86:NAME", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeCompanyName(name) { return name }
            }
            if line.uppercased().hasPrefix("NAME ACCOUNT OWNER") {
                let name = line
                    .replacingOccurrences(of: "NAME ACCOUNT OWNER", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeCompanyName(name) { return name }
            }
        }
        return nil
    }

    // MARK: - Generic

    private static func extractGenericAccountHolder(from text: String) -> String? {
        let patterns = [
            #"(?i)titular(?:\s+cont)?\s*[:\-]\s*(.+)$"#,
            #"(?i)account\s+holder\s*[:\-]\s*(.+)$"#,
            #"(?i)client(?:\s+name)?\s*[:\-]\s*(.+)$"#,
            #"(?i)denumire\s+(?:client|beneficiar)\s*[:\-]\s*(.+)$"#,
        ]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      match.numberOfRanges >= 2,
                      let range = Range(match.range(at: 1), in: line) else { continue }
                let candidate = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if looksLikeCompanyName(candidate) { return candidate }
            }
        }
        return nil
    }

    private static func looksLikeCompanyName(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 120 else { return false }

        let folded = trimmed
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let blocked = [
            "extras de cont", "statement", "perioada", "data generare", "sold",
            "descrierea", "debit", "credit", "iban", "raiffeisen", "banca",
            "account statement", "opening balance", "closing balance"
        ]
        if blocked.contains(where: { folded.contains($0) }) { return false }
        if trimmed.range(of: #"^\d{2}[.\-/]\d{2}"#, options: .regularExpression) != nil { return false }
        if trimmed.range(of: #"^RO\d{2}\b"#, options: .regularExpression) != nil { return false }
        return true
    }
}
