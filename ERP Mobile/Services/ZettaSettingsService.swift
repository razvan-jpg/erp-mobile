import Foundation
import Supabase

private struct ZettaSettingsUpsert: Encodable {
    let companyId: UUID
    let settings: ZettaSettingsPayload

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case settings
    }
}

enum ZettaSettingsService {
    private static let client = SupabaseManager.client

    static func fetchSettings(companyId: UUID) async throws -> CompanyZettaSettings {
        let rows: [CompanyZettaSettings] = try await client
            .from("company_zetta_settings")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .limit(1)
            .execute()
            .value

        if let existing = rows.first {
            return existing
        }
        return .defaults(companyId: companyId)
    }

    static func saveSettings(_ settings: CompanyZettaSettings) async throws -> CompanyZettaSettings {
        let payload = ZettaSettingsUpsert(companyId: settings.companyId, settings: settings.payload)
        let rows: [CompanyZettaSettings] = try await client
            .from("company_zetta_settings")
            .upsert(payload, onConflict: "company_id")
            .select()
            .execute()
            .value
        guard let saved = rows.first else { throw ServiceError.invalidResponse }
        return saved
    }

    /// Asigură depozit distinct pentru fiecare punct de lucru fără depozit asociat.
    static func ensureWarehousesForWorkLocations(companyId: UUID) async throws -> Int {
        let locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
        let warehouses = try await WarehouseService.fetchWarehouses(companyId: companyId)
        var created = 0
        for location in locations {
            if warehouses.contains(where: { $0.workLocationId == location.id }) {
                continue
            }
            try await WorkLocationService.ensureWarehouse(for: location)
            created += 1
        }
        return created
    }
}
