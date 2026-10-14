import Foundation
import Supabase

enum PosStockService {
    private static let client = SupabaseManager.client

    struct Item: Encodable {
        let productId: UUID
        let cantitate: Double
        let canal: String

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case cantitate
            case canal
        }
    }

    private struct Params: Encodable {
        let workLocationId: UUID
        let receiptNumber: String
        let items: [Item]

        enum CodingKeys: String, CodingKey {
            case workLocationId = "p_work_location_id"
            case receiptNumber = "p_receipt_number"
            case items = "p_items"
        }
    }

    static func closeShiftProduction(locationId: UUID) async throws {
        try await client
            .rpc("pos_close_shift_production", params: LocationParams(locationId: locationId))
            .execute()
    }

    static func createStockSheet(locationId: UUID, zNumber: String) async throws {
        try await client
            .rpc(
                "pos_create_z_stock_sheet",
                params: SheetParams(locationId: locationId, zNumber: zNumber)
            )
            .execute()
    }

    static func discharge(locationId: UUID, receiptNumber: String, items: [Item]) async throws {
        let number = receiptNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty, !items.isEmpty else { return }
        try await client
            .rpc(
                "pos_discharge_fiscal_receipt",
                params: Params(workLocationId: locationId, receiptNumber: number, items: items)
            )
            .execute()
    }

    private struct LocationParams: Encodable {
        let locationId: UUID

        enum CodingKeys: String, CodingKey {
            case locationId = "p_work_location_id"
        }
    }

    private struct SheetParams: Encodable {
        let locationId: UUID
        let zNumber: String

        enum CodingKeys: String, CodingKey {
            case locationId = "p_work_location_id"
            case zNumber = "p_z_number"
        }
    }
}
