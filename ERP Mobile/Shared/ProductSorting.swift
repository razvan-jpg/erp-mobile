import Foundation

enum ProductSorting {
    private nonisolated static let romanianLocale = Locale(identifier: "ro_RO")

    nonisolated static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func byName(_ lhs: Product, _ rhs: Product) -> Bool {
        let left = normalizedName(lhs.denumire)
        let right = normalizedName(rhs.denumire)
        let comparison = left.compare(
            right,
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: romanianLocale
        )
        if comparison == .orderedSame {
            let leftCode = normalizedName(lhs.cod ?? "")
            let rightCode = normalizedName(rhs.cod ?? "")
            return leftCode.localizedCompare(rightCode) == .orderedAscending
        }
        return comparison == .orderedAscending
    }

    nonisolated static func sortedByName(_ products: [Product]) -> [Product] {
        products.sorted(by: byName)
    }
}
