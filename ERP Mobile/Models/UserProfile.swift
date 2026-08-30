import Foundation

struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var nume: String
    var prenume: String
    var cnp: String
    var email: String
    var telefon: String?
    var isAdmin: Bool
    var isSuperAdmin: Bool
    var isBlocked: Bool
    var isEmailConfirmed: Bool
    var selectedCompanyId: UUID?
    var preferredLanguageCode: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, nume, prenume, cnp, email, telefon
        case isAdmin = "is_admin"
        case isSuperAdmin = "is_superadmin"
        case isBlocked = "is_blocked"
        case isEmailConfirmed = "is_email_confirmed"
        case selectedCompanyId = "selected_company_id"
        case preferredLanguageCode = "preferred_language_code"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var fullName: String { "\(prenume) \(nume)" }

    var statusLabel: String {
        if isBlocked { return L10n.tr("users.status_blocked") }
        if !isEmailConfirmed { return L10n.tr("users.status_unconfirmed") }
        return L10n.tr("users.status_active")
    }

    var isActive: Bool { !isBlocked && isEmailConfirmed }

    var isCompanyAdmin: Bool { isAdmin && !isSuperAdmin }

    var roleLabel: String? {
        if isSuperAdmin { return L10n.tr("users.role_superadmin") }
        if isCompanyAdmin { return L10n.tr("users.role_company_admin") }
        return nil
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        nume = try container.decode(String.self, forKey: .nume)
        prenume = try container.decode(String.self, forKey: .prenume)
        cnp = try container.decode(String.self, forKey: .cnp)
        email = try container.decode(String.self, forKey: .email)
        telefon = try container.decodeIfPresent(String.self, forKey: .telefon)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        isSuperAdmin = try container.decodeIfPresent(Bool.self, forKey: .isSuperAdmin) ?? false
        isBlocked = try container.decode(Bool.self, forKey: .isBlocked)
        isEmailConfirmed = try container.decodeIfPresent(Bool.self, forKey: .isEmailConfirmed) ?? true
        selectedCompanyId = try container.decodeIfPresent(UUID.self, forKey: .selectedCompanyId)
        preferredLanguageCode = try container.decodeIfPresent(String.self, forKey: .preferredLanguageCode) ?? AppLanguage.romanian.rawValue
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

struct UserProfileWithPermissions: Identifiable, Hashable, Sendable {
    let profile: UserProfile
    var permissions: [ModulePermission]

    var id: UUID { profile.id }
}
