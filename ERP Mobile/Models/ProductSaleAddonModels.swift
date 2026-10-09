import Foundation

/// Produs adițional legat de un produs de vânzare (ex. Garantie SGR).
nonisolated struct ProductSaleAddon: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let productId: UUID
    let addonProductId: UUID
    var cantitate: Decimal
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?
    let addon: ProductSaleAddonRef?

    enum CodingKeys: String, CodingKey {
        case id, cantitate
        case companyId = "company_id"
        case productId = "product_id"
        case addonProductId = "addon_product_id"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case addon
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        companyId = try c.decode(UUID.self, forKey: .companyId)
        productId = try c.decode(UUID.self, forKey: .productId)
        addonProductId = try c.decode(UUID.self, forKey: .addonProductId)
        cantitate = try c.decode(SupabaseDecimal.self, forKey: .cantitate).wrappedValue
        sortOrder = try c.decode(Int.self, forKey: .sortOrder)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        addon = try c.decodeIfPresent(ProductSaleAddonRef.self, forKey: .addon)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(companyId, forKey: .companyId)
        try c.encode(productId, forKey: .productId)
        try c.encode(addonProductId, forKey: .addonProductId)
        try c.encode(SupabaseDecimal(wrappedValue: cantitate), forKey: .cantitate)
        try c.encode(sortOrder, forKey: .sortOrder)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(addon, forKey: .addon)
    }
}

nonisolated struct ProductSaleAddonRef: Codable, Hashable, Sendable {
    let id: UUID
    let denumire: String
    let cod: String?
    let tip: ProductKind
    var pretVanzare: Decimal
    var cotaTva: Decimal
    let unitateMasura: String

    enum CodingKeys: String, CodingKey {
        case id, denumire, cod, tip
        case pretVanzare = "pret_vanzare"
        case cotaTva = "cota_tva"
        case unitateMasura = "unitate_masura"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        denumire = try c.decode(String.self, forKey: .denumire)
        cod = try c.decodeIfPresent(String.self, forKey: .cod)
        tip = try c.decode(ProductKind.self, forKey: .tip)
        pretVanzare = try c.decode(SupabaseDecimal.self, forKey: .pretVanzare).wrappedValue
        cotaTva = try c.decode(SupabaseDecimal.self, forKey: .cotaTva).wrappedValue
        unitateMasura = try c.decode(String.self, forKey: .unitateMasura)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(denumire, forKey: .denumire)
        try c.encodeIfPresent(cod, forKey: .cod)
        try c.encode(tip, forKey: .tip)
        try c.encode(SupabaseDecimal(wrappedValue: pretVanzare), forKey: .pretVanzare)
        try c.encode(SupabaseDecimal(wrappedValue: cotaTva), forKey: .cotaTva)
        try c.encode(unitateMasura, forKey: .unitateMasura)
    }
}

/// Linie de vânzare după expandarea adiționalelor (pentru POS / bon fiscal).
nonisolated struct ProductSaleLineDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    let productId: UUID
    let denumire: String
    let cantitate: Decimal
    /// Preț unitar cu TVA inclus (din fișa produsului).
    let pretUnitarCuTva: Decimal
    let cotaTva: Decimal
    let isAddon: Bool
    let parentProductId: UUID?

    var lineTotalCuTva: Decimal {
        cantitate * pretUnitarCuTva
    }
}
