import Foundation

enum ProductRecipePurchasePriceSource: String, Codable, Sendable {
    case local
    case bina

    var label: String {
        switch self {
        case .local: return L10n.tr("products.recipe_price_source_local")
        case .bina: return L10n.tr("products.recipe_price_source_bina")
        }
    }
}

struct ProductRecipeLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let productId: UUID
    let ingredientProductId: UUID
    let numarLinie: Int
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    @SupabaseOptionalDecimal var pretAchizitie: Decimal?
    let pretAchizitieSursa: ProductRecipePurchasePriceSource
    let binaComponentItemId: Int64?
    let createdAt: Date?
    let updatedAt: Date?
    let ingredient: ProductRecipeIngredientRef?

    enum CodingKeys: String, CodingKey {
        case id, cantitate
        case companyId = "company_id"
        case productId = "product_id"
        case ingredientProductId = "ingredient_product_id"
        case numarLinie = "numar_linie"
        case unitateMasura = "unitate_masura"
        case pretAchizitie = "pret_achizitie"
        case pretAchizitieSursa = "pret_achizitie_sursa"
        case binaComponentItemId = "bina_component_item_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case ingredient = "ingredient"
    }

    var lineCost: Decimal? {
        guard let pretAchizitie else { return nil }
        return SupplierFormatting.roundAmount(cantitate * pretAchizitie)
    }
}

struct ProductRecipeIngredientRef: Codable, Hashable, Sendable {
    let id: UUID
    let denumire: String
    let cod: String?
    let unitateMasura: String
    let tip: ProductKind

    enum CodingKeys: String, CodingKey {
        case id, denumire, cod, tip
        case unitateMasura = "unitate_masura"
    }
}

struct ProductRecipeSummary: Sendable {
    let lines: [ProductRecipeLine]

    var totalCost: Decimal? {
        let costs = lines.compactMap(\.lineCost)
        guard costs.count == lines.count, !lines.isEmpty else { return nil }
        return costs.reduce(0, +)
    }
}
