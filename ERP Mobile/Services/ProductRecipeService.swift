import Foundation
import Supabase

enum ProductRecipeError: LocalizedError {
    case invalidQuantity
    case invalidUnit
    case duplicateIngredient
    case ingredientNotAllowed
    case cannotUseSelfAsIngredient

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return L10n.tr("products.recipe_error_invalid_quantity")
        case .invalidUnit:
            return L10n.tr("products.recipe_error_invalid_unit")
        case .duplicateIngredient:
            return L10n.tr("products.recipe_error_duplicate_ingredient")
        case .ingredientNotAllowed:
            return L10n.tr("products.recipe_error_ingredient_not_allowed")
        case .cannotUseSelfAsIngredient:
            return L10n.tr("products.recipe_error_self_ingredient")
        }
    }
}

enum ProductRecipeService {
    private static let client = SupabaseManager.client

    private static let lineSelect = """
        id, company_id, product_id, ingredient_product_id, numar_linie, cantitate, unitate_masura,
        pret_achizitie, pret_achizitie_sursa, bina_component_item_id, created_at, updated_at,
        ingredient:products!product_recipe_lines_ingredient_product_id_fkey(id, denumire, cod, unitate_masura, tip)
        """

    static let allowedIngredientKinds: Set<ProductKind> = [
        .materiePrima,
        .ambalaj,
        .materialeConsumabile,
        .marfa,
    ]

    static func fetchRecipeLines(productId: UUID) async throws -> [ProductRecipeLine] {
        try await client
            .from("product_recipe_lines")
            .select(lineSelect)
            .eq("product_id", value: productId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
    }

    static func fetchRecipeSummary(productId: UUID) async throws -> ProductRecipeSummary {
        let lines = try await fetchRecipeLines(productId: productId)
        return ProductRecipeSummary(lines: lines)
    }

    static func fetchIngredientCandidates(
        companyId: UUID,
        productId: UUID,
        existingIngredientIds: Set<UUID>,
        additionallyAllowedIngredientIds: Set<UUID> = []
    ) async throws -> [Product] {
        let products = try await ProductService.fetchProducts(companyId: companyId)
        return products
            .filter { candidate in
                candidate.id != productId
                    && candidate.isActive
                    && Self.allowedIngredientKinds.contains(candidate.tip)
                    && (
                        !existingIngredientIds.contains(candidate.id)
                            || additionallyAllowedIngredientIds.contains(candidate.id)
                    )
            }
            .sorted {
                $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending
            }
    }

    static func normalizedUnit(_ value: String) -> String {
        EFacturaUnitCode.normalize(value)
    }

    static func addLine(
        companyId: UUID,
        productId: UUID,
        ingredientProductId: UUID,
        cantitate: Decimal,
        unitateMasura: String
    ) async throws -> ProductRecipeLine {
        guard cantitate > 0 else { throw ProductRecipeError.invalidQuantity }
        let trimmedUnit = normalizedUnit(unitateMasura)
        guard !trimmedUnit.isEmpty else { throw ProductRecipeError.invalidUnit }
        guard productId != ingredientProductId else { throw ProductRecipeError.cannotUseSelfAsIngredient }

        let ingredient = try await ProductService.fetchProduct(id: ingredientProductId)
        guard allowedIngredientKinds.contains(ingredient.tip) else {
            throw ProductRecipeError.ingredientNotAllowed
        }

        let existing = try await fetchRecipeLines(productId: productId)
        if existing.contains(where: { $0.ingredientProductId == ingredientProductId }) {
            throw ProductRecipeError.duplicateIngredient
        }

        let nextLineNumber = (existing.map(\.numarLinie).max() ?? 0) + 1
        let (pretAchizitie, sursa) = try await resolvedPurchasePrice(
            companyId: companyId,
            ingredientProductId: ingredientProductId
        )

        struct Insert: Encodable {
            let companyId: UUID
            let productId: UUID
            let ingredientProductId: UUID
            let numarLinie: Int
            let cantitate: Decimal
            let unitateMasura: String
            let pretAchizitie: Decimal?
            let pretAchizitieSursa: String

            enum CodingKeys: String, CodingKey {
                case cantitate
                case companyId = "company_id"
                case productId = "product_id"
                case ingredientProductId = "ingredient_product_id"
                case numarLinie = "numar_linie"
                case unitateMasura = "unitate_masura"
                case pretAchizitie = "pret_achizitie"
                case pretAchizitieSursa = "pret_achizitie_sursa"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(companyId, forKey: .companyId)
                try container.encode(productId, forKey: .productId)
                try container.encode(ingredientProductId, forKey: .ingredientProductId)
                try container.encode(numarLinie, forKey: .numarLinie)
                try container.encode(cantitate, forKey: .cantitate)
                try container.encode(unitateMasura, forKey: .unitateMasura)
                try container.encode(pretAchizitieSursa, forKey: .pretAchizitieSursa)
                if let pretAchizitie {
                    try container.encode(pretAchizitie, forKey: .pretAchizitie)
                } else {
                    try container.encodeNil(forKey: .pretAchizitie)
                }
            }
        }

        let payload = Insert(
            companyId: companyId,
            productId: productId,
            ingredientProductId: ingredientProductId,
            numarLinie: nextLineNumber,
            cantitate: cantitate,
            unitateMasura: trimmedUnit,
            pretAchizitie: pretAchizitie,
            pretAchizitieSursa: sursa.rawValue
        )

        let rows: [ProductRecipeLine] = try await client
            .from("product_recipe_lines")
            .insert(payload)
            .select(lineSelect)
            .execute()
            .value
        guard let line = rows.first else { throw ServiceError.invalidResponse }

        _ = try await ProductService.updateCatalogSettings(productId: productId, hasRecipe: true)
        return line
    }

    static func updateLine(
        lineId: UUID,
        productId: UUID,
        companyId: UUID,
        ingredientProductId: UUID,
        cantitate: Decimal,
        unitateMasura: String
    ) async throws -> ProductRecipeLine {
        guard cantitate > 0 else { throw ProductRecipeError.invalidQuantity }
        let trimmedUnit = normalizedUnit(unitateMasura)
        guard !trimmedUnit.isEmpty else { throw ProductRecipeError.invalidUnit }
        guard productId != ingredientProductId else { throw ProductRecipeError.cannotUseSelfAsIngredient }

        let ingredient = try await ProductService.fetchProduct(id: ingredientProductId)
        guard allowedIngredientKinds.contains(ingredient.tip) else {
            throw ProductRecipeError.ingredientNotAllowed
        }

        let existing = try await fetchRecipeLines(productId: productId)
        if existing.contains(where: { $0.ingredientProductId == ingredientProductId && $0.id != lineId }) {
            throw ProductRecipeError.duplicateIngredient
        }

        let (pretAchizitie, sursa) = try await resolvedPurchasePrice(
            companyId: companyId,
            ingredientProductId: ingredientProductId
        )

        struct Patch: Encodable {
            let ingredientProductId: UUID
            let cantitate: Decimal
            let unitateMasura: String
            let pretAchizitie: Decimal?
            let pretAchizitieSursa: String
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case cantitate
                case ingredientProductId = "ingredient_product_id"
                case unitateMasura = "unitate_masura"
                case pretAchizitie = "pret_achizitie"
                case pretAchizitieSursa = "pret_achizitie_sursa"
                case updatedAt = "updated_at"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(ingredientProductId, forKey: .ingredientProductId)
                try container.encode(cantitate, forKey: .cantitate)
                try container.encode(unitateMasura, forKey: .unitateMasura)
                try container.encode(pretAchizitieSursa, forKey: .pretAchizitieSursa)
                try container.encode(updatedAt, forKey: .updatedAt)
                if let pretAchizitie {
                    try container.encode(pretAchizitie, forKey: .pretAchizitie)
                } else {
                    try container.encodeNil(forKey: .pretAchizitie)
                }
            }
        }

        let rows: [ProductRecipeLine] = try await client
            .from("product_recipe_lines")
            .update(Patch(
                ingredientProductId: ingredientProductId,
                cantitate: cantitate,
                unitateMasura: trimmedUnit,
                pretAchizitie: pretAchizitie,
                pretAchizitieSursa: sursa.rawValue,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: lineId.uuidString)
            .select(lineSelect)
            .execute()
            .value
        guard let line = rows.first else { throw ServiceError.invalidResponse }
        return line
    }

    static func deleteLine(lineId: UUID, productId: UUID) async throws {
        try await client
            .from("product_recipe_lines")
            .delete()
            .eq("id", value: lineId.uuidString)
            .execute()

        let remaining = try await fetchRecipeLines(productId: productId)
        if remaining.isEmpty {
            _ = try await ProductService.updateCatalogSettings(productId: productId, hasRecipe: false)
        }
    }

    static func resolveLocalPurchasePrice(
        companyId: UUID,
        productId: UUID
    ) async throws -> Decimal? {
        struct PriceRow: Decodable {
            @SupabaseDecimal var pretUnitar: Decimal

            enum CodingKeys: String, CodingKey {
                case pretUnitar = "pret_unitar"
            }
        }

        let rows: [PriceRow] = try await client
            .from("supplier_invoice_lines")
            .select("pret_unitar, supplier_invoices!inner(data_factura)")
            .eq("company_id", value: companyId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .order("supplier_invoices(data_factura)", ascending: false)
            .limit(1)
            .execute()
            .value

        return rows.first?.pretUnitar
    }

    static func fetchLatestPurchasePrices(companyId: UUID) async throws -> [UUID: Decimal] {
        struct PriceRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var pretUnitar: Decimal

            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case pretUnitar = "pret_unitar"
            }
        }

        let rows: [PriceRow] = try await client
            .from("supplier_invoice_lines")
            .select("product_id, pret_unitar, supplier_invoices!inner(data_factura)")
            .eq("company_id", value: companyId.uuidString)
            .order("supplier_invoices(data_factura)", ascending: false)
            .execute()
            .value

        var result: [UUID: Decimal] = [:]
        for row in rows where result[row.productId] == nil {
            result[row.productId] = row.pretUnitar
        }
        return result
    }

    static func refreshPurchasePrices(
        companyId: UUID,
        productId: UUID
    ) async throws -> [ProductRecipeLine] {
        let lines = try await fetchRecipeLines(productId: productId)
        guard !lines.isEmpty else { return lines }

        var updated: [ProductRecipeLine] = []
        for line in lines {
            if let localPrice = try await resolveLocalPurchasePrice(
                companyId: companyId,
                productId: line.ingredientProductId
            ) {
                let refreshed = try await updatePurchasePrice(
                    lineId: line.id,
                    pretAchizitie: localPrice,
                    sursa: .local
                )
                updated.append(refreshed)
            } else {
                updated.append(line)
            }
        }
        return updated
    }

    private static func resolvedPurchasePrice(
        companyId: UUID,
        ingredientProductId: UUID
    ) async throws -> (Decimal?, ProductRecipePurchasePriceSource) {
        if let localPrice = try await resolveLocalPurchasePrice(
            companyId: companyId,
            productId: ingredientProductId
        ) {
            return (localPrice, .local)
        }
        return (nil, .local)
    }

    private static func updatePurchasePrice(
        lineId: UUID,
        pretAchizitie: Decimal,
        sursa: ProductRecipePurchasePriceSource
    ) async throws -> ProductRecipeLine {
        struct Patch: Encodable {
            let pretAchizitie: Decimal
            let pretAchizitieSursa: String
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case pretAchizitie = "pret_achizitie"
                case pretAchizitieSursa = "pret_achizitie_sursa"
                case updatedAt = "updated_at"
            }
        }

        let payload = Patch(
            pretAchizitie: pretAchizitie,
            pretAchizitieSursa: sursa.rawValue,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )

        let rows: [ProductRecipeLine] = try await client
            .from("product_recipe_lines")
            .update(payload)
            .eq("id", value: lineId.uuidString)
            .select(lineSelect)
            .execute()
            .value
        guard let line = rows.first else { throw ServiceError.invalidResponse }
        return line
    }

    static func fetchProductionCosts(companyId: UUID) async throws -> [UUID: Decimal] {
        struct LineCostRow: Decodable {
            let productId: UUID
            @SupabaseDecimal var cantitate: Decimal
            @SupabaseOptionalDecimal var pretAchizitie: Decimal?

            enum CodingKeys: String, CodingKey {
                case productId = "product_id"
                case cantitate
                case pretAchizitie = "pret_achizitie"
            }
        }

        let rows: [LineCostRow] = try await client
            .from("product_recipe_lines")
            .select("product_id, cantitate, pret_achizitie")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value

        var result: [UUID: Decimal] = [:]
        for (productId, productLines) in Dictionary(grouping: rows, by: \.productId) {
            let lineCosts = productLines.compactMap { row -> Decimal? in
                guard let pretAchizitie = row.pretAchizitie else { return nil }
                return SupplierFormatting.roundAmount(row.cantitate * pretAchizitie)
            }
            guard lineCosts.count == productLines.count, !productLines.isEmpty else { continue }
            result[productId] = lineCosts.reduce(0, +)
        }
        return result
    }
}
