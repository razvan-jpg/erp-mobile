import Foundation

enum ProductKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case materiePrima = "materie_prima"
    case produsFinit = "produs_finit"
    case marfa
    case ambalaj
    case materialeConsumabile = "materiale_consumabile"
    case materialeCuratenie = "materiale_curatenie"
    case birotica
    case servicii
    case obiectInventar = "obiect_inventar"
    case garantie

    var id: String { rawValue }

    /// Categorii selectabile pe fișa articolului și în NIR.
    static let articleCategories: [ProductKind] = [
        .marfa,
        .materiePrima,
        .produsFinit,
        .ambalaj,
        .materialeConsumabile,
        .materialeCuratenie,
        .birotica,
        .servicii,
        .garantie,
    ]

    var isArticleCategory: Bool {
        Self.articleCategories.contains(self)
    }

    /// Produs finit apare implicit în catalog.
    var impliesInCatalog: Bool {
        self == .produsFinit
    }

    /// Doar marfa și materia primă intră în stoc cu conversie UM; restul sunt cheltuieli.
    var allowsStockConversion: Bool {
        self == .marfa || self == .materiePrima
    }

    /// Articole care nu țin stoc (ex. garanție SGR, servicii, produs finit la inventar).
    var isStockable: Bool {
        switch self {
        case .marfa, .materiePrima, .ambalaj, .materialeConsumabile, .materialeCuratenie, .birotica:
            return true
        case .produsFinit, .obiectInventar, .garantie, .servicii:
            return false
        }
    }

    /// Preț achiziție și adaos 0% implicit (materie primă, ambalaj, consumabile, curățenie, birotică).
    var usesPurchasePriceAsDefault: Bool {
        switch self {
        case .materiePrima, .ambalaj, .materialeConsumabile, .materialeCuratenie, .birotica, .servicii:
            return true
        default:
            return false
        }
    }

    var label: String {
        switch self {
        case .materiePrima: return L10n.tr("products.kind_raw_material")
        case .produsFinit: return L10n.tr("products.kind_finished")
        case .marfa: return L10n.tr("products.kind_merchandise")
        case .ambalaj: return L10n.tr("products.kind_packaging")
        case .materialeConsumabile: return L10n.tr("products.kind_consumables")
        case .materialeCuratenie: return L10n.tr("products.kind_cleaning")
        case .birotica: return L10n.tr("products.kind_stationery")
        case .servicii: return L10n.tr("products.kind_services")
        case .obiectInventar: return L10n.tr("products.kind_inventory_object")
        case .garantie: return L10n.tr("products.kind_garantie")
        }
    }
}

struct Product: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var cod: String?
    var codBare: String?
    var denumire: String
    var descriere: String?
    var unitateMasura: String
    var unitateAchizitie: String?
    @SupabaseDecimal var factorConversie: Decimal
    var tip: ProductKind
    var cpv: String?
    var isActive: Bool
    var inCatalog: Bool
    var inStockSheet: Bool
    var hasRecipe: Bool
    @SupabaseDecimal var cotaTva: Decimal
    @SupabaseDecimal var pretVanzare: Decimal
    @SupabaseDecimal var pretVanzareOnline: Decimal
    var imagineUrl: String?
    @SupabaseDecimal var cantitateMinima: Decimal
    @SupabaseDecimal var cantitateOptima: Decimal
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire, descriere, cpv
        case companyId = "company_id"
        case cod
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
        case unitateAchizitie = "unitate_achizitie"
        case factorConversie = "factor_conversie"
        case tip
        case isActive = "is_active"
        case inCatalog = "in_catalog"
        case inStockSheet = "in_stock_sheet"
        case hasRecipe = "has_recipe"
        case cotaTva = "cota_tva"
        case pretVanzare = "pret_vanzare"
        case pretVanzareOnline = "pret_vanzare_online"
        case imagineUrl = "imagine_url"
        case cantitateMinima = "cantitate_minima"
        case cantitateOptima = "cantitate_optima"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        cod = try container.decodeIfPresent(String.self, forKey: .cod)
        codBare = try container.decodeIfPresent(String.self, forKey: .codBare)
        denumire = try container.decode(String.self, forKey: .denumire)
        descriere = try container.decodeIfPresent(String.self, forKey: .descriere)
        unitateMasura = try container.decode(String.self, forKey: .unitateMasura)
        unitateAchizitie = try container.decodeIfPresent(String.self, forKey: .unitateAchizitie)
        _factorConversie = try container.decode(SupabaseDecimal.self, forKey: .factorConversie)
        tip = try container.decode(ProductKind.self, forKey: .tip)
        cpv = try container.decodeIfPresent(String.self, forKey: .cpv)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        inCatalog = try container.decode(Bool.self, forKey: .inCatalog)
        inStockSheet = try container.decode(Bool.self, forKey: .inStockSheet)
        hasRecipe = try container.decode(Bool.self, forKey: .hasRecipe)
        _cotaTva = try container.decode(SupabaseDecimal.self, forKey: .cotaTva)
        let storePrice = try container.decode(SupabaseDecimal.self, forKey: .pretVanzare)
        _pretVanzare = storePrice
        if let online = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .pretVanzareOnline) {
            _pretVanzareOnline = online
        } else {
            _pretVanzareOnline = SupabaseDecimal(wrappedValue: storePrice.wrappedValue)
        }
        imagineUrl = try container.decodeIfPresent(String.self, forKey: .imagineUrl)
        if let minQty = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .cantitateMinima) {
            _cantitateMinima = minQty
        } else {
            _cantitateMinima = SupabaseDecimal(wrappedValue: 0)
        }
        if let optimalQty = try container.decodeIfPresent(SupabaseDecimal.self, forKey: .cantitateOptima) {
            _cantitateOptima = optimalQty
        } else {
            _cantitateOptima = SupabaseDecimal(wrappedValue: 0)
        }
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(companyId, forKey: .companyId)
        try container.encodeIfPresent(cod, forKey: .cod)
        try container.encodeIfPresent(codBare, forKey: .codBare)
        try container.encode(denumire, forKey: .denumire)
        try container.encodeIfPresent(descriere, forKey: .descriere)
        try container.encode(unitateMasura, forKey: .unitateMasura)
        try container.encodeIfPresent(unitateAchizitie, forKey: .unitateAchizitie)
        try container.encode(_factorConversie, forKey: .factorConversie)
        try container.encode(tip, forKey: .tip)
        try container.encodeIfPresent(cpv, forKey: .cpv)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(inCatalog, forKey: .inCatalog)
        try container.encode(inStockSheet, forKey: .inStockSheet)
        try container.encode(hasRecipe, forKey: .hasRecipe)
        try container.encode(_cotaTva, forKey: .cotaTva)
        try container.encode(_pretVanzare, forKey: .pretVanzare)
        try container.encode(_pretVanzareOnline, forKey: .pretVanzareOnline)
        try container.encodeIfPresent(imagineUrl, forKey: .imagineUrl)
        try container.encode(_cantitateMinima, forKey: .cantitateMinima)
        try container.encode(_cantitateOptima, forKey: .cantitateOptima)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct SupplierInvoiceLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let invoiceId: UUID
    var productId: UUID
    var numarLinie: Int
    var denumire: String
    @SupabaseDecimal var cantitate: Decimal
    @SupabaseDecimal var pretUnitar: Decimal
    @SupabaseDecimal var sumaLinie: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var cotaTva: Decimal
    var unitateMasura: String
    /// Importul a legat un articol similar și așteaptă confirmare pe NIR.
    var needsProductReview: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire
        case companyId = "company_id"
        case invoiceId = "invoice_id"
        case productId = "product_id"
        case numarLinie = "numar_linie"
        case cantitate
        case pretUnitar = "pret_unitar"
        case sumaLinie = "suma_linie"
        case sumaTva = "suma_tva"
        case cotaTva = "cota_tva"
        case unitateMasura = "unitate_masura"
        case needsProductReview = "needs_product_review"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        companyId = try container.decode(UUID.self, forKey: .companyId)
        invoiceId = try container.decode(UUID.self, forKey: .invoiceId)
        productId = try container.decode(UUID.self, forKey: .productId)
        numarLinie = try container.decode(Int.self, forKey: .numarLinie)
        denumire = try container.decode(String.self, forKey: .denumire)
        _cantitate = try container.decode(SupabaseDecimal.self, forKey: .cantitate)
        _pretUnitar = try container.decode(SupabaseDecimal.self, forKey: .pretUnitar)
        _sumaLinie = try container.decode(SupabaseDecimal.self, forKey: .sumaLinie)
        _sumaTva = try container.decode(SupabaseDecimal.self, forKey: .sumaTva)
        _cotaTva = try container.decode(SupabaseDecimal.self, forKey: .cotaTva)
        unitateMasura = try container.decode(String.self, forKey: .unitateMasura)
        needsProductReview = try container.decodeIfPresent(Bool.self, forKey: .needsProductReview) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(
        id: UUID,
        companyId: UUID,
        invoiceId: UUID,
        productId: UUID,
        numarLinie: Int,
        denumire: String,
        cantitate: Decimal,
        pretUnitar: Decimal,
        sumaLinie: Decimal,
        sumaTva: Decimal,
        cotaTva: Decimal,
        unitateMasura: String,
        needsProductReview: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.companyId = companyId
        self.invoiceId = invoiceId
        self.productId = productId
        self.numarLinie = numarLinie
        self.denumire = denumire
        self.cantitate = cantitate
        self.pretUnitar = pretUnitar
        self.sumaLinie = sumaLinie
        self.sumaTva = sumaTva
        self.cotaTva = cotaTva
        self.unitateMasura = unitateMasura
        self.needsProductReview = needsProductReview
        self.createdAt = createdAt
    }
}
