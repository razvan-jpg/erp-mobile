import Foundation
import Supabase

enum ModuleService {
    private static let client = SupabaseManager.client

    static func fetchActiveModules() async throws -> [AppModule] {
        try await client
            .from("modules")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    static func fetchModule(code: String) async throws -> AppModule? {
        let modules: [AppModule] = try await client
            .from("modules")
            .select()
            .eq("code", value: code)
            .limit(1)
            .execute()
            .value
        return modules.first
    }

    static func modulesForPermissionsEditor() async throws -> [AppModule] {
        try await fetchActiveModules()
            .filter { !ModuleCode.dashboardHiddenCodes.contains($0.code) }
            .filter { !ModuleCode.adminOnlyCodes.contains($0.code) }
    }

    static func fetchUserPermissions(userId: UUID) async throws -> [ModulePermission] {
        try await client
            .from("user_module_permissions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    static func accessibleModules(for profile: UserProfile) async throws -> [AppModule] {
        let modules = try await fetchActiveModules()
            .filter { !ModuleCode.dashboardHiddenCodes.contains($0.code) }
        if profile.isSuperAdmin || profile.isCompanyAdmin { return modules }

        let permissions = try await fetchUserPermissions(userId: profile.id)
        let allowedModuleIds = Set(permissions.filter(\.canView).map(\.moduleId))
        return modules.filter {
            allowedModuleIds.contains($0.id) && !ModuleCode.adminOnlyCodes.contains($0.code)
        }
    }
}
