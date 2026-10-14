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
    let locationName: String
    let asOf: Date
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
    let locationName: String
    let asOf: Date
    let warehouseIds: [UUID]
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

struct ZStockSheetRow: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let workLocationId: UUID
    let series: String
    let numar: Int
    let sheetDate: String
    let shiftNo: Int
    let zNumber: String
    let glovo: Decimal
    let bolt: Decimal
    let wolt: Decimal
    let totalVanzare: Decimal
    let plataCard: Decimal
    let plataModerna: Decimal
    let numerar: Decimal
    let baniPredati: Decimal

    enum CodingKeys: String, CodingKey {
        case id
        case workLocationId = "work_location_id"
        case series
        case numar
        case sheetDate = "sheet_date"
        case shiftNo = "shift_no"
        case zNumber = "z_number"
        case glovo
        case bolt
        case wolt
        case totalVanzare = "total_vanzare"
        case plataCard = "plata_card"
        case plataModerna = "plata_moderna"
        case numerar
        case baniPredati = "bani_predati"
    }

    var title: String {
        let parts = sheetDate.split(separator: "-")
        let shown = parts.count == 3 ? "\(parts[2]).\(parts[1]).\(parts[0])" : sheetDate
        let z = zNumber.isEmpty ? "—" : zNumber
        return "\(shown) · Tura \(shiftNo) (Z \(z))"
    }

    var documentNumber: String { "\(series) \(numar)" }
}

struct ZStockSheetLine: Identifiable, Decodable, Hashable, Sendable {
    let id: UUID
    let category: String
    let nrCrt: Int
    let denumire: String
    let unitateMasura: String
    let openingQty: Decimal
    let inflowQty: Decimal
    let transferOutQty: Decimal
    let recipeOutQty: Decimal
    let saleStoreQty: Decimal
    let saleOnlineQty: Decimal
    let priceStore: Decimal
    let priceOnline: Decimal
    let valueStore: Decimal
    let valueOnline: Decimal
    let profit: Decimal
    let closingQty: Decimal
    let mismatch: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case nrCrt = "nr_crt"
        case denumire
        case unitateMasura = "unitate_masura"
        case openingQty = "opening_qty"
        case inflowQty = "inflow_qty"
        case transferOutQty = "transfer_out_qty"
        case recipeOutQty = "recipe_out_qty"
        case saleStoreQty = "sale_store_qty"
        case saleOnlineQty = "sale_online_qty"
        case priceStore = "price_store"
        case priceOnline = "price_online"
        case valueStore = "value_store"
        case valueOnline = "value_online"
        case profit
        case closingQty = "closing_qty"
        case mismatch
    }

    var categoryTitle: String {
        switch category {
        case "finite": return "Produse finite (Shaorma, Farfurii & Box, Sandwich & Chifle, Meniuri)"
        case "drinks": return "Băuturi"
        default: return "Materii prime și ambalaje"
        }
    }
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
