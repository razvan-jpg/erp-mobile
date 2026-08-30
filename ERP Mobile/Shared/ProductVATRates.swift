import Foundation

enum ProductVATRates {
    static let payerRates: [Decimal] = [0, 11, 21]
    static let nonPayerRate: Decimal = 0
    static let defaultPayerRate: Decimal = 21

    static func allowedRates(isVatPayer: Bool) -> [Decimal] {
        isVatPayer ? payerRates : [nonPayerRate]
    }

    static func defaultRate(isVatPayer: Bool) -> Decimal {
        isVatPayer ? defaultPayerRate : nonPayerRate
    }

    static func normalizedRate(_ rate: Decimal, isVatPayer: Bool) -> Decimal {
        let rounded = ProductService.roundCurrency(rate)
        if isValidRate(rounded, isVatPayer: isVatPayer) {
            return rounded
        }
        return defaultRate(isVatPayer: isVatPayer)
    }

    static func isValidRate(_ rate: Decimal, isVatPayer: Bool) -> Bool {
        let rounded = ProductService.roundCurrency(rate)
        return allowedRates(isVatPayer: isVatPayer).contains {
            ProductService.roundCurrency($0) == rounded
        }
    }

    static func label(for rate: Decimal) -> String {
        InventoryFormatting.vatPercent(rate)
    }
}

extension Company {
    var isVatPayer: Bool {
        platitorTva
    }
}
