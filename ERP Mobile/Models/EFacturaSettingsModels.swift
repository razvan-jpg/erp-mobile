import Foundation

enum EFacturaAuthStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case none
    case requested
    case authorized

    var labelKey: String {
        switch self {
        case .none: return "efactura.auth_status_none"
        case .requested: return "efactura.auth_status_requested"
        case .authorized: return "efactura.auth_status_authorized"
        }
    }

    var label: String { L10n.tr(labelKey) }
}

enum EFacturaSendStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case none
    case sentToAccountant = "sent_to_accountant"
    case uploaded

    var labelKey: String {
        switch self {
        case .none: return "efactura.send_status_none"
        case .sentToAccountant: return "efactura.send_status_sent"
        case .uploaded: return "efactura.send_status_uploaded"
        }
    }

    var label: String { L10n.tr(labelKey) }
}

struct CompanyEFacturaSettings: Codable, Hashable, Sendable, Identifiable {
    var id: UUID { companyId }
    let companyId: UUID
    var accountantEmail: String?
    var authStatus: EFacturaAuthStatus
    var authRequestedAt: Date?
    var authAuthorizedAt: Date?
    var authValidUntil: Date?
    var authInviteSentAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case accountantEmail = "accountant_email"
        case authStatus = "auth_status"
        case authRequestedAt = "auth_requested_at"
        case authAuthorizedAt = "auth_authorized_at"
        case authValidUntil = "auth_valid_until"
        case authInviteSentAt = "auth_invite_sent_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var trimmedAccountantEmail: String? {
        guard let email = accountantEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return nil
        }
        return email
    }

    var isExpired: Bool {
        guard authStatus == .authorized, let authValidUntil else { return false }
        let calendar = Calendar.current
        return calendar.startOfDay(for: authValidUntil) < calendar.startOfDay(for: Date())
    }

    var canSendInvoices: Bool {
        authStatus == .authorized && trimmedAccountantEmail != nil && authValidUntil != nil && !isExpired
    }

    var validUntilText: String? {
        guard let authValidUntil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: authValidUntil)
    }
}

struct CompanyEFacturaSettingsUpsert: Encodable, Sendable {
    let companyId: UUID
    let accountantEmail: String?
    let authStatus: String
    let authRequestedAt: Date?
    let authAuthorizedAt: Date?
    let authValidUntil: String?

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case accountantEmail = "accountant_email"
        case authStatus = "auth_status"
        case authRequestedAt = "auth_requested_at"
        case authAuthorizedAt = "auth_authorized_at"
        case authValidUntil = "auth_valid_until"
    }
}

struct ClientInvoiceEFacturaUpdate: Encodable, Sendable {
    let efacturaStatus: String
    let efacturaSentAt: Date?
    let efacturaChannel: String?

    enum CodingKeys: String, CodingKey {
        case efacturaStatus = "efactura_status"
        case efacturaSentAt = "efactura_sent_at"
        case efacturaChannel = "efactura_channel"
    }
}
