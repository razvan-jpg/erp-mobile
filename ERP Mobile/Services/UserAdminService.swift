import Foundation
import Supabase

struct CreateUserRequest: Encodable, Sendable {
    let nume: String
    let prenume: String
    let cnp: String
    let email: String
    let telefon: String
    let parola: String
    let permissions: [PermissionInput]
    let companyPermissions: [CompanyPermissionInput]
    let adminEmail: String
    let modulePermissionsSummary: String
    let companyPermissionsSummary: String

    enum CodingKeys: String, CodingKey {
        case nume, prenume, cnp, email, telefon, parola, permissions
        case companyPermissions = "company_permissions"
        case adminEmail = "admin_email"
        case modulePermissionsSummary = "module_permissions_summary"
        case companyPermissionsSummary = "company_permissions_summary"
    }
}

struct CreateUserResult: Sendable {
    let user: UserProfile
    let emailStatus: String
    let emailsSent: Bool
    let verificationLink: String?
}

struct UpdateUserRequest: Encodable, Sendable {
    let userId: UUID
    var nume: String?
    var prenume: String?
    var cnp: String?
    var email: String?
    var telefon: String?
    var parola: String?
    var permissions: [PermissionInput]?
    var companyPermissions: [CompanyPermissionInput]?

    enum CodingKeys: String, CodingKey {
        case nume, prenume, cnp, email, telefon, parola, permissions
        case companyPermissions = "company_permissions"
        case userId = "user_id"
    }
}

struct ToggleBlockRequest: Encodable, Sendable {
    let userId: UUID
    let isBlocked: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isBlocked = "is_blocked"
    }
}

struct DeleteUserRequest: Encodable, Sendable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct ResendConfirmationRequest: Encodable, Sendable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

struct UpdateUserResult: Sendable {
    let user: UserProfile
    let emailChanged: Bool
    let emailStatus: String?
    let emailsSent: Bool
    let verificationLink: String?
}

struct ResendConfirmationResult: Sendable {
    let user: UserProfile
    let emailStatus: String
    let emailsSent: Bool
    let verificationLink: String?
}

private nonisolated struct UserResponse: Decodable, Sendable {
    let user: UserProfile?
    let error: String?
    let emailChanged: Bool?
    let emailStatus: String?
    let emailsSent: Bool?
    let verificationLink: String?

    enum CodingKeys: String, CodingKey {
        case user, error
        case emailChanged = "email_changed"
        case emailStatus = "email_status"
        case emailsSent = "emails_sent"
        case verificationLink = "verification_link"
    }
}

private nonisolated struct ErrorResponse: Decodable, Sendable {
    let error: String?
}

private nonisolated struct DeleteResponse: Decodable, Sendable {
    let status: String?
    let error: String?
}

enum UserAdminService {
    private static let client = SupabaseManager.client
    private static let responseDecoder = SupabaseDecoding.jsonDecoder

    static func fetchAllUsers() async throws -> [UserProfile] {
        try await client
            .from("user_profiles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchUserPermissions(userId: UUID) async throws -> [ModulePermission] {
        try await ModuleService.fetchUserPermissions(userId: userId)
    }

    static func fetchUserCompanyPermissions(userId: UUID) async throws -> [CompanyPermission] {
        try await CompanyService.fetchUserCompanyPermissions(userId: userId)
    }

    static func createUser(_ request: CreateUserRequest) async throws -> CreateUserResult {
        let response: UserResponse = try await invoke("admin-create-user", body: request)
        if let error = response.error { throw ServiceError.server(error) }
        let user: UserProfile
        if let responseUser = response.user {
            user = responseUser
        } else if let fetched = try? await fetchUserByEmail(request.email) {
            user = fetched
        } else {
            throw ServiceError.invalidResponse
        }
        return CreateUserResult(
            user: user,
            emailStatus: response.emailStatus ?? "Status email necunoscut.",
            emailsSent: response.emailsSent ?? false,
            verificationLink: response.verificationLink
        )
    }

    private static func fetchUserByEmail(_ email: String) async throws -> UserProfile {
        let users: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value
        guard let user = users.first else { throw ServiceError.invalidResponse }
        return user
    }

    static func updateUser(_ request: UpdateUserRequest) async throws -> UpdateUserResult {
        let response: UserResponse = try await invoke("admin-update-user", body: request)
        if let error = response.error { throw ServiceError.server(error) }
        let user: UserProfile
        if let responseUser = response.user {
            user = responseUser
        } else {
            user = try await fetchUser(userId: request.userId)
        }
        return UpdateUserResult(
            user: user,
            emailChanged: response.emailChanged ?? false,
            emailStatus: response.emailStatus,
            emailsSent: response.emailsSent ?? false,
            verificationLink: response.verificationLink
        )
    }

    static func resendConfirmation(userId: UUID) async throws -> ResendConfirmationResult {
        let request = ResendConfirmationRequest(userId: userId)
        let response: UserResponse = try await invoke("admin-resend-confirmation", body: request)
        if let error = response.error { throw ServiceError.server(error) }
        guard let user = response.user else { throw ServiceError.invalidResponse }
        return ResendConfirmationResult(
            user: user,
            emailStatus: response.emailStatus ?? "Status email necunoscut.",
            emailsSent: response.emailsSent ?? false,
            verificationLink: response.verificationLink
        )
    }

    static func toggleBlock(userId: UUID, isBlocked: Bool) async throws -> UserProfile {
        let request = ToggleBlockRequest(userId: userId, isBlocked: isBlocked)
        let response: UserResponse = try await invoke("admin-toggle-block", body: request)
        if let error = response.error { throw ServiceError.server(error) }
        guard let user = response.user else { throw ServiceError.invalidResponse }
        return user
    }

    static func deleteUser(userId: UUID) async throws {
        let request = DeleteUserRequest(userId: userId)
        let response: DeleteResponse = try await invoke("admin-delete-user", body: request)
        if let error = response.error { throw ServiceError.server(error) }
    }

    private static func fetchUser(userId: UUID) async throws -> UserProfile {
        let users: [UserProfile] = try await client
            .from("user_profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        guard let user = users.first else { throw ServiceError.invalidResponse }
        return user
    }

    private static func invoke<T: Encodable, R: Decodable & Sendable>(
        _ functionName: String,
        body: T
    ) async throws -> R {
        do {
            return try await client.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(body: body),
                decoder: responseDecoder
            )
        } catch let error as FunctionsError {
            throw ServiceError.server(parseFunctionsError(error))
        }
    }

    private static func parseFunctionsError(_ error: FunctionsError) -> String {
        switch error {
        case .relayError:
            return "Eroare de rețea la apelul funcției Edge."
        case .httpError(_, let data):
            if let payload = try? responseDecoder.decode(ErrorResponse.self, from: data),
               let message = payload.error, !message.isEmpty {
                return message
            }
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                return raw
            }
            return "Eroare server la actualizarea utilizatorului."
        }
    }
}

enum ServiceError: LocalizedError {
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        case .invalidResponse: return "Răspuns invalid de la server."
        }
    }
}
