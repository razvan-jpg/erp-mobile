import Foundation

enum ModuleAccessLevel: String, CaseIterable, Identifiable, Sendable {
    case noAccess
    case read
    case write

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noAccess: return "Fără acces"
        case .read: return "Citire"
        case .write: return "Scriere"
        }
    }

    func toPermission(moduleId: UUID) -> ModulePermission? {
        switch self {
        case .noAccess:
            return nil
        case .read:
            return ModulePermission(moduleId: moduleId, canView: true)
        case .write:
            return ModulePermission(
                moduleId: moduleId,
                canView: true,
                canCreate: true,
                canEdit: true,
                canDelete: true
            )
        }
    }

    static func from(permission: ModulePermission?) -> ModuleAccessLevel {
        guard let permission, permission.hasAnyPermission else { return .noAccess }
        if permission.canCreate || permission.canEdit || permission.canDelete {
            return .write
        }
        return .read
    }
}
