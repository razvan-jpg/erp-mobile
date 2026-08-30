import Foundation
import Supabase

private struct CashRegisterSettingsUpsert: Encodable {
    let companyId: UUID
    let settings: CashRegisterSettingsPayload

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case settings
    }
}

enum CashRegisterSettingsService {
    private static let client = SupabaseManager.client
    private static let passwordKeyPrefix = "utility.cashregister.password."
    private static let payloadKeyPrefix = "utility.cashregister.payload."
    /// Shared scope for utility settings — not tied to the ERP company currently open in the app.
    static let globalScopeId = UUID(uuidString: "E1E1E1E1-E1E1-4E1E-A1E1-E1E1E1E1E1E1")!

    static func fetchGlobalSettings() async throws -> CompanyCashRegisterSettings {
        try await fetchSettings(companyId: globalScopeId)
    }

    @discardableResult
    static func saveGlobalSettings(_ settings: CompanyCashRegisterSettings, password: String?) async throws -> CompanyCashRegisterSettings {
        try await saveSettings(settings, password: password)
    }

    static func loadGlobalPassword() -> String? {
        if let password = loadPassword(companyId: globalScopeId), !password.isEmpty {
            return password
        }
        let prefix = passwordKeyPrefix
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            if let password = UserDefaults.standard.string(forKey: key), !password.isEmpty {
                return password
            }
        }
        return nil
    }

    static func fetchSettings(companyId: UUID) async throws -> CompanyCashRegisterSettings {
        do {
            let rows: [CompanyCashRegisterSettings] = try await client
                .from("company_cash_register_settings")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .limit(1)
                .execute()
                .value

            if let existing = rows.first {
                saveLocalPayload(existing.payload, companyId: companyId)
                return existing
            }
            return loadLocalSettings(companyId: companyId)
        } catch {
            if isMissingRemoteTableError(error) {
                return loadLocalSettings(companyId: companyId)
            }
            throw error
        }
    }

    @discardableResult
    static func saveSettings(_ settings: CompanyCashRegisterSettings, password: String?) async throws -> CompanyCashRegisterSettings {
        saveLocalPayload(settings.payload, companyId: settings.companyId)
        if let password, !password.isEmpty {
            savePassword(password, companyId: settings.companyId)
        }

        do {
            let payload = CashRegisterSettingsUpsert(companyId: settings.companyId, settings: settings.payload)
            let rows: [CompanyCashRegisterSettings] = try await client
                .from("company_cash_register_settings")
                .upsert(payload, onConflict: "company_id")
                .select()
                .execute()
                .value
            guard let saved = rows.first else { throw ServiceError.invalidResponse }
            return saved
        } catch {
            if isMissingRemoteTableError(error) {
                return settings
            }
            throw error
        }
    }

    static func loadPassword(companyId: UUID) -> String? {
        UserDefaults.standard.string(forKey: passwordKeyPrefix + companyId.uuidString)
    }

    static func savePassword(_ password: String, companyId: UUID) {
        UserDefaults.standard.set(password, forKey: passwordKeyPrefix + companyId.uuidString)
    }

    private static func loadLocalSettings(companyId: UUID) -> CompanyCashRegisterSettings {
        guard
            let data = UserDefaults.standard.data(forKey: payloadKeyPrefix + companyId.uuidString),
            let payload = try? JSONDecoder().decode(CashRegisterSettingsPayload.self, from: data)
        else {
            return .defaults(companyId: companyId)
        }
        return CompanyCashRegisterSettings(companyId: companyId, payload: payload, updatedAt: nil)
    }

    private static func saveLocalPayload(_ payload: CashRegisterSettingsPayload, companyId: UUID) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: payloadKeyPrefix + companyId.uuidString)
    }

    private static func isMissingRemoteTableError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("company_cash_register_settings") { return true }
        if message.contains("schema cache") { return true }
        if message.contains("pgrst205") { return true }
        if message.contains("does not exist") { return true }
        return false
    }
}
