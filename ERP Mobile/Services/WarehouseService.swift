import Foundation
import Supabase

private struct WarehouseInsert: Encodable {
    let companyId: UUID
    let cod: String
    let denumire: String
    let warehouseType: String
    let workLocationId: UUID?
    let partnerSupplierId: UUID?
    let partnerClientId: UUID?
    let isCustody: Bool
    let allowsStockReservation: Bool
    let isLohn: Bool
    let managerName: String?
    let adresa: String?
    let additionalInfo: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case cod, denumire, adresa
        case companyId = "company_id"
        case warehouseType = "warehouse_type"
        case workLocationId = "work_location_id"
        case partnerSupplierId = "partner_supplier_id"
        case partnerClientId = "partner_client_id"
        case isCustody = "is_custody"
        case allowsStockReservation = "allows_stock_reservation"
        case isLohn = "is_lohn"
        case managerName = "manager_name"
        case additionalInfo = "additional_info"
        case isActive = "is_active"
    }

    init(from warehouse: CompanyWarehouse) {
        companyId = warehouse.companyId
        cod = warehouse.cod
        denumire = warehouse.denumire
        warehouseType = warehouse.warehouseType.rawValue
        workLocationId = warehouse.workLocationId
        partnerSupplierId = warehouse.partnerSupplierId
        partnerClientId = warehouse.partnerClientId
        isCustody = warehouse.isCustody
        allowsStockReservation = warehouse.allowsStockReservation
        isLohn = warehouse.isLohn
        managerName = warehouse.managerName
        adresa = warehouse.adresa
        additionalInfo = warehouse.additionalInfo
        isActive = warehouse.isActive
    }
}

private struct WarehouseUpdate: Encodable {
    let cod: String
    let denumire: String
    let warehouseType: String
    let workLocationId: UUID?
    let partnerSupplierId: UUID?
    let partnerClientId: UUID?
    let isCustody: Bool
    let allowsStockReservation: Bool
    let isLohn: Bool
    let managerName: String?
    let adresa: String?
    let additionalInfo: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case cod, denumire, adresa
        case warehouseType = "warehouse_type"
        case workLocationId = "work_location_id"
        case partnerSupplierId = "partner_supplier_id"
        case partnerClientId = "partner_client_id"
        case isCustody = "is_custody"
        case allowsStockReservation = "allows_stock_reservation"
        case isLohn = "is_lohn"
        case managerName = "manager_name"
        case additionalInfo = "additional_info"
        case isActive = "is_active"
    }

    init(from warehouse: CompanyWarehouse) {
        cod = warehouse.cod
        denumire = warehouse.denumire
        warehouseType = warehouse.warehouseType.rawValue
        workLocationId = warehouse.workLocationId
        partnerSupplierId = warehouse.partnerSupplierId
        partnerClientId = warehouse.partnerClientId
        isCustody = warehouse.isCustody
        allowsStockReservation = warehouse.allowsStockReservation
        isLohn = warehouse.isLohn
        managerName = warehouse.managerName
        adresa = warehouse.adresa
        additionalInfo = warehouse.additionalInfo
        isActive = warehouse.isActive
    }
}

enum WarehouseService {
    private static let client = SupabaseManager.client

    private static let selectQuery = """
        *,
        work_location:company_work_locations(denumire),
        partner_supplier:suppliers(denumire),
        partner_client:clients(denumire)
        """

    static func fetchWarehouses(companyId: UUID) async throws -> [CompanyWarehouse] {
        try await client
            .from("company_warehouses")
            .select(selectQuery)
            .eq("company_id", value: companyId.uuidString)
            .order("cod", ascending: true)
            .execute()
            .value
    }

    static func suggestNextCod(companyId: UUID) async throws -> String {
        let warehouses = try await fetchWarehouses(companyId: companyId)
        let maxValue = warehouses.compactMap { Int($0.cod) }.max() ?? 0
        return String(format: "%07d", maxValue + 1)
    }

    static func createWarehouse(_ warehouse: CompanyWarehouse) async throws -> CompanyWarehouse {
        let payload = WarehouseInsert(from: warehouse)
        let rows: [CompanyWarehouse] = try await client
            .from("company_warehouses")
            .insert(payload)
            .select(selectQuery)
            .execute()
            .value
        guard let created = rows.first else { throw ServiceError.invalidResponse }
        return created
    }

    static func updateWarehouse(_ warehouse: CompanyWarehouse) async throws -> CompanyWarehouse {
        let payload = WarehouseUpdate(from: warehouse)
        let rows: [CompanyWarehouse] = try await client
            .from("company_warehouses")
            .update(payload)
            .eq("id", value: warehouse.id.uuidString)
            .select(selectQuery)
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func deleteWarehouse(id: UUID) async throws {
        try await client
            .from("company_warehouses")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
