import Foundation
import Supabase

enum ProductionVoucherService {
    private static let client = SupabaseManager.client

    private static let voucherSelect = """
        id, company_id, numar, data_bon, warehouse_id, product_id, cantitate, unitate_masura, observatii, created_at,
        product:products!production_vouchers_product_id_fkey(id, denumire, cod, cod_bare, unitate_masura, tip, cantitate_minima),
        warehouse:company_warehouses!production_vouchers_warehouse_id_fkey(id, denumire, cod)
        """

    private struct PostParams: Encodable {
        let pCompanyId: UUID
        let pDataBon: String
        let pWarehouseId: UUID
        let pProductId: UUID
        let pCantitate: Double
        let pObservatii: String?

        enum CodingKeys: String, CodingKey {
            case pCompanyId = "p_company_id"
            case pDataBon = "p_data_bon"
            case pWarehouseId = "p_warehouse_id"
            case pProductId = "p_product_id"
            case pCantitate = "p_cantitate"
            case pObservatii = "p_observatii"
        }
    }

    private struct UpdateParams: Encodable {
        let pVoucherId: UUID
        let pDataBon: String
        let pWarehouseId: UUID
        let pProductId: UUID
        let pCantitate: Double
        let pObservatii: String?

        enum CodingKeys: String, CodingKey {
            case pVoucherId = "p_voucher_id"
            case pDataBon = "p_data_bon"
            case pWarehouseId = "p_warehouse_id"
            case pProductId = "p_product_id"
            case pCantitate = "p_cantitate"
            case pObservatii = "p_observatii"
        }
    }

    private struct DeleteParams: Encodable {
        let pVoucherId: UUID

        enum CodingKeys: String, CodingKey {
            case pVoucherId = "p_voucher_id"
        }
    }

    static func fetchVouchers(companyId: UUID) async throws -> [ProductionVoucher] {
        try await client
            .from("production_vouchers")
            .select(voucherSelect)
            .eq("company_id", value: companyId.uuidString)
            .order("data_bon", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchVoucher(id: UUID) async throws -> ProductionVoucher {
        let rows: [ProductionVoucher] = try await client
            .from("production_vouchers")
            .select(voucherSelect)
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let voucher = rows.first else { throw ServiceError.invalidResponse }
        return voucher
    }

    static func fetchLines(voucherId: UUID) async throws -> [ProductionVoucherLine] {
        try await client
            .from("production_voucher_lines")
            .select("""
                id, voucher_id, product_id, numar_linie, cantitate, unitate_masura,
                product:products(id, denumire, cod, cod_bare, unitate_masura, tip, cantitate_minima)
                """)
            .eq("voucher_id", value: voucherId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
    }

    static func fetchFinishedGoodsWithRecipe(companyId: UUID) async throws -> [Product] {
        try await ProductService.fetchProducts(companyId: companyId, hasRecipe: true)
            .filter { $0.isActive && $0.tip == .produsFinit }
            .sorted { $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending }
    }

    static func postVoucher(
        companyId: UUID,
        dataBon: Date,
        warehouseId: UUID,
        productId: UUID,
        cantitate: Decimal,
        observatii: String?
    ) async throws -> UUID {
        guard cantitate > 0 else { throw ProductionVoucherError.invalidQuantity }

        let payload = PostParams(
            pCompanyId: companyId,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pWarehouseId: warehouseId,
            pProductId: productId,
            pCantitate: NSDecimalNumber(decimal: cantitate).doubleValue,
            pObservatii: observatii
        )
        do {
            return try await client
                .rpc("post_production_voucher", params: payload)
                .execute()
                .value
        } catch {
            throw ProductionVoucherError.map(error)
        }
    }

    static func updateVoucher(
        id: UUID,
        dataBon: Date,
        warehouseId: UUID,
        productId: UUID,
        cantitate: Decimal,
        observatii: String?
    ) async throws {
        guard cantitate > 0 else { throw ProductionVoucherError.invalidQuantity }
        let payload = UpdateParams(
            pVoucherId: id,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pWarehouseId: warehouseId,
            pProductId: productId,
            pCantitate: NSDecimalNumber(decimal: cantitate).doubleValue,
            pObservatii: observatii
        )
        do {
            try await client
                .rpc("update_production_voucher", params: payload)
                .execute()
        } catch {
            throw ProductionVoucherError.map(error)
        }
    }

    static func deleteVoucher(id: UUID) async throws {
        do {
            try await client
                .rpc("delete_production_voucher", params: DeleteParams(pVoucherId: id))
                .execute()
        } catch {
            throw ProductionVoucherError.map(error)
        }
    }
}
