import Foundation

enum BarcodeMatching {
    static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    static func exactMatch(productBarcode: String?, scanned: String) -> Bool {
        guard let productBarcode else { return false }
        let left = normalize(productBarcode)
        let right = normalize(scanned)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left.caseInsensitiveCompare(right) == .orderedSame
    }

    static func matchesField(_ field: String?, query: String) -> Bool {
        guard let field else { return false }
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return false }
        let normalizedField = normalize(field)
        guard !normalizedField.isEmpty else { return false }
        return normalizedField.localizedCaseInsensitiveContains(normalizedQuery)
            || normalizedQuery.localizedCaseInsensitiveContains(normalizedField)
    }
}
