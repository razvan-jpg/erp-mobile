import Foundation
import Supabase

enum CompanyEFacturaSettingsService {
    private static let client = SupabaseManager.client

    static func fetch(companyId: UUID) async throws -> CompanyEFacturaSettings? {
        let rows: [CompanyEFacturaSettings] = try await client
            .from("company_efactura_settings")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func upsert(_ settings: CompanyEFacturaSettingsUpsert) async throws -> CompanyEFacturaSettings {
        let rows: [CompanyEFacturaSettings] = try await client
            .from("company_efactura_settings")
            .upsert(settings, onConflict: "company_id")
            .select()
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func saveAccountantEmail(companyId: UUID, email: String?, existing: CompanyEFacturaSettings?) async throws -> CompanyEFacturaSettings {
        let trimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = (trimmed?.isEmpty == false) ? trimmed : nil
        return try await upsert(
            CompanyEFacturaSettingsUpsert(
                companyId: companyId,
                accountantEmail: clean,
                authStatus: existing?.authStatus.rawValue ?? EFacturaAuthStatus.none.rawValue,
                authRequestedAt: existing?.authRequestedAt,
                authAuthorizedAt: existing?.authAuthorizedAt,
                authValidUntil: optionalDayString(existing?.authValidUntil)
            )
        )
    }

    static func markAuthRequested(companyId: UUID, email: String, existing: CompanyEFacturaSettings?) async throws -> CompanyEFacturaSettings {
        let now = Date()
        return try await upsert(
            CompanyEFacturaSettingsUpsert(
                companyId: companyId,
                accountantEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
                authStatus: EFacturaAuthStatus.requested.rawValue,
                authRequestedAt: now,
                authAuthorizedAt: existing?.authAuthorizedAt,
                authValidUntil: optionalDayString(existing?.authValidUntil)
            )
        )
    }

    static func markAuthAuthorized(companyId: UUID, existing: CompanyEFacturaSettings, validUntil: Date) async throws -> CompanyEFacturaSettings {
        try await upsert(
            CompanyEFacturaSettingsUpsert(
                companyId: companyId,
                accountantEmail: existing.trimmedAccountantEmail,
                authStatus: EFacturaAuthStatus.authorized.rawValue,
                authRequestedAt: existing.authRequestedAt ?? Date(),
                authAuthorizedAt: Date(),
                authValidUntil: dayString(validUntil)
            )
        )
    }

    private static func dayString(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func optionalDayString(_ date: Date?) -> String? {
        guard let date else { return nil }
        return dayString(date)
    }
}
