import Foundation
import Supabase

private struct CompanyStockSettingsRow: Decodable {
    let fractionDigits: Int

    enum CodingKeys: String, CodingKey {
        case fractionDigits = "fraction_digits"
    }
}

private struct CompanyStockSettingsUpsert: Encodable {
    let companyId: UUID
    let fractionDigits: Int

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case fractionDigits = "fraction_digits"
    }
}

enum CompanyStockSettingsService {
    private static let client = SupabaseManager.client

    static func fetchFractionDigits(companyId: UUID) async throws -> Int? {
        let rows: [CompanyStockSettingsRow] = try await client
            .from("company_stock_settings")
            .select("fraction_digits")
            .eq("company_id", value: companyId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first?.fractionDigits
    }

    static func saveFractionDigits(companyId: UUID, digits: Int) async throws {
        let payload = CompanyStockSettingsUpsert(
            companyId: companyId,
            fractionDigits: StockQuantityFormat.normalized(digits)
        )
        try await client
            .from("company_stock_settings")
            .upsert(payload, onConflict: "company_id")
            .execute()
    }
}
