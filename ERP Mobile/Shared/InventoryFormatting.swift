import Foundation

enum InventoryFormatting {
    static func vatPercent(_ value: Decimal) -> String {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        let formatted = SupplierFormatting.amountString(rounded)
        if formatted.hasSuffix(",00") {
            return String(formatted.dropLast(3)) + "%"
        }
        return "\(formatted)%"
    }
}
