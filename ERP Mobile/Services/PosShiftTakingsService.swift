import Foundation
import Supabase

struct PosShiftTotals: Equatable, Sendable {
    var cash: Decimal = 0
    var card: Decimal = 0
    var glovo: Decimal = 0
    var bolt: Decimal = 0
    var wolt: Decimal = 0

    static let zero = PosShiftTotals()
}

enum PosShiftTakingsService {
    private static let client = SupabaseManager.client

    static func record(locationId: UUID, channel: String, amount: Decimal) async throws {
        struct Params: Encodable {
            let locationId: UUID
            let channel: String
            let amount: String
            enum CodingKeys: String, CodingKey {
                case locationId = "p_work_location_id"
                case channel = "p_channel"
                case amount = "p_amount"
            }
        }
        try await client
            .rpc(
                "pos_record_taking",
                params: Params(locationId: locationId, channel: channel, amount: plain(amount))
            )
            .execute()
    }

    static func open(locationId: UUID) async throws -> PosShiftTotals {
        struct Params: Encodable {
            let locationId: UUID
            enum CodingKeys: String, CodingKey {
                case locationId = "p_work_location_id"
            }
        }
        struct Row: Decodable {
            let cash: SupabaseDecimal
            let card: SupabaseDecimal
            let glovo: SupabaseDecimal
            let bolt: SupabaseDecimal
            let wolt: SupabaseDecimal
        }
        let rows: [Row] = try await client
            .rpc("pos_open_takings", params: Params(locationId: locationId))
            .execute()
            .value
        guard let row = rows.first else { return .zero }
        return PosShiftTotals(
            cash: row.cash.wrappedValue,
            card: row.card.wrappedValue,
            glovo: row.glovo.wrappedValue,
            bolt: row.bolt.wrappedValue,
            wolt: row.wolt.wrappedValue
        )
    }

    static func closeZ(locationId: UUID) async throws {
        struct Params: Encodable {
            let locationId: UUID
            enum CodingKeys: String, CodingKey {
                case locationId = "p_work_location_id"
            }
        }
        try await client
            .rpc("pos_close_takings_z", params: Params(locationId: locationId))
            .execute()
    }

    private static func plain(_ value: Decimal) -> String {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}
