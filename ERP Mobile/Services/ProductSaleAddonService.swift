import Foundation
import Supabase

enum ProductSaleAddonError: LocalizedError {
    case invalidQuantity
    case cannotUseSelf
    case duplicateAddon
    case addonNotFound

    var errorDescription: String? {
        switch self {
        case .invalidQuantity: return L10n.tr("products.sale_addon_error_invalid_quantity")
        case .cannotUseSelf: return L10n.tr("products.sale_addon_error_self")
        case .duplicateAddon: return L10n.tr("products.sale_addon_error_duplicate")
        case .addonNotFound: return L10n.tr("products.sale_addon_error_not_found")
        }
    }
}

enum ProductSaleAddonService {
    private static let client = SupabaseManager.client

    private static let lineSelect = """
        id, company_id, product_id, addon_product_id, cantitate, sort_order, created_at, updated_at, \
        addon:products!product_sale_addons_addon_product_id_fkey(\
        id, denumire, cod, tip, pret_vanzare, cota_tva, unitate_masura)
        """

    static func fetchAddons(productId: UUID) async throws -> [ProductSaleAddon] {
        try await client
            .from("product_sale_addons")
            .select(lineSelect)
            .eq("product_id", value: productId.uuidString)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Adiționale pentru produsele deschise în POS, grupate după produsul părinte.
    static func fetchAddons(productIds: [UUID]) async throws -> [UUID: [ProductSaleAddon]] {
        let ids = Array(Set(productIds))
        guard !ids.isEmpty else { return [:] }
        var rows: [ProductSaleAddon] = []
        var start = 0
        while start < ids.count {
            let end = min(start + 80, ids.count)
            let slice = Array(ids[start..<end])
            let part: [ProductSaleAddon] = try await client
                .from("product_sale_addons")
                .select(lineSelect)
                .in("product_id", values: slice.map(\.uuidString))
                .execute()
                .value
            rows.append(contentsOf: part)
            start = end
        }
        return Dictionary(grouping: rows, by: \.productId).mapValues { list in
            list.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    /// Candidați pentru adițional: articole active din aceeași societate (fără produsul părinte).
    static func fetchAddonCandidates(
        companyId: UUID,
        excludingProductId: UUID,
        excludingAddonIds: Set<UUID>
    ) async throws -> [Product] {
        let products = try await ProductService.fetchProducts(companyId: companyId)
        return products.filter { product in
            product.id != excludingProductId
                && !excludingAddonIds.contains(product.id)
        }
    }

    static func addAddon(
        companyId: UUID,
        productId: UUID,
        addonProductId: UUID,
        cantitate: Decimal = 1
    ) async throws -> ProductSaleAddon {
        guard cantitate > 0 else { throw ProductSaleAddonError.invalidQuantity }
        guard productId != addonProductId else { throw ProductSaleAddonError.cannotUseSelf }

        _ = try await ProductService.fetchProduct(id: addonProductId)

        let existing = try await fetchAddons(productId: productId)
        if existing.contains(where: { $0.addonProductId == addonProductId }) {
            throw ProductSaleAddonError.duplicateAddon
        }

        let nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1

        struct Insert: Encodable {
            let companyId: UUID
            let productId: UUID
            let addonProductId: UUID
            let cantitate: String
            let sortOrder: Int

            enum CodingKeys: String, CodingKey {
                case companyId = "company_id"
                case productId = "product_id"
                case addonProductId = "addon_product_id"
                case cantitate
                case sortOrder = "sort_order"
            }
        }

        let rows: [ProductSaleAddon] = try await client
            .from("product_sale_addons")
            .insert(Insert(
                companyId: companyId,
                productId: productId,
                addonProductId: addonProductId,
                cantitate: NSDecimalNumber(decimal: cantitate).stringValue,
                sortOrder: nextOrder
            ))
            .select(lineSelect)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func updateQuantity(addonId: UUID, cantitate: Decimal) async throws -> ProductSaleAddon {
        guard cantitate > 0 else { throw ProductSaleAddonError.invalidQuantity }

        struct Patch: Encodable {
            let cantitate: String
        }

        let rows: [ProductSaleAddon] = try await client
            .from("product_sale_addons")
            .update(Patch(cantitate: NSDecimalNumber(decimal: cantitate).stringValue))
            .eq("id", value: addonId.uuidString)
            .select(lineSelect)
            .execute()
            .value
        guard let row = rows.first else { throw ProductSaleAddonError.addonNotFound }
        return row
    }

    static func deleteAddon(id: UUID) async throws {
        try await client
            .from("product_sale_addons")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Expandă vânzarea: linie produs + linii adiționale (preț/TVA din fișa fiecăruia).
    static func expandSaleLines(
        parent: Product,
        parentQuantity: Decimal,
        addons: [ProductSaleAddon]
    ) -> [ProductSaleLineDraft] {
        guard parentQuantity > 0 else { return [] }

        var lines: [ProductSaleLineDraft] = [
            ProductSaleLineDraft(
                id: parent.id,
                productId: parent.id,
                denumire: parent.denumire,
                cantitate: parentQuantity,
                pretUnitarCuTva: parent.pretVanzare,
                cotaTva: parent.cotaTva,
                isAddon: false,
                parentProductId: nil
            )
        ]

        for addon in addons.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            guard let ref = addon.addon else { continue }
            let qty = parentQuantity * addon.cantitate
            guard qty > 0 else { continue }
            lines.append(
                ProductSaleLineDraft(
                    id: UUID(),
                    productId: ref.id,
                    denumire: ref.denumire,
                    cantitate: qty,
                    pretUnitarCuTva: ref.pretVanzare,
                    cotaTva: ref.cotaTva,
                    isAddon: true,
                    parentProductId: parent.id
                )
            )
        }
        return lines
    }
}
