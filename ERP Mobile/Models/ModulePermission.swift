import Foundation

struct ModulePermission: Codable, Identifiable, Hashable, Sendable {
    let id: UUID?
    let userId: UUID?
    let moduleId: UUID
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case moduleId = "module_id"
        case canView = "can_view"
        case canCreate = "can_create"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
    }

    init(
        id: UUID? = nil,
        userId: UUID? = nil,
        moduleId: UUID,
        canView: Bool = false,
        canCreate: Bool = false,
        canEdit: Bool = false,
        canDelete: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.moduleId = moduleId
        self.canView = canView
        self.canCreate = canCreate
        self.canEdit = canEdit
        self.canDelete = canDelete
    }

    var hasAnyPermission: Bool {
        canView || canCreate || canEdit || canDelete
    }
}

struct PermissionInput: Codable, Sendable {
    let moduleId: UUID
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    enum CodingKeys: String, CodingKey {
        case moduleId = "module_id"
        case canView = "can_view"
        case canCreate = "can_create"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
    }
}
