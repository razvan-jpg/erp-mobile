import Foundation
import Supabase

enum PhysicalInventoryService {
    private static let client = SupabaseManager.client

    private struct InventoryInsert: Encodable {
        let companyId: UUID
        let dataInventar: String
        let observatii: String?
        let createdBy: UUID?
        let warehouseId: UUID?

        enum CodingKeys: String, CodingKey {
            case observatii
            case companyId = "company_id"
            case dataInventar = "data_inventar"
            case createdBy = "created_by"
            case warehouseId = "warehouse_id"
        }
    }

    private struct UpsertLineParams: Encodable {
        let pInventoryId: UUID
        let pProductId: UUID
        let pCantitateNumarata: Double
        let pObservatii: String?

        enum CodingKeys: String, CodingKey {
            case pObservatii = "p_observatii"
            case pInventoryId = "p_inventory_id"
            case pProductId = "p_product_id"
            case pCantitateNumarata = "p_cantitate_numarata"
        }
    }

    private struct InventoryIdParams: Encodable {
        let pInventoryId: UUID

        enum CodingKeys: String, CodingKey {
            case pInventoryId = "p_inventory_id"
        }
    }

    static func fetchInventories(companyId: UUID) async throws -> [PhysicalInventory] {
        try await client
            .from("physical_inventories")
            .select("id, company_id, numar_inventar, data_inventar, status, observatii, warehouse_id, created_at, updated_at, finalized_at")
            .eq("company_id", value: companyId.uuidString)
            .order("data_inventar", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchInventory(id: UUID) async throws -> PhysicalInventory {
        let rows: [PhysicalInventory] = try await client
            .from("physical_inventories")
            .select("id, company_id, numar_inventar, data_inventar, status, observatii, warehouse_id, created_at, updated_at, finalized_at")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let inventory = rows.first else { throw PhysicalInventoryError.notFound }
        return inventory
    }

    static func fetchLines(inventoryId: UUID) async throws -> [PhysicalInventoryLine] {
        let rows: [PhysicalInventoryLine] = try await client
            .from("physical_inventory_lines")
            .select("""
                id, inventory_id, company_id, product_id, stoc_scriptic, cantitate_numarata,
                unitate_masura, observatii,
                product:products(id, denumire, cod, cod_bare, unitate_masura)
                """)
            .eq("inventory_id", value: inventoryId.uuidString)
            .execute()
            .value
        return rows.sorted {
            ($0.product?.denumire ?? "").localizedStandardCompare($1.product?.denumire ?? "") == .orderedAscending
        }
    }

    static func createInventory(
        companyId: UUID,
        dataInventar: Date,
        observatii: String?,
        createdBy: UUID?,
        warehouseId: UUID?,
        populateFromStock: Bool
    ) async throws -> PhysicalInventory {
        let payload = InventoryInsert(
            companyId: companyId,
            dataInventar: dateString(dataInventar),
            observatii: emptyToNil(observatii),
            createdBy: createdBy,
            warehouseId: warehouseId
        )
        let rows: [PhysicalInventory] = try await client
            .from("physical_inventories")
            .insert(payload)
            .select("id, company_id, numar_inventar, data_inventar, status, observatii, warehouse_id, created_at, updated_at, finalized_at")
            .execute()
            .value
        guard let inventory = rows.first else { throw ServiceError.invalidResponse }

        if populateFromStock {
            _ = try await loadProductsFromStock(inventoryId: inventory.id)
        }
        return inventory
    }

    static func loadProductsFromStock(inventoryId: UUID) async throws -> Int {
        do {
            let result: Int = try await client
                .rpc("populate_physical_inventory_from_stock", params: InventoryIdParams(pInventoryId: inventoryId))
                .execute()
                .value
            return result
        } catch {
            throw PhysicalInventoryError.map(error)
        }
    }

    static func upsertLine(
        inventoryId: UUID,
        productId: UUID,
        cantitateNumarata: Decimal,
        observatii: String? = nil
    ) async throws -> PhysicalInventoryLine {
        let params = UpsertLineParams(
            pInventoryId: inventoryId,
            pProductId: productId,
            pCantitateNumarata: doubleAmount(cantitateNumarata),
            pObservatii: emptyToNil(observatii)
        )

        do {
            return try await client
                .rpc("upsert_physical_inventory_line", params: params)
                .execute()
                .value
        } catch {
            throw PhysicalInventoryError.map(error)
        }
    }

    static func finalize(inventoryId: UUID) async throws {
        do {
            try await client
                .rpc("finalize_physical_inventory", params: InventoryIdParams(pInventoryId: inventoryId))
                .execute()
        } catch {
            throw PhysicalInventoryError.map(error)
        }
    }

    static func deleteInventory(id: UUID) async throws {
        do {
            try await client
                .rpc("delete_physical_inventory", params: InventoryIdParams(pInventoryId: id))
                .execute()
        } catch {
            throw PhysicalInventoryError.map(error)
        }
    }

    static func fetchDifferenceReports(companyId: UUID) async throws -> [InventoryDifferenceReport] {
        try await client
            .from("inventory_difference_reports")
            .select("id, company_id, inventory_id, warehouse_id, numar, data_ora")
            .eq("company_id", value: companyId.uuidString)
            .order("data_ora", ascending: false)
            .execute()
            .value
    }

    static func fetchDifferenceReportLines(reportId: UUID) async throws -> [InventoryDifferenceReportLine] {
        try await client
            .from("inventory_difference_report_lines")
            .select("id, report_id, product_id, denumire, unitate_masura, stoc_scriptic, cantitate_faptica, diferenta")
            .eq("report_id", value: reportId.uuidString)
            .execute()
            .value
    }

    static func deleteLine(id: UUID) async throws {
        try await client
            .from("physical_inventory_lines")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    private static func dateString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private static func doubleAmount(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private static func emptyToNil(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
