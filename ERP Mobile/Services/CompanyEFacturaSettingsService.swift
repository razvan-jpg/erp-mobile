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

    static func spvStatus() async throws -> AnafOauthResult {
        try await invokeOauth(AnafOauthRequest(action: "status", companyId: nil, accountantEmail: nil, clientId: nil, clientSecret: nil))
    }

    static func saveSpvEnrollment(clientId: String, clientSecret: String) async throws {
        let result: AnafOauthResult = try await invokeOauth(AnafOauthRequest(
            action: "save",
            companyId: nil,
            accountantEmail: nil,
            clientId: clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            clientSecret: clientSecret
        ))
        if result.saved != true {
            throw ServiceError.server(result.error ?? "Înrolarea nu a putut fi salvată.")
        }
    }

    static func sendSpvInvite(companyId: UUID, email: String) async throws {
        let result: AnafOauthResult = try await invokeOauth(AnafOauthRequest(
            action: "invite",
            companyId: companyId,
            accountantEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            clientId: nil,
            clientSecret: nil
        ))
        if result.sent != true {
            throw ServiceError.server(result.error ?? "Invitația nu a putut fi trimisă.")
        }
    }

    static func refreshSpv(companyId: UUID) async throws {
        let result: AnafOauthResult = try await invokeOauth(AnafOauthRequest(
            action: "refresh",
            companyId: companyId,
            accountantEmail: nil,
            clientId: nil,
            clientSecret: nil
        ))
        if result.refreshed != true {
            throw ServiceError.server(result.error ?? "Prelungirea nu a reușit.")
        }
    }

    static func revokeSpv(companyId: UUID) async throws {
        let result: AnafOauthResult = try await invokeOauth(AnafOauthRequest(
            action: "revoke",
            companyId: companyId,
            accountantEmail: nil,
            clientId: nil,
            clientSecret: nil
        ))
        if result.revoked != true {
            throw ServiceError.server(result.error ?? "Revocarea nu a reușit.")
        }
    }

    private static func invokeOauth<T: Encodable>(_ body: T) async throws -> AnafOauthResult {
        do {
            let result: AnafOauthResult = try await client.functions.invoke(
                "anaf-oauth",
                options: FunctionInvokeOptions(body: body)
            )
            if let error = result.error, !error.isEmpty {
                throw ServiceError.server(error)
            }
            return result
        } catch let error as FunctionsError {
            throw ServiceError.server(oauthError(error))
        }
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

    private static func oauthError(_ error: FunctionsError) -> String {
        switch error {
        case .relayError:
            return "Eroare de rețea la autorizarea SPV."
        case .httpError(_, let data):
            if let payload = try? JSONDecoder().decode(AnafOauthResult.self, from: data),
               let message = payload.error, !message.isEmpty {
                return message
            }
            return "Autorizarea SPV nu a putut porni."
        }
    }
}

private nonisolated struct AnafOauthRequest: Encodable, Sendable {
    let action: String
    let companyId: UUID?
    let accountantEmail: String?
    let clientId: String?
    let clientSecret: String?

    enum CodingKeys: String, CodingKey {
        case action
        case companyId = "company_id"
        case accountantEmail = "accountant_email"
        case clientId = "client_id"
        case clientSecret = "client_secret"
    }
}

nonisolated struct AnafOauthResult: Decodable, Sendable {
    let configured: Bool?
    let redirectUri: String?
    let clientId: String?
    let url: String?
    let saved: Bool?
    let sent: Bool?
    let refreshed: Bool?
    let revoked: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case configured
        case redirectUri = "redirect_uri"
        case clientId = "client_id"
        case url
        case saved
        case sent
        case refreshed
        case revoked
        case error
    }
}
