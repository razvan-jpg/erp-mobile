import Foundation

enum UserCompanyAccessSummary {
    static func labels(
        for user: UserProfile,
        companies: [Company],
        permissionsByUserId: [UUID: [CompanyPermission]]
    ) -> String {
        if user.isSuperAdmin {
            return L10n.tr("users.companies_all")
        }

        var accessibleCompanyIds = Set<UUID>()

        if user.isCompanyAdmin {
            for company in companies where company.adminUserId == user.id {
                accessibleCompanyIds.insert(company.id)
            }
        }

        for permission in permissionsByUserId[user.id] ?? [] where permission.hasAnyPermission {
            accessibleCompanyIds.insert(permission.companyId)
        }

        let names = companies
            .filter { accessibleCompanyIds.contains($0.id) }
            .map(\.denumire)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        if names.isEmpty {
            return L10n.tr("users.companies_none")
        }
        return names.joined(separator: ", ")
    }

    static func permissionsGroupedByUser(_ permissions: [CompanyPermission]) -> [UUID: [CompanyPermission]] {
        Dictionary(grouping: permissions.compactMap { permission -> (UUID, CompanyPermission)? in
            guard let userId = permission.userId else { return nil }
            return (userId, permission)
        }, by: \.0)
            .mapValues { pairs in pairs.map(\.1) }
    }
}
