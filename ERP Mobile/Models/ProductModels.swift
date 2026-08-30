import Foundation

enum ProductKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case materiePrima = "materie_prima"
    case produsFinit = "produs_finit"
    case marfa
    case ambalaj
    case materialeConsumabile = "materiale_consumabile"
    case obiectInventar = "obiect_inventar"

    var id: String { rawValue }

    /// Categorii selectabile pe fișa articolului și în NIR.
    static let articleCategories: [ProductKind] = [
        .marfa,
        .materiePrima,
        .produsFinit,
        .ambalaj,
        .materialeConsumabile,
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

    /// Preț achiziție și adaos 0% implicit (materie primă, ambalaj, consumabile).
    var usesPurchasePriceAsDefault: Bool {
        switch self {
        case .materiePrima, .ambalaj, .materialeConsumabile:
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
        case .obiectInventar: return L10n.tr("products.kind_inventory_object")
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
    var imagineUrl: String?
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
        case imagineUrl = "imagine_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupplierInvoiceLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let invoiceId: UUID
    let productId: UUID
    var numarLinie: Int
    var denumire: String
    @SupabaseDecimal var cantitate: Decimal
    @SupabaseDecimal var pretUnitar: Decimal
    @SupabaseDecimal var sumaLinie: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var cotaTva: Decimal
    var unitateMasura: String
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
        case createdAt = "created_at"
    }
}
