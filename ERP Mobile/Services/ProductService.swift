import Foundation
import Supabase

private struct ProductInsert: Encodable {
    let companyId: UUID
    let cod: String?
    let codBare: String?
    let denumire: String
    let descriere: String?
    let unitateMasura: String
    let unitateAchizitie: String?
    let factorConversie: Decimal
    let tip: String
    let cpv: String?
    let isActive: Bool
    let inCatalog: Bool
    let inStockSheet: Bool
    let hasRecipe: Bool
    let cotaTva: Decimal
    let pretVanzare: Decimal
    let imagineUrl: String?

    enum CodingKeys: String, CodingKey {
        case cod, denumire, descriere, cpv, tip
        case companyId = "company_id"
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
        case unitateAchizitie = "unitate_achizitie"
        case factorConversie = "factor_conversie"
        case isActive = "is_active"
        case inCatalog = "in_catalog"
        case inStockSheet = "in_stock_sheet"
        case hasRecipe = "has_recipe"
        case cotaTva = "cota_tva"
        case pretVanzare = "pret_vanzare"
        case imagineUrl = "imagine_url"
    }
}

private struct ProductImportEnrichment: Encodable {
    let codBare: String?

    enum CodingKeys: String, CodingKey {
        case codBare = "cod_bare"
    }
}

private struct ProductCatalogSettingsPatch: Encodable {
    let inCatalog: Bool?
    let inStockSheet: Bool?
    let hasRecipe: Bool?

    enum CodingKeys: String, CodingKey {
        case inCatalog = "in_catalog"
        case inStockSheet = "in_stock_sheet"
        case hasRecipe = "has_recipe"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let inCatalog {
            try container.encode(inCatalog, forKey: .inCatalog)
        }
        if let inStockSheet {
            try container.encode(inStockSheet, forKey: .inStockSheet)
        }
        if let hasRecipe {
            try container.encode(hasRecipe, forKey: .hasRecipe)
        }
    }
}

private struct ProductDetailsPatch: Encodable {
    let denumire: String
    let cod: String?
    let codBare: String?
    let unitateMasura: String
    let unitateAchizitie: String?
    let factorConversie: Decimal
    let tip: String

    enum CodingKeys: String, CodingKey {
        case denumire, cod, tip
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
        case unitateAchizitie = "unitate_achizitie"
        case factorConversie = "factor_conversie"
    }
}

private struct ProductImagePatch: Encodable {
    let imagineUrl: String?

    enum CodingKeys: String, CodingKey {
        case imagineUrl = "imagine_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let imagineUrl {
            try container.encode(imagineUrl, forKey: .imagineUrl)
        } else {
            try container.encodeNil(forKey: .imagineUrl)
        }
    }
}

private struct ProductArticleCategoryPatch: Encodable {
    let tip: String
    let inCatalog: Bool?

    enum CodingKeys: String, CodingKey {
        case tip
        case inCatalog = "in_catalog"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tip, forKey: .tip)
        if let inCatalog {
            try container.encode(inCatalog, forKey: .inCatalog)
        }
    }
}

private struct ProductPricingPatch: Encodable {
    let cotaTva: Decimal?
    let pretVanzare: Decimal?

    enum CodingKeys: String, CodingKey {
        case cotaTva = "cota_tva"
        case pretVanzare = "pret_vanzare"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let cotaTva {
            try container.encode(cotaTva, forKey: .cotaTva)
        }
        if let pretVanzare {
            try container.encode(pretVanzare, forKey: .pretVanzare)
        }
    }
}

enum ProductService {
    nonisolated static let garantieSGRProductName = "Garantie SGR"
    nonisolated static let garantieProductName = "Garantie"

    private static let client = SupabaseManager.client

    nonisolated static func isGarantieProductName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: garantieProductName, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func resolvedProductName(for denumire: String) -> String {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        return isGarantieProductName(trimmed) ? garantieSGRProductName : trimmed
    }

    /// Produsul „Garantie SGR” din catalog, folosit doar pentru liniile de garanție.
    nonisolated static func isCanonicalGarantieSGRProduct(_ product: Product) -> Bool {
        product.denumire.localizedCaseInsensitiveCompare(garantieSGRProductName) == .orderedSame
    }

    /// Factura a legat greșit produsul (ex. băuturi „DOZA SGR”) la articolul Garantie SGR.
    nonisolated static func isMislinkedGarantieSGRProduct(_ product: Product, lineName: String) -> Bool {
        isCanonicalGarantieSGRProduct(product) && !isGarantieProductName(lineName)
    }

    nonisolated static func resolvedProductForNIRLine(
        line: SupplierInvoiceLine,
        productsById: [UUID: Product],
        allProducts: [Product] = []
    ) -> Product? {
        guard let linked = productsById[line.productId] else {
            return nil
        }

        guard isMislinkedGarantieSGRProduct(linked, lineName: line.denumire) else {
            return linked
        }

        let trimmedName = line.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = EFacturaUnitCode.normalize(line.unitateMasura)
        if let match = allProducts.first(where: {
            $0.denumire.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                && (
                    EFacturaUnitCode.normalize($0.unitateMasura) == trimmedUnit
                    || StockUnitConversion.matchesPurchaseUnit($0, invoiceUnit: trimmedUnit)
                )
        }) {
            return match
        }

        return linked
    }

    static func fetchProducts(
        companyId: UUID,
        inCatalog: Bool? = nil,
        inStockSheet: Bool? = nil,
        hasRecipe: Bool? = nil
    ) async throws -> [Product] {
        return try await SupabasePaging.fetchAll { from, to in
            var query = client
                .from("products")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("is_active", value: true)

            if let inCatalog {
                query = query.eq("in_catalog", value: inCatalog)
            }
            if let inStockSheet {
                query = query.eq("in_stock_sheet", value: inStockSheet)
            }
            if let hasRecipe {
                query = query.eq("has_recipe", value: hasRecipe)
            }

            return try await query
                .order("denumire", ascending: true)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
        }
    }

    static func fetchProducts(ids: [UUID]) async throws -> [Product] {
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return [] }
        var all: [Product] = []
        for chunk in uniqueIds.chunked(into: 200) {
            let rows: [Product] = try await client
                .from("products")
                .select()
                .in("id", values: chunk.map(\.uuidString))
                .execute()
                .value
            all.append(contentsOf: rows)
        }
        return all
    }

    static func fetchProduct(id: UUID) async throws -> Product {
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func updateCatalogSettings(
        productId: UUID,
        inCatalog: Bool? = nil,
        inStockSheet: Bool? = nil,
        hasRecipe: Bool? = nil
    ) async throws -> Product {
        let payload = ProductCatalogSettingsPatch(
            inCatalog: inCatalog,
            inStockSheet: inStockSheet,
            hasRecipe: hasRecipe
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func updateImage(productId: UUID, imagineUrl: String?) async throws -> Product {
        let payload = ProductImagePatch(imagineUrl: emptyToNil(imagineUrl))
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func uploadImage(
        companyId: UUID,
        productId: UUID,
        imageData: Data,
        contentType: String,
        previousImagineUrl: String?
    ) async throws -> Product {
        await ProductImageService.deleteIfStored(previousImagineUrl)
        let publicURL = try await ProductImageService.upload(
            companyId: companyId,
            productId: productId,
            imageData: imageData,
            contentType: contentType
        )
        return try await updateImage(productId: productId, imagineUrl: publicURL)
    }

    static func removeImage(productId: UUID, imagineUrl: String?) async throws -> Product {
        await ProductImageService.deleteIfStored(imagineUrl)
        return try await updateImage(productId: productId, imagineUrl: nil)
    }

    static func updateDetails(
        productId: UUID,
        companyId: UUID,
        input: ProductUpdateInput
    ) async throws -> Product {
        let trimmedName = input.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProductCreateError.missingName }

        if let barcode = normalizedBarcode(input.codBare),
           let existing = try await findProductByBarcode(companyId: companyId, barcode: barcode),
           existing.id != productId {
            throw ProductCreateError.duplicateBarcode(barcode)
        }

        let payload = ProductDetailsPatch(
            denumire: resolvedProductName(for: trimmedName),
            cod: emptyToNil(input.cod?.trimmingCharacters(in: .whitespacesAndNewlines)),
            codBare: normalizedBarcode(input.codBare),
            unitateMasura: normalizedUnit(input.unitateMasura),
            unitateAchizitie: emptyToNil(input.unitateAchizitie).map { normalizedUnit($0) },
            factorConversie: input.factorConversie > 0 ? input.factorConversie : 1,
            tip: input.tip.rawValue
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func deletionBlocker(productId: UUID) async throws -> ProductDeleteBlocker? {
        struct IdRow: Decodable { let id: UUID }

        let movements: [IdRow] = try await client
            .from("stock_movements")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !movements.isEmpty { return .hasStockMovements }

        let invoiceLines: [IdRow] = try await client
            .from("supplier_invoice_lines")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !invoiceLines.isEmpty { return .hasInvoiceLines }

        let inventoryLines: [IdRow] = try await client
            .from("physical_inventory_lines")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !inventoryLines.isEmpty { return .hasPhysicalInventoryLines }

        return nil
    }

    static func deleteProduct(productId: UUID) async throws {
        if let blocker = try await deletionBlocker(productId: productId) {
            throw ProductDeleteError.blocked(blocker)
        }
        try await client
            .from("products")
            .delete()
            .eq("id", value: productId.uuidString)
            .execute()
    }

    static func lookup(forBarcode barcode: String) async -> BarcodeProductLookup? {
        guard let normalized = normalizedBarcode(barcode) else { return nil }
        return await BarcodeLookupService.lookup(barcode: normalized)
    }

    static func lookupName(forBarcode barcode: String) async -> String? {
        await lookup(forBarcode: barcode)?.resolvedName
    }

    static func lookupImageOnline(name: String, barcode: String?) async -> String? {
        await ProductImageLookupService.findBestImage(name: name, barcode: barcode)
    }

    static func updateArticleCategory(productId: UUID, tip: ProductKind) async throws -> Product {
        let payload = ProductArticleCategoryPatch(
            tip: tip.rawValue,
            inCatalog: tip.impliesInCatalog ? true : nil
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        if let product = rows.first {
            return product
        }
        return try await fetchProduct(id: productId)
    }

    static func updateKind(productId: UUID, tip: ProductKind) async throws -> Product {
        try await updateArticleCategory(productId: productId, tip: tip)
    }

    static func updatePricing(
        productId: UUID,
        cotaTva: Decimal? = nil,
        pretVanzare: Decimal? = nil,
        isVatPayer: Bool
    ) async throws -> Product {
        var validatedVat: Decimal?
        if let cotaTva {
            guard let value = validateVatRate(cotaTva, isVatPayer: isVatPayer) else {
                throw ProductCreateError.invalidVatRate
            }
            validatedVat = value
        }
        let payload = ProductPricingPatch(cotaTva: validatedVat, pretVanzare: pretVanzare)
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        if let product = rows.first {
            return product
        }
        return try await fetchProduct(id: productId)
    }

    static func setAllProductsVatRate(companyId: UUID, cotaTva: Decimal) async throws {
        let rate = roundCurrency(cotaTva)
        struct Patch: Encodable {
            let cotaTva: Decimal
            enum CodingKeys: String, CodingKey {
                case cotaTva = "cota_tva"
            }
        }
        try await client
            .from("products")
            .update(Patch(cotaTva: rate))
            .eq("company_id", value: companyId.uuidString)
            .execute()
    }

    static func parseVatRate(_ text: String, isVatPayer: Bool) -> Decimal? {
        guard let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 2) else { return nil }
        guard ProductVATRates.isValidRate(roundCurrency(value), isVatPayer: isVatPayer) else { return nil }
        return roundCurrency(value)
    }

    static func validateVatRate(_ rate: Decimal, isVatPayer: Bool) -> Decimal? {
        let rounded = roundCurrency(rate)
        guard ProductVATRates.isValidRate(rounded, isVatPayer: isVatPayer) else { return nil }
        return rounded
    }

    static func defaultVatRate(isVatPayer: Bool) -> Decimal {
        ProductVATRates.defaultRate(isVatPayer: isVatPayer)
    }

    static func parseSalePrice(_ text: String) -> Decimal? {
        guard let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 4) else { return nil }
        guard value >= 0 else { return nil }
        return roundCurrency(value)
    }

    static func roundCurrency(_ value: Decimal) -> Decimal {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded
    }

    static func findProductByBarcode(companyId: UUID, barcode: String) async throws -> Product? {
        guard let normalized = normalizedBarcode(barcode) else { return nil }
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("is_active", value: true)
            .eq("cod_bare", value: normalized)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func createProduct(
        companyId: UUID,
        input: ProductCreateInput,
        isVatPayer: Bool
    ) async throws -> Product {
        let trimmedName = input.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProductCreateError.missingName }

        if let barcode = normalizedBarcode(input.codBare),
           try await findProductByBarcode(companyId: companyId, barcode: barcode) != nil {
            throw ProductCreateError.duplicateBarcode(barcode)
        }

        guard let cotaTva = validateVatRate(roundCurrency(input.cotaTva), isVatPayer: isVatPayer) else {
            throw ProductCreateError.invalidVatRate
        }
        let pretVanzare = roundCurrency(input.pretVanzare)
        guard pretVanzare >= 0 else { throw ProductCreateError.invalidSalePrice }

        let payload = ProductInsert(
            companyId: companyId,
            cod: emptyToNil(input.cod?.trimmingCharacters(in: .whitespacesAndNewlines)),
            codBare: normalizedBarcode(input.codBare),
            denumire: resolvedProductName(for: trimmedName),
            descriere: emptyToNil(input.descriere),
            unitateMasura: normalizedUnit(input.unitateMasura),
            unitateAchizitie: emptyToNil(input.unitateAchizitie).map { normalizedUnit($0) },
            factorConversie: input.factorConversie > 0 ? input.factorConversie : 1,
            tip: input.tip.rawValue,
            cpv: nil,
            isActive: true,
            inCatalog: input.inCatalog,
            inStockSheet: input.inStockSheet,
            hasRecipe: input.hasRecipe,
            cotaTva: cotaTva,
            pretVanzare: pretVanzare,
            imagineUrl: emptyToNil(input.imagineUrl)
        )
        let rows: [Product] = try await client
            .from("products")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func createProductFromBarcode(
        companyId: UUID,
        barcode: String,
        isVatPayer: Bool
    ) async throws -> Product {
        guard let normalized = normalizedBarcode(barcode) else {
            throw ProductCreateError.missingName
        }
        if let existing = try await findProductByBarcode(companyId: companyId, barcode: normalized) {
            return existing
        }

        let lookup = await lookup(forBarcode: normalized)
        let resolvedName = lookup?.resolvedName ?? defaultName(forBarcode: normalized)
        return try await createProduct(
            companyId: companyId,
            input: ProductCreateInput(
                denumire: resolvedName,
                codBare: normalized,
                unitateMasura: "Buc.",
                tip: .marfa,
                cotaTva: defaultVatRate(isVatPayer: isVatPayer),
                imagineUrl: lookup?.imageURL
            ),
            isVatPayer: isVatPayer
        )
    }

    static func defaultName(forBarcode barcode: String) -> String {
        L10n.tr("module.products.default_name_from_barcode", barcode)
    }

    static func findOrCreateProduct(
        companyId: UUID,
        cod: String?,
        codBare: String?,
        denumire: String,
        descriere: String?,
        unitateMasura: String,
        cpv: String?,
        products: inout [Product]
    ) async throws -> (product: Product, created: Bool) {
        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let isGarantieProduct = isGarantieProductName(trimmedName)
        let effectiveName = isGarantieProduct ? garantieSGRProductName : trimmedName
        let invoiceUnit = isGarantieProduct ? ProductStockUnit.bucata.rawValue : normalizedUnit(unitateMasura)
        let pack = InvoiceNamePackHint.parse(effectiveName)
        let pieceLikeInvoice = InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit)
        let resolvedStock = ProductStockUnit.resolve(invoiceUnit)
        let stockUnit: String
        let purchaseUnit: String?
        let factorConversie: Decimal
        if isGarantieProduct {
            stockUnit = ProductStockUnit.bucata.rawValue
            purchaseUnit = nil
            factorConversie = 1
        } else if pieceLikeInvoice, let pack {
            stockUnit = pack.unit.rawValue
            purchaseUnit = invoiceUnit
            factorConversie = pack.quantity
        } else if let resolvedStock {
            stockUnit = resolvedStock.rawValue
            purchaseUnit = nil
            factorConversie = 1
        } else {
            stockUnit = ProductStockUnit.bucata.rawValue
            purchaseUnit = invoiceUnit
            factorConversie = 1
        }
        let trimmedCod = emptyToNil(cod)
        let trimmedBarcode = normalizedBarcode(codBare)

        if !isGarantieProduct {
            if let match = try await existingProduct(
                companyId: companyId,
                cod: trimmedCod,
                barcode: nil,
                products: &products
            ) {
                let enriched = try await enrichProductFromImport(
                    product: match,
                    codBare: trimmedBarcode,
                    products: &products
                )
                return (enriched, false)
            }

            if let match = try await existingProduct(
                companyId: companyId,
                cod: nil,
                barcode: trimmedBarcode,
                products: &products
            ) {
                return (match, false)
            }
        }

        if let match = products.first(where: {
            $0.denumire.localizedCaseInsensitiveCompare(effectiveName) == .orderedSame
                && (
                    isGarantieProduct
                    || normalizedUnit($0.unitateMasura) == invoiceUnit
                    || StockUnitConversion.matchesPurchaseUnit($0, invoiceUnit: invoiceUnit)
                    || (
                        ProductStockUnit.resolve($0.unitateMasura) != nil
                        && InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit)
                        && !StockUnitConversion.unitsMatch($0.unitateMasura, invoiceUnit)
                    )
                    || (pieceLikeInvoice && pack != nil)
                )
        }) {
            let enriched = try await enrichProductFromImport(
                product: match,
                codBare: trimmedBarcode,
                products: &products
            )
            return (enriched, false)
        }

        let payload = ProductInsert(
            companyId: companyId,
            cod: isGarantieProduct ? nil : trimmedCod,
            codBare: isGarantieProduct ? nil : emptyToNil(trimmedBarcode),
            denumire: effectiveName,
            descriere: isGarantieProduct ? nil : emptyToNil(descriere),
            unitateMasura: stockUnit,
            unitateAchizitie: purchaseUnit,
            factorConversie: factorConversie,
            tip: ProductKind.materiePrima.rawValue,
            cpv: isGarantieProduct ? nil : emptyToNil(cpv),
            isActive: true,
            inCatalog: false,
            inStockSheet: false,
            hasRecipe: false,
            cotaTva: 21,
            pretVanzare: 0,
            imagineUrl: nil
        )
        do {
            let rows: [Product] = try await client
                .from("products")
                .insert(payload)
                .select()
                .execute()
                .value
            guard let product = rows.first else { throw ServiceError.invalidResponse }
            remember(product, in: &products)
            return (product, true)
        } catch {
            guard isProductUniqueConstraintViolation(error),
                  let existing = try await existingProduct(
                    companyId: companyId,
                    cod: isGarantieProduct ? nil : trimmedCod,
                    barcode: isGarantieProduct ? nil : trimmedBarcode,
                    products: &products
                  ) else {
                throw error
            }
            let enriched = try await enrichProductFromImport(
                product: existing,
                codBare: trimmedBarcode,
                products: &products
            )
            return (enriched, false)
        }
    }

    nonisolated static func shouldSkipNIRProductKindUpdate(lineName: String) -> Bool {
        isGarantieProductName(lineName)
    }

    nonisolated static func isProductUniqueConstraintViolation(_ error: Error) -> Bool {
        if let postgrest = error as? PostgrestError, postgrest.code == "23505" {
            return true
        }
        let text = [
            (error as? PostgrestError)?.code,
            (error as? PostgrestError)?.message,
            (error as? PostgrestError)?.detail,
            error.localizedDescription
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        return text.contains("duplicate key")
            || text.contains("unique constraint")
            || text.contains("idx_products_company_cod")
            || text.contains("idx__products_company_cod")
    }

    private static func existingProduct(
        companyId: UUID,
        cod: String?,
        barcode: String?,
        products: inout [Product]
    ) async throws -> Product? {
        if let cod, !cod.isEmpty {
            if let match = products.first(where: {
                $0.cod?.caseInsensitiveCompare(cod) == .orderedSame
            }) {
                return match
            }
            if let match = try await findProductByCode(companyId: companyId, code: cod) {
                remember(match, in: &products)
                return match
            }
        }

        if let barcode, !barcode.isEmpty {
            if let match = products.first(where: {
                $0.codBare?.caseInsensitiveCompare(barcode) == .orderedSame
            }) {
                return match
            }
            if let match = try await findProductByBarcodeAnyStatus(companyId: companyId, barcode: barcode) {
                remember(match, in: &products)
                return match
            }
        }

        return nil
    }

    private static func findProductByCode(companyId: UUID, code: String) async throws -> Product? {
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("cod", value: code)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private static func findProductByBarcodeAnyStatus(companyId: UUID, barcode: String) async throws -> Product? {
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("cod_bare", value: barcode)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private static func remember(_ product: Product, in products: inout [Product]) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.append(product)
        }
    }

    private static func normalizedUnit(_ value: String) -> String {
        EFacturaUnitCode.normalize(value)
    }

    private static func normalizedBarcode(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: " ", with: "")
    }

    private static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private static func enrichProductFromImport(
        product: Product,
        codBare: String?,
        products: inout [Product]
    ) async throws -> Product {
        guard isBlank(product.codBare), let codBare = emptyToNil(codBare) else {
            return product
        }

        let payload = ProductImportEnrichment(codBare: codBare)
        do {
            let rows: [Product] = try await client
                .from("products")
                .update(payload)
                .eq("id", value: product.id.uuidString)
                .select()
                .execute()
                .value
            guard let updated = rows.first else { return product }
            remember(updated, in: &products)
            return updated
        } catch {
            if isProductUniqueConstraintViolation(error) {
                return product
            }
            throw error
        }
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
