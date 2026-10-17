import Foundation
import Supabase

enum ConsumptionVoucherService {
    private static let client = SupabaseManager.client

    private static let voucherSelect = """
        id, company_id, numar, data_bon, shift_no, warehouse_id, motiv, status, created_by, \
        warehouse:company_warehouses!consumption_vouchers_warehouse_id_fkey(id, denumire, cod, work_location_id)
        """

    private struct LineParam: Encodable {
        let productId: UUID
        let cantitate: Double

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case cantitate
        }
    }

    private struct PostParams: Encodable {
        let pCompanyId: UUID
        let pDataBon: String
        let pWarehouseId: UUID
        let pMotiv: String
        let pLines: [LineParam]
        let pShiftNo: Int

        enum CodingKeys: String, CodingKey {
            case pCompanyId = "p_company_id"
            case pDataBon = "p_data_bon"
            case pWarehouseId = "p_warehouse_id"
            case pMotiv = "p_motiv"
            case pLines = "p_lines"
            case pShiftNo = "p_shift_no"
        }
    }

    private struct UpdateParams: Encodable {
        let pVoucherId: UUID
        let pDataBon: String
        let pWarehouseId: UUID
        let pMotiv: String
        let pLines: [LineParam]
        let pShiftNo: Int

        enum CodingKeys: String, CodingKey {
            case pVoucherId = "p_voucher_id"
            case pDataBon = "p_data_bon"
            case pWarehouseId = "p_warehouse_id"
            case pMotiv = "p_motiv"
            case pLines = "p_lines"
            case pShiftNo = "p_shift_no"
        }
    }

    private struct IdParams: Encodable {
        let pVoucherId: UUID

        enum CodingKeys: String, CodingKey {
            case pVoucherId = "p_voucher_id"
        }
    }

    private struct ApproveParams: Encodable {
        let pVoucherId: UUID
        let pApproveAll: Bool
        let pLineIds: [UUID]

        enum CodingKeys: String, CodingKey {
            case pVoucherId = "p_voucher_id"
            case pApproveAll = "p_approve_all"
            case pLineIds = "p_line_ids"
        }
    }

    static func fetchVouchers(companyId: UUID) async throws -> [ConsumptionVoucher] {
        try await client
            .from("consumption_vouchers")
            .select(voucherSelect)
            .eq("company_id", value: companyId.uuidString)
            .order("data_bon", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchLines(voucherId: UUID) async throws -> [ConsumptionVoucherLine] {
        try await client
            .from("consumption_voucher_lines")
            .select("id, voucher_id, product_id, numar_linie, cantitate, unitate_masura, aprobat, product:products(id, denumire, cod, cod_bare, unitate_masura, tip, cantitate_minima)")
            .eq("voucher_id", value: voucherId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
    }

    static func post(
        companyId: UUID,
        dataBon: Date,
        shiftNo: Int,
        warehouseId: UUID,
        motiv: String,
        lines: [(productId: UUID, quantity: Decimal)]
    ) async throws -> UUID {
        let payload = PostParams(
            pCompanyId: companyId,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pWarehouseId: warehouseId,
            pMotiv: motiv,
            pLines: lines.map {
                LineParam(productId: $0.productId, cantitate: NSDecimalNumber(decimal: $0.quantity).doubleValue)
            },
            pShiftNo: shiftNo
        )
        do {
            let id: UUID = try await client.rpc("post_consumption_voucher", params: payload).execute().value
            return id
        } catch {
            throw ConsumptionVoucherError.map(error)
        }
    }

    static func update(
        id: UUID,
        dataBon: Date,
        shiftNo: Int,
        warehouseId: UUID,
        motiv: String,
        lines: [(productId: UUID, quantity: Decimal)]
    ) async throws {
        let payload = UpdateParams(
            pVoucherId: id,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pWarehouseId: warehouseId,
            pMotiv: motiv,
            pLines: lines.map {
                LineParam(productId: $0.productId, cantitate: NSDecimalNumber(decimal: $0.quantity).doubleValue)
            },
            pShiftNo: shiftNo
        )
        do {
            try await client.rpc("update_consumption_voucher", params: payload).execute()
        } catch {
            throw ConsumptionVoucherError.map(error)
        }
    }

    static func delete(id: UUID) async throws {
        do {
            try await client.rpc("delete_consumption_voucher", params: IdParams(pVoucherId: id)).execute()
        } catch {
            throw ConsumptionVoucherError.map(error)
        }
    }

    static func approveAll(id: UUID) async throws {
        try await approve(id: id, all: true, lineIds: [])
    }

    static func approve(id: UUID, lineIds: [UUID]) async throws {
        try await approve(id: id, all: false, lineIds: lineIds)
    }

    private static func approve(id: UUID, all: Bool, lineIds: [UUID]) async throws {
        do {
            try await client
                .rpc("approve_consumption_voucher", params: ApproveParams(pVoucherId: id, pApproveAll: all, pLineIds: lineIds))
                .execute()
        } catch {
            throw ConsumptionVoucherError.map(error)
        }
    }

    static func reopen(id: UUID) async throws {
        do {
            try await client.rpc("reopen_consumption_voucher", params: IdParams(pVoucherId: id)).execute()
        } catch {
            throw ConsumptionVoucherError.map(error)
        }
    }
}
