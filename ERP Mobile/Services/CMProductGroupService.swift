import Foundation
import Supabase

enum CMProductGroupService {
    private static let client = SupabaseManager.client

    private struct GroupInsert: Encodable {
        let companyId: UUID
        let name: String
        let kind: String
        let isSystem: Bool
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case name, kind
            case companyId = "company_id"
            case isSystem = "is_system"
            case sortOrder = "sort_order"
        }
    }

    private struct GroupNamePatch: Encodable {
        let name: String
    }

    private struct MembershipRow: Decodable {
        let groupId: UUID
        let productId: UUID

        enum CodingKeys: String, CodingKey {
            case groupId = "group_id"
            case productId = "product_id"
        }
    }

    private struct MemberInsert: Encodable {
        let companyId: UUID
        let groupId: UUID
        let productId: UUID
        let sortOrder: Int

        enum CodingKeys: String, CodingKey {
            case companyId = "company_id"
            case groupId = "group_id"
            case productId = "product_id"
            case sortOrder = "sort_order"
        }
    }

    private struct MenuInsert: Encodable {
        let companyId: UUID
        let name: String
        let pretVanzare: Decimal
        let pretVanzareOnline: Decimal
        let isActive: Bool
        let sortOrder: Int
        let cod: String
        let permiteSecundareMultiple: Bool

        enum CodingKeys: String, CodingKey {
            case name, cod
            case companyId = "company_id"
            case pretVanzare = "pret_vanzare"
            case pretVanzareOnline = "pret_vanzare_online"
            case isActive = "is_active"
            case sortOrder = "sort_order"
            case permiteSecundareMultiple = "permite_secundare_multiple"
        }
    }

    private struct MenuPatch: Encodable {
        let name: String
        let pretVanzare: Decimal
        let pretVanzareOnline: Decimal
        let isActive: Bool
        let permiteSecundareMultiple: Bool

        enum CodingKeys: String, CodingKey {
            case name
            case pretVanzare = "pret_vanzare"
            case pretVanzareOnline = "pret_vanzare_online"
            case isActive = "is_active"
            case permiteSecundareMultiple = "permite_secundare_multiple"
        }
    }

    private struct MenuLineInsert: Encodable {
        let companyId: UUID
        let menuId: UUID
        let productId: UUID
        let cantitate: Decimal
        let sortOrder: Int
        let role: String
        let isRequired: Bool

        enum CodingKeys: String, CodingKey {
            case cantitate, role
            case companyId = "company_id"
            case menuId = "menu_id"
            case productId = "product_id"
            case sortOrder = "sort_order"
            case isRequired = "is_required"
        }
    }

    static func ensureSystemGroups(companyId: UUID) async throws {
        let existing: [CMProductGroup] = try await client
            .from("cm_product_groups")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .in("kind", values: ["menus", "ungrouped"])
            .execute()
            .value

        if !existing.contains(where: { $0.kind == .menus }) {
            let _: CMProductGroup = try await client
                .from("cm_product_groups")
                .insert(GroupInsert(
                    companyId: companyId,
                    name: "Meniuri",
                    kind: CMProductGroupKind.menus.rawValue,
                    isSystem: true,
                    sortOrder: 9000
                ))
                .select()
                .single()
                .execute()
                .value
        }

        if !existing.contains(where: { $0.kind == .ungrouped }) {
            let _: CMProductGroup = try await client
                .from("cm_product_groups")
                .insert(GroupInsert(
                    companyId: companyId,
                    name: "Produse fara grupa",
                    kind: CMProductGroupKind.ungrouped.rawValue,
                    isSystem: true,
                    sortOrder: 9100
                ))
                .select()
                .single()
                .execute()
                .value
        }
    }

    static func fetchGroups(companyId: UUID) async throws -> [CMProductGroup] {
        try await ensureSystemGroups(companyId: companyId)
        return try await client
            .from("cm_product_groups")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("sort_order", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func fetchCustomGroups(companyId: UUID) async throws -> [CMProductGroup] {
        try await fetchGroups(companyId: companyId).filter { $0.kind == .custom }
    }

    static func fetchGroupListItems(companyId: UUID) async throws -> [CMProductGroupListItem] {
        let groups = try await fetchGroups(companyId: companyId)
        let members: [CMProductGroupMember] = try await client
            .from("cm_product_group_members")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        let menus: [CMMenu] = try await client
            .from("cm_menus")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value

        let catalogProducts = try await ProductService.fetchProducts(
            companyId: companyId,
            inCatalog: true
        )
        let assignedProductIds = Set(members.map(\.productId))
        let ungroupedCount = catalogProducts.filter { product in
            (product.tip == .produsFinit || product.tip == .marfa)
                && !assignedProductIds.contains(product.id)
        }.count

        let memberCountByGroup = Dictionary(grouping: members, by: \.groupId).mapValues(\.count)

        return groups.map { group in
            let count: Int
            switch group.kind {
            case .custom:
                count = memberCountByGroup[group.id] ?? 0
            case .menus:
                count = menus.count
            case .ungrouped:
                count = ungroupedCount
            }
            return CMProductGroupListItem(group: group, itemCount: count)
        }
    }

    static func createGroup(companyId: UUID, name: String) async throws -> CMProductGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CMCatalogError.emptyGroupName }
        let existing = (try? await fetchGroups(companyId: companyId)) ?? []
        let nextOrder = (existing.filter { $0.kind == .custom }.map(\.sortOrder).max() ?? 0) + 10
        let localId = UUID()
        let optimistic = OfflineOptimistic.cmGroup(
            id: localId,
            companyId: companyId,
            name: trimmed,
            sortOrder: nextOrder
        )
        return try await OfflineAwareGateway.run(
            companyId: companyId,
            operation: .cmGroupCreate,
            entityKind: LocalDocumentEntityKind.cmGroup.rawValue,
            entityId: localId,
            title: trimmed,
            payload: SyncPayloads.CMGroupCreate(
                id: localId,
                companyId: companyId,
                name: trimmed,
                sortOrder: nextOrder
            ),
            optimistic: optimistic,
            remote: {
                try await client
                    .from("cm_product_groups")
                    .insert(GroupInsert(
                        companyId: companyId,
                        name: trimmed,
                        kind: CMProductGroupKind.custom.rawValue,
                        isSystem: false,
                        sortOrder: nextOrder
                    ))
                    .select()
                    .single()
                    .execute()
                    .value
            }
        )
    }

    static func renameGroup(id: UUID, name: String) async throws -> CMProductGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CMCatalogError.emptyGroupName }
        let companyId = await OfflineCompany.requireId()
        let optimistic = OfflineOptimistic.cmGroup(
            id: id,
            companyId: companyId,
            name: trimmed,
            sortOrder: 0
        )
        return try await OfflineAwareGateway.run(
            companyId: companyId,
            operation: .cmGroupRename,
            entityKind: LocalDocumentEntityKind.cmGroup.rawValue,
            entityId: id,
            title: trimmed,
            payload: SyncPayloads.CMGroupRename(id: id, name: trimmed),
            optimistic: optimistic,
            remote: {
                try await client
                    .from("cm_product_groups")
                    .update(GroupNamePatch(name: trimmed))
                    .eq("id", value: id.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value
            }
        )
    }

    static func deleteGroup(id: UUID) async throws {
        let companyId = await OfflineCompany.requireId()
        try await OfflineAwareGateway.runVoid(
            companyId: companyId,
            operation: .cmGroupDelete,
            entityKind: LocalDocumentEntityKind.cmGroup.rawValue,
            entityId: id,
            title: L10n.tr("offline.entity.cm_group"),
            payload: SyncPayloads.UUIDPayload(id: id),
            remote: {
                try await client
                    .from("cm_product_groups")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        )
    }

    static func fetchMembers(groupId: UUID) async throws -> [CMProductGroupMember] {
        try await client
            .from("cm_product_group_members")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    static func fetchProductGroupIds(companyId: UUID) async throws -> [UUID: Set<UUID>] {
        let rows: [MembershipRow] = try await client
            .from("cm_product_group_members")
            .select("product_id, group_id")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        var map: [UUID: Set<UUID>] = [:]
        for row in rows {
            map[row.productId, default: []].insert(row.groupId)
        }
        return map
    }

    static func fetchMembers(productId: UUID) async throws -> [CMProductGroupMember] {
        try await client
            .from("cm_product_group_members")
            .select()
            .eq("product_id", value: productId.uuidString)
            .execute()
            .value
    }

    static func fetchProducts(inGroupId groupId: UUID, companyId: UUID) async throws -> [Product] {
        let members = try await fetchMembers(groupId: groupId)
        guard !members.isEmpty else { return [] }
        let products = try await ProductService.fetchProducts(ids: members.map(\.productId))
        let byId = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        return members.compactMap { byId[$0.productId] }
    }

    static func fetchUngroupedCatalogProducts(companyId: UUID) async throws -> [Product] {
        let members: [CMProductGroupMember] = try await client
            .from("cm_product_group_members")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        let assigned = Set(members.map(\.productId))
        let catalog = try await ProductService.fetchProducts(
            companyId: companyId,
            inCatalog: true
        )
        return ProductSorting.sortedByName(
            catalog.filter { product in
                (product.tip == .produsFinit || product.tip == .marfa)
                    && !assigned.contains(product.id)
            }
        )
    }

    static func setProductGroups(
        companyId: UUID,
        productId: UUID,
        groupIds: [UUID]
    ) async throws {
        let unique = Array(Set(groupIds))
        guard unique.count <= 2 else { throw CMCatalogError.tooManyGroups }

        if !OfflineWriteContext.isSyncDrain {
            let online = await MainActor.run { NetworkMonitor.shared.isOnline }
            if !online {
                try SyncOutbox.enqueue(
                    companyId: companyId,
                    operationType: .cmSetProductGroups,
                    entityKind: LocalDocumentEntityKind.cmGroup.rawValue,
                    entityId: productId,
                    title: L10n.tr("offline.entity.cm_group"),
                    payload: SyncPayloads.CMSetProductGroups(
                        companyId: companyId,
                        productId: productId,
                        groupIds: unique
                    )
                )
                await MainActor.run {
                    SyncEngine.shared.refreshPublishedState(companyId: companyId)
                }
                return
            }
        }

        let customGroups = try await fetchCustomGroups(companyId: companyId)
        let allowed = Set(customGroups.map(\.id))
        guard unique.allSatisfy({ allowed.contains($0) }) else {
            throw CMCatalogError.invalidGroup
        }

        let existing = try await fetchMembers(productId: productId)
        for member in existing where !unique.contains(member.groupId) {
            try await client
                .from("cm_product_group_members")
                .delete()
                .eq("id", value: member.id.uuidString)
                .execute()
        }

        let existingIds = Set(existing.map(\.groupId))
        for (index, groupId) in unique.enumerated() where !existingIds.contains(groupId) {
            let _: CMProductGroupMember = try await client
                .from("cm_product_group_members")
                .insert(MemberInsert(
                    companyId: companyId,
                    groupId: groupId,
                    productId: productId,
                    sortOrder: index
                ))
                .select()
                .single()
                .execute()
                .value
        }
    }

    static func addProduct(toGroupId groupId: UUID, companyId: UUID, productId: UUID) async throws {
        let current = try await fetchMembers(productId: productId)
        if current.contains(where: { $0.groupId == groupId }) { return }
        if current.count >= 2 { throw CMCatalogError.tooManyGroups }
        let _: CMProductGroupMember = try await client
            .from("cm_product_group_members")
            .insert(MemberInsert(
                companyId: companyId,
                groupId: groupId,
                productId: productId,
                sortOrder: current.count
            ))
            .select()
            .single()
            .execute()
            .value
    }

    static func removeProduct(fromGroupId groupId: UUID, productId: UUID) async throws {
        try await client
            .from("cm_product_group_members")
            .delete()
            .eq("group_id", value: groupId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .execute()
    }

    // MARK: - Menus

    static func fetchMenus(companyId: UUID) async throws -> [CMMenu] {
        try await client
            .from("cm_menus")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("sort_order", ascending: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    static func fetchMenuLines(menuId: UUID) async throws -> [CMMenuLine] {
        try await client
            .from("cm_menu_lines")
            .select()
            .eq("menu_id", value: menuId.uuidString)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    static func fetchMainProductImages(menuIds: [UUID]) async throws -> [UUID: String] {
        let unique = Array(Set(menuIds))
        guard !unique.isEmpty else { return [:] }
        struct MainLine: Decodable {
            let menuId: UUID
            let productId: UUID
            enum CodingKeys: String, CodingKey {
                case menuId = "menu_id"
                case productId = "product_id"
            }
        }
        struct ImageRow: Decodable {
            let id: UUID
            let imagineUrl: String?
            enum CodingKeys: String, CodingKey {
                case id
                case imagineUrl = "imagine_url"
            }
        }
        var productByMenu: [UUID: UUID] = [:]
        for chunk in unique.chunked(into: 200) {
            let lines: [MainLine] = try await client
                .from("cm_menu_lines")
                .select("menu_id,product_id")
                .in("menu_id", values: chunk.map(\.uuidString))
                .eq("role", value: "main")
                .execute()
                .value
            for line in lines {
                productByMenu[line.menuId] = line.productId
            }
        }
        var imageByProduct: [UUID: String] = [:]
        for chunk in Array(Set(productByMenu.values)).chunked(into: 200) {
            let rows: [ImageRow] = try await client
                .from("products")
                .select("id,imagine_url")
                .in("id", values: chunk.map(\.uuidString))
                .execute()
                .value
            for row in rows {
                let url = row.imagineUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !url.isEmpty {
                    imageByProduct[row.id] = url
                }
            }
        }
        var result: [UUID: String] = [:]
        for (menuId, productId) in productByMenu {
            if let url = imageByProduct[productId] {
                result[menuId] = url
            }
        }
        return result
    }

    struct MenuLineDraft: Sendable {
        let productId: UUID
        let role: String
        let isRequired: Bool
    }

    static func nextMenuCode(companyId: UUID) async throws -> String {
        struct CodeRow: Decodable { let cod: String? }
        let products: [CodeRow] = try await client
            .from("products")
            .select("cod")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        let menus: [CodeRow] = try await client
            .from("cm_menus")
            .select("cod")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        var used = Set<String>()
        for row in products + menus {
            let code = row.cod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !code.isEmpty { used.insert(code) }
        }
        var number = 1
        while number < 100000 {
            let digits = String(number)
            let padded = String(repeating: "0", count: max(0, 5 - digits.count)) + digits
            let candidate = "M" + padded
            if !used.contains(candidate) { return candidate }
            number += 1
        }
        throw CMCatalogError.menuShape
    }

    static func createMenu(
        companyId: UUID,
        name: String,
        pretVanzare: Decimal,
        pretVanzareOnline: Decimal? = nil,
        productIds: [UUID],
        permiteSecundareMultiple: Bool = false
    ) async throws -> CMMenu {
        let onlinePrice = pretVanzareOnline ?? pretVanzare
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CMCatalogError.emptyMenuName }
        guard !productIds.isEmpty else { throw CMCatalogError.emptyMenuProducts }
        let code = try await nextMenuCode(companyId: companyId)

        let localId = UUID()
        let optimistic = OfflineOptimistic.cmMenu(
            id: localId,
            companyId: companyId,
            name: trimmed,
            pretVanzare: pretVanzare,
            pretVanzareOnline: onlinePrice,
            cod: code,
            permiteSecundareMultiple: permiteSecundareMultiple
        )
        return try await OfflineAwareGateway.run(
            companyId: companyId,
            operation: .cmMenuCreate,
            entityKind: LocalDocumentEntityKind.cmMenu.rawValue,
            entityId: localId,
            title: trimmed,
            payload: SyncPayloads.CMMenuCreate(
                id: localId,
                companyId: companyId,
                name: trimmed,
                pretVanzare: pretVanzare,
                pretVanzareOnline: onlinePrice,
                productIds: productIds,
                permiteSecundareMultiple: permiteSecundareMultiple
            ),
            optimistic: optimistic,
            remote: {
                let menu: CMMenu = try await client
                    .from("cm_menus")
                    .insert(MenuInsert(
                        companyId: companyId,
                        name: trimmed,
                        pretVanzare: pretVanzare,
                        pretVanzareOnline: onlinePrice,
                        isActive: true,
                        sortOrder: 0,
                        cod: code,
                        permiteSecundareMultiple: permiteSecundareMultiple
                    ))
                    .select()
                    .single()
                    .execute()
                    .value

                for (index, productId) in productIds.enumerated() {
                    let role = index == 0 ? "main" : "secondary"
                    let required = index <= 1
                    let _: CMMenuLine = try await client
                        .from("cm_menu_lines")
                        .insert(MenuLineInsert(
                            companyId: companyId,
                            menuId: menu.id,
                            productId: productId,
                            cantitate: 1,
                            sortOrder: index,
                            role: role,
                            isRequired: required
                        ))
                        .select()
                        .single()
                        .execute()
                        .value
                }
                return menu
            }
        )
    }

    static func updateMenu(
        menuId: UUID,
        companyId: UUID,
        name: String,
        pretVanzare: Decimal,
        pretVanzareOnline: Decimal? = nil,
        isActive: Bool,
        productIds: [UUID],
        permiteSecundareMultiple: Bool = false
    ) async throws -> CMMenu {
        let onlinePrice = pretVanzareOnline ?? pretVanzare
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CMCatalogError.emptyMenuName }
        guard !productIds.isEmpty else { throw CMCatalogError.emptyMenuProducts }

        let optimistic = OfflineOptimistic.cmMenu(
            id: menuId,
            companyId: companyId,
            name: trimmed,
            pretVanzare: pretVanzare,
            pretVanzareOnline: onlinePrice,
            permiteSecundareMultiple: permiteSecundareMultiple
        )
        return try await OfflineAwareGateway.run(
            companyId: companyId,
            operation: .cmMenuUpdate,
            entityKind: LocalDocumentEntityKind.cmMenu.rawValue,
            entityId: menuId,
            title: trimmed,
            payload: SyncPayloads.CMMenuUpdate(
                id: menuId,
                companyId: companyId,
                name: trimmed,
                pretVanzare: pretVanzare,
                pretVanzareOnline: onlinePrice,
                isActive: isActive,
                productIds: productIds,
                permiteSecundareMultiple: permiteSecundareMultiple
            ),
            optimistic: optimistic,
            remote: {
                let menu: CMMenu = try await client
                    .from("cm_menus")
                    .update(MenuPatch(
                        name: trimmed,
                        pretVanzare: pretVanzare,
                        pretVanzareOnline: onlinePrice,
                        isActive: isActive,
                        permiteSecundareMultiple: permiteSecundareMultiple
                    ))
                    .eq("id", value: menuId.uuidString)
                    .select()
                    .single()
                    .execute()
                    .value

                try await client
                    .from("cm_menu_lines")
                    .delete()
                    .eq("menu_id", value: menuId.uuidString)
                    .execute()

                for (index, productId) in productIds.enumerated() {
                    let role = index == 0 ? "main" : "secondary"
                    let required = index <= 1
                    let _: CMMenuLine = try await client
                        .from("cm_menu_lines")
                        .insert(MenuLineInsert(
                            companyId: companyId,
                            menuId: menuId,
                            productId: productId,
                            cantitate: 1,
                            sortOrder: index,
                            role: role,
                            isRequired: required
                        ))
                        .select()
                        .single()
                        .execute()
                        .value
                }
                return menu
            }
        )
    }

    static func deleteMenu(id: UUID) async throws {
        let companyId = await OfflineCompany.requireId()
        try await OfflineAwareGateway.runVoid(
            companyId: companyId,
            operation: .cmMenuDelete,
            entityKind: LocalDocumentEntityKind.cmMenu.rawValue,
            entityId: id,
            title: L10n.tr("offline.entity.cm_menu"),
            payload: SyncPayloads.UUIDPayload(id: id),
            remote: {
                try await client
                    .from("cm_menus")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        )
    }
}

enum CMCatalogError: LocalizedError {
    case emptyGroupName
    case emptyMenuName
    case emptyMenuProducts
    case menuShape
    case tooManyGroups
    case invalidGroup

    var errorDescription: String? {
        switch self {
        case .emptyGroupName: return L10n.tr("module.catalog.cm.error_empty_group_name")
        case .emptyMenuName: return L10n.tr("module.catalog.cm.error_empty_menu_name")
        case .emptyMenuProducts: return L10n.tr("module.catalog.cm.error_empty_menu_products")
        case .menuShape: return "Meniul are un produs principal și produse secundare: unul obligatoriu și cel mult 10 opționale. Același produs nu se repetă."
        case .tooManyGroups: return L10n.tr("module.catalog.cm.error_too_many_groups")
        case .invalidGroup: return L10n.tr("module.catalog.cm.error_invalid_group")
        }
    }
}
