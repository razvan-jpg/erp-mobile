import Foundation

enum InvoiceLineVAT {
    static func vatRate(amount: Decimal, lineTotal: Decimal) -> Decimal {
        guard lineTotal > 0, amount > 0 else { return .zero }
        var percent = amount / lineTotal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &percent, 2, .plain)
        return rounded
    }

    static func vatAmount(lineTotal: Decimal, rate: Decimal) -> Decimal {
        guard lineTotal > 0, rate > 0 else { return .zero }
        return SupplierFormatting.roundAmount(lineTotal * rate / 100)
    }
}
