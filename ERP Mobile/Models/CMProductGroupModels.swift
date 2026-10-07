import Foundation

enum CMProductGroupKind: String, Codable, Sendable {
    case custom
    case menus
    case ungrouped
}

struct CMProductGroup: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var name: String
    var kind: CMProductGroupKind
    var isSystem: Bool
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, kind
        case companyId = "company_id"
        case isSystem = "is_system"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var canDelete: Bool { !isSystem && kind == .custom }
    var canRename: Bool { kind == .custom }
}

struct CMProductGroupMember: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let groupId: UUID
    let productId: UUID
    var sortOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case groupId = "group_id"
        case productId = "product_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct CMMenu: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var name: String
    @SupabaseDecimal var pretVanzare: Decimal
    var isActive: Bool
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case companyId = "company_id"
        case pretVanzare = "pret_vanzare"
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CMMenuLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let menuId: UUID
    let productId: UUID
    @SupabaseDecimal var cantitate: Decimal
    var sortOrder: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, cantitate
        case companyId = "company_id"
        case menuId = "menu_id"
        case productId = "product_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }
}

struct CMProductGroupListItem: Identifiable, Hashable, Sendable {
    let group: CMProductGroup
    let itemCount: Int

    var id: UUID { group.id }
}
