import Foundation

struct StockSheetListRow: Identifiable, Hashable, Sendable {
    let product: Product
    let cantitate: Decimal
    let pretMediu: Decimal?
    let valoare: Decimal

    var id: UUID { product.id }

    var unit: String { product.unitateMasura }
}

struct StockSheetLedgerEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let nrCrt: Int
    let dataTranzactie: Date
    let numarDocument: String
    let cantitateIntrare: Decimal
    let valoareIntrare: Decimal
    let cantitateIesire: Decimal
    let valoareIesire: Decimal
    let stocCantitate: Decimal
    let stocValoare: Decimal
}

struct StockSheetLedgerResult: Sendable {
    let entries: [StockSheetLedgerEntry]
    let weightedAverageCost: Decimal?
    let finalQuantity: Decimal
    let finalValue: Decimal
}

struct StockSheetSnapshot: Sendable {
    let company: Company?
    let product: Product
    let entries: [StockSheetLedgerEntry]
    let cantitate: Decimal
    let pretMediu: Decimal?
    let valoare: Decimal
    let generatedAt: Date
}

struct StockSheetListingSnapshot: Sendable {
    let company: Company?
    let rows: [StockSheetListRow]
    let generatedAt: Date

    var totalValue: Decimal {
        rows.reduce(0) { $0 + $1.valoare }
    }
}

struct StockSheetDetailContext: Identifiable, Hashable {
    let row: StockSheetListRow
    var id: UUID { row.id }
}

struct InitialStockDraftLine: Identifiable, Hashable, Sendable {
    let product: Product
    var quantityText: String
    var unitPriceText: String
    let currentStock: Decimal

    var id: UUID { product.id }

    var parsedQuantity: Decimal? {
        Self.parseAmount(quantityText)
    }

    var parsedUnitPrice: Decimal? {
        Self.parseAmount(unitPriceText)
    }

    var lineValue: Decimal? {
        guard let quantity = parsedQuantity, let price = parsedUnitPrice else { return nil }
        return quantity * price
    }

    private static func parseAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return SupplierFormatting.parseAmount(
            trimmed,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }
}

struct InitialStockDraftSnapshot: Sendable {
    let lines: [InitialStockDraftLine]
    let transactionDate: Date?
}

struct InitialStockLinePayload: Encodable, Sendable {
    let productId: UUID
    let cantitate: Decimal
    let pretUnitar: Decimal

    enum CodingKeys: String, CodingKey {
        case cantitate
        case productId = "product_id"
        case pretUnitar = "pret_unitar"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productId, forKey: .productId)
        try container.encode(NSDecimalNumber(decimal: cantitate).doubleValue, forKey: .cantitate)
        try container.encode(NSDecimalNumber(decimal: pretUnitar).doubleValue, forKey: .pretUnitar)
    }
}
