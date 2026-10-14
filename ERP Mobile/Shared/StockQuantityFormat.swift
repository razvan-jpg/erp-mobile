import Combine
import Foundation

@MainActor
final class StockQuantityFormat: ObservableObject {
    static let shared = StockQuantityFormat()
    static let choices = [2, 3, 4]

    @Published private(set) var fractionDigits: Int = 2

    static func normalized(_ digits: Int) -> Int {
        choices.contains(digits) ? digits : 2
    }

    static func fallback(for company: Company) -> Int {
        let cui = (company.cui ?? "")
            .uppercased()
            .replacingOccurrences(of: "RO", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cui == "51159591" || company.denumire.uppercased().contains("NECTARIE") {
            return 4
        }
        return 2
    }

    func apply(_ digits: Int) {
        let next = Self.normalized(digits)
        if fractionDigits != next {
            fractionDigits = next
        }
    }

    func load(for company: Company) async {
        do {
            if let digits = try await CompanyStockSettingsService.fetchFractionDigits(companyId: company.id) {
                apply(digits)
            } else {
                apply(Self.fallback(for: company))
            }
        } catch {
            apply(Self.fallback(for: company))
        }
    }

    func string(_ value: Decimal) -> String {
        SupplierFormatting.fixedQuantityString(value, fractionDigits: fractionDigits)
    }
}
