import Foundation
import Supabase

enum AuthService {
    private static let client = SupabaseManager.client
    static func seedAdminIfNeeded() async throws {
        nonisolated struct SeedResponse: Decodable, Sendable {
            let status: String
            let email: String?
            let error: String?
        }

        let response: SeedResponse = try await client.functions.invoke("seed-admin")
        if let error = response.error {
            throw AppAuthError.seedFailed(error)
        }
    }

    static func signIn(email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let session: Session
        do {
            session = try await client.auth.signIn(email: normalizedEmail, password: password)
        } catch {
            throw mapSignInError(error)
        }

        let profile: UserProfile
        do {
            profile = try await fetchCurrentProfile(userId: session.user.id)
        } catch {
            throw mapAuthError(error)
        }

        if profile.isBlocked {
            try? await client.auth.signOut()
            throw AppAuthError.accountBlocked
        }
        if !profile.isEmailConfirmed && !profile.isAdmin && !profile.isSuperAdmin {
            try? await client.auth.signOut()
            throw AppAuthError.emailNotConfirmed
        }
        return profile
    }

    static func signOut() async throws {
        try await client.auth.signOut()
    }

    static func currentSession() async -> Session? {
        do {
            return try await client.auth.session
        } catch {
            try? await client.auth.signOut()
            return nil
        }
    }

    static func currentUserId() async -> UUID? {
        guard let session = await currentSession() else { return nil }
        return session.user.id
    }

    static func fetchCurrentProfile(userId: UUID? = nil) async throws -> UserProfile {
        let resolvedUserId: UUID
        if let userId {
            resolvedUserId = userId
        } else {
            let session = try await client.auth.session
            resolvedUserId = session.user.id
        }

        let profiles: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: resolvedUserId.uuidString)
            .execute()
            .value

        guard let profile = profiles.first else {
            throw AppAuthError.profileNotFound
        }
        return profile
    }

    static func updateOwnPassword(_ newPassword: String) async throws -> UpdateOwnPasswordResult {
        struct Payload: Encodable {
            let parola: String
        }

        nonisolated struct Response: Decodable, Sendable {
            let error: String?
            let emailStatus: String?
            let emailsSent: Bool?
            let verificationLink: String?

            enum CodingKeys: String, CodingKey {
                case error
                case emailStatus = "email_status"
                case emailsSent = "emails_sent"
                case verificationLink = "verification_link"
            }
        }

        do {
            let response: Response = try await client.functions.invoke(
                "update-own-password",
                options: FunctionInvokeOptions(body: Payload(parola: newPassword))
            )

            if let error = response.error, !error.isEmpty {
                throw AppAuthError.passwordUpdateFailed(error)
            }

            return UpdateOwnPasswordResult(
                emailStatus: response.emailStatus ?? L10n.tr("my_account.password_email_status_unknown"),
                emailsSent: response.emailsSent ?? false,
                verificationLink: response.verificationLink
            )
        } catch let error as AppAuthError {
            throw error
        } catch let error as FunctionsError {
            throw AppAuthError.passwordUpdateFailed(parseFunctionsError(error))
        } catch {
            throw mapAuthError(error)
        }
    }

    private static func parseFunctionsError(_ error: FunctionsError) -> String {
        switch error {
        case .relayError:
            return L10n.tr("my_account.password_update_network_error")
        case .httpError(_, let data):
            nonisolated struct ErrorResponse: Decodable, Sendable { let error: String? }
            if let payload = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               let message = payload.error, !message.isEmpty {
                return message
            }
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                return raw
            }
            return L10n.tr("my_account.password_update_server_error")
        }
    }

    private static func mapSignInError(_ error: Error) -> Error {
        mapAuthError(error)
    }

    private static func mapAuthError(_ error: Error) -> Error {
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .emailNotConfirmed:
                return AppAuthError.emailNotConfirmed
            case .invalidCredentials:
                return AppAuthError.invalidCredentials
            case .sessionNotFound:
                return AppAuthError.sessionStorageFailed
            default:
                break
            }
        }
        let message = error.localizedDescription.lowercased()
        if message.contains("email not confirmed") || message.contains("email_not_confirmed") {
            return AppAuthError.emailNotConfirmed
        }
        if message.contains("invalid login credentials") || message.contains("invalid credentials") {
            return AppAuthError.invalidCredentials
        }
        if message.contains("auth session missing") || message.contains("session missing") {
            return AppAuthError.sessionStorageFailed
        }
        if let decodingError = error as? DecodingError {
            return AppAuthError.decodingFailed(decodingError.localizedDescription)
        }
        return error
    }
}

struct UpdateOwnPasswordResult: Sendable {
    let emailStatus: String
    let emailsSent: Bool
    let verificationLink: String?
}

enum AppAuthError: LocalizedError {
    case profileNotFound
    case accountBlocked
    case emailNotConfirmed
    case invalidCredentials
    case sessionStorageFailed
    case decodingFailed(String)
    case seedFailed(String)
    case passwordUpdateFailed(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return L10n.tr("auth.error_profile_not_found")
        case .accountBlocked:
            return L10n.tr("auth.error_account_blocked")
        case .emailNotConfirmed:
            return L10n.tr("auth.error_email_not_confirmed")
        case .invalidCredentials:
            return L10n.tr("auth.error_invalid_credentials")
        case .sessionStorageFailed:
            return L10n.tr("auth.error_session_storage_failed")
        case .decodingFailed:
            return L10n.tr("auth.error_decoding_failed")
        case .seedFailed(let message):
            return L10n.tr("auth.error_seed_failed", message)
        case .passwordUpdateFailed(let message):
            return message
        case .notConfigured:
            return L10n.tr("auth.error_not_configured")
        }
    }
}
