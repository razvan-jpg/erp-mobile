import Foundation
import Supabase

enum StockSheetService {
    private static let client = SupabaseManager.client

    static func fetchListRows(
        companyId: UUID,
        warehouseIds: [UUID] = [],
        asOf: Date = Date()
    ) async throws -> [StockSheetListRow] {
        let products = try await ProductService.fetchProducts(companyId: companyId, inStockSheet: true)
        let stocks = try await InventoryService.fetchStockRows(companyId: companyId)
        let quantityByProduct = Dictionary(uniqueKeysWithValues: stocks.map { ($0.productId, $0.cantitate) })
        let movements = try await InventoryService.fetchProductMovements(
            companyId: companyId,
            productIds: products.map(\.id)
        )
        let movementsByProduct = Dictionary(grouping: movements, by: \.productId)
        let useLedger = !warehouseIds.isEmpty || !Calendar.current.isDateInToday(asOf)

        return products.map { product in
            let scoped = scopedMovements(movementsByProduct[product.id] ?? [], warehouseIds: warehouseIds, asOf: asOf)
            let ledger = StockSheetLedgerBuilder.build(movements: scoped)
            let quantity = useLedger ? ledger.finalQuantity : (quantityByProduct[product.id] ?? ledger.finalQuantity)
            let pretMediu = ledger.weightedAverageCost
            let valoare = (pretMediu ?? 0) * quantity
            return StockSheetListRow(
                product: product,
                cantitate: quantity,
                pretMediu: pretMediu,
                valoare: valoare
            )
        }
        .sorted {
            $0.product.denumire.localizedStandardCompare($1.product.denumire) == .orderedAscending
        }
    }

    static func fetchSnapshot(
        companyId: UUID,
        company: Company?,
        product: Product,
        locationName: String,
        warehouseIds: [UUID] = [],
        asOf: Date = Date()
    ) async throws -> StockSheetSnapshot {
        let stocks = try await InventoryService.fetchStockRows(companyId: companyId)
        let quantity = stocks.first(where: { $0.productId == product.id })?.cantitate
        let movements = try await InventoryService.fetchProductMovements(
            companyId: companyId,
            productId: product.id
        )
        let scoped = scopedMovements(movements, warehouseIds: warehouseIds, asOf: asOf)
        let ledger = StockSheetLedgerBuilder.build(movements: scoped)
        let useLedger = !warehouseIds.isEmpty || !Calendar.current.isDateInToday(asOf)
        let cantitate = useLedger ? ledger.finalQuantity : (quantity ?? ledger.finalQuantity)
        let pretMediu = ledger.weightedAverageCost
        return StockSheetSnapshot(
            company: company,
            product: product,
            entries: ledger.entries,
            cantitate: cantitate,
            pretMediu: pretMediu,
            valoare: (pretMediu ?? 0) * cantitate,
            generatedAt: Date(),
            locationName: locationName,
            asOf: asOf
        )
    }

    private static func scopedMovements(
        _ movements: [StockMovementDetailRow],
        warehouseIds: [UUID],
        asOf: Date
    ) -> [StockMovementDetailRow] {
        let end = Calendar.current.startOfDay(for: asOf).addingTimeInterval(86_399)
        let ids = Set(warehouseIds)
        return movements.filter { movement in
            if movement.transactionDate > end { return false }
            if ids.isEmpty { return true }
            guard let warehouseId = movement.warehouseId else { return false }
            return ids.contains(warehouseId)
        }
    }

    static func fetchInitialStockDraft(companyId: UUID) async throws -> InitialStockDraftSnapshot {
        let products = try await ProductService.fetchProducts(companyId: companyId, inStockSheet: true)
        let stocks = try await InventoryService.fetchStockRows(companyId: companyId)
        let quantityByProduct = Dictionary(uniqueKeysWithValues: stocks.map { ($0.productId, $0.cantitate) })
        let movements = try await InventoryService.fetchProductMovements(
            companyId: companyId,
            productIds: products.map(\.id)
        )
        let initialByProduct = Dictionary(
            movements
                .filter { $0.sursa == StockMovementSource.initialStock.rawValue && $0.tip == .intrare }
                .map { ($0.productId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let lines = products.map { product -> InitialStockDraftLine in
            let initial = initialByProduct[product.id]
            return InitialStockDraftLine(
                product: product,
                quantityText: initial.map { SupplierFormatting.stockQuantityString($0.cantitate) } ?? "",
                unitPriceText: initial.flatMap { movement -> String? in
                    let price = movement.unitPurchasePrice
                    return price == 0 && movement.pretUnitar == nil ? nil : SupplierFormatting.amountString(price)
                } ?? "",
                currentStock: quantityByProduct[product.id] ?? 0
            )
        }

        let transactionDate = initialByProduct.values
            .map(\.transactionDate)
            .filter { $0 != .distantPast }
            .min()

        return InitialStockDraftSnapshot(lines: lines, transactionDate: transactionDate)
    }

    static func saveInitialStock(
        companyId: UUID,
        transactionDate: Date,
        lines: [InitialStockLinePayload]
    ) async throws -> Int {
        let params = UpsertInitialStockParams(
            pCompanyId: companyId,
            pDataTranzactie: dateString(transactionDate),
            pLines: lines
        )
        let result: Int = try await client
            .rpc("upsert_initial_stock_lines", params: params)
            .execute()
            .value
        return result
    }

    static func mapInitialStockError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("INITIAL_STOCK_FORBIDDEN") {
            return L10n.tr("stock_sheet.initial.forbidden")
        }
        if text.contains("INITIAL_STOCK_INVALID_QTY") {
            return L10n.tr("stock_sheet.initial.invalid_qty_rpc")
        }
        return text
    }

    static func fetchZSheets(companyId: UUID, locationId: UUID?, date: Date) async throws -> [ZStockSheetRow] {
        let day = dateString(date)
        if let locationId {
            return try await client
                .from("z_stock_sheets")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("sheet_date", value: day)
                .eq("work_location_id", value: locationId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
        }
        return try await client
            .from("z_stock_sheets")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("sheet_date", value: day)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchZSheetLines(sheetId: UUID) async throws -> [ZStockSheetLine] {
        try await client
            .from("z_stock_sheet_lines")
            .select()
            .eq("sheet_id", value: sheetId.uuidString)
            .order("nr_crt", ascending: true)
            .execute()
            .value
    }

    private static func dateString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }
}

private struct UpsertInitialStockParams: Encodable {
    let pCompanyId: UUID
    let pDataTranzactie: String
    let pLines: [InitialStockLinePayload]

    enum CodingKeys: String, CodingKey {
        case pCompanyId = "p_company_id"
        case pDataTranzactie = "p_data_tranzactie"
        case pLines = "p_lines"
    }
}
