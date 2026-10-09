import Foundation

nonisolated enum CMProductGroupKind: String, Codable, Sendable {
    case custom
    case menus
    case ungrouped
}

nonisolated struct CMProductGroup: Codable, Identifiable, Hashable, Sendable {
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

nonisolated struct CMProductGroupMember: Codable, Identifiable, Hashable, Sendable {
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

nonisolated struct CMMenu: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var name: String
    var pretVanzare: Decimal
    var isActive: Bool
    var sortOrder: Int
    var cod: String
    var permiteSecundareMultiple: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case companyId = "company_id"
        case pretVanzare = "pret_vanzare"
        case isActive = "is_active"
        case sortOrder = "sort_order"
        case cod
        case permiteSecundareMultiple = "permite_secundare_multiple"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    nonisolated init(
        id: UUID,
        companyId: UUID,
        name: String,
        pretVanzare: Decimal,
        isActive: Bool,
        sortOrder: Int,
        cod: String = "",
        permiteSecundareMultiple: Bool = false,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.companyId = companyId
        self.name = name
        self.pretVanzare = pretVanzare
        self.isActive = isActive
        self.sortOrder = sortOrder
        self.cod = cod
        self.permiteSecundareMultiple = permiteSecundareMultiple
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        companyId = try c.decode(UUID.self, forKey: .companyId)
        name = try c.decode(String.self, forKey: .name)
        pretVanzare = try c.decode(SupabaseDecimal.self, forKey: .pretVanzare).wrappedValue
        isActive = try c.decode(Bool.self, forKey: .isActive)
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        cod = try c.decodeIfPresent(String.self, forKey: .cod) ?? ""
        permiteSecundareMultiple = try c.decodeIfPresent(Bool.self, forKey: .permiteSecundareMultiple) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(companyId, forKey: .companyId)
        try c.encode(name, forKey: .name)
        try c.encode(SupabaseDecimal(wrappedValue: pretVanzare), forKey: .pretVanzare)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(cod, forKey: .cod)
        try c.encode(permiteSecundareMultiple, forKey: .permiteSecundareMultiple)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

nonisolated struct CMMenuLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let menuId: UUID
    let productId: UUID
    var cantitate: Decimal
    var sortOrder: Int
    var role: String
    var isRequired: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, cantitate
        case companyId = "company_id"
        case menuId = "menu_id"
        case productId = "product_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case role
        case isRequired = "is_required"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        companyId = try c.decode(UUID.self, forKey: .companyId)
        menuId = try c.decode(UUID.self, forKey: .menuId)
        productId = try c.decode(UUID.self, forKey: .productId)
        cantitate = try c.decode(SupabaseDecimal.self, forKey: .cantitate).wrappedValue
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "secondary"
        isRequired = try c.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(companyId, forKey: .companyId)
        try c.encode(menuId, forKey: .menuId)
        try c.encode(productId, forKey: .productId)
        try c.encode(SupabaseDecimal(wrappedValue: cantitate), forKey: .cantitate)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encode(role, forKey: .role)
        try c.encode(isRequired, forKey: .isRequired)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct CMProductGroupListItem: Identifiable, Hashable, Sendable {
    let group: CMProductGroup
    let itemCount: Int

    var id: UUID { group.id }
}
