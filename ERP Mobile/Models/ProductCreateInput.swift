import Foundation

struct ProductCreateInput: Sendable {
    var denumire: String
    var cod: String?
    var codBare: String?
    var descriere: String?
    var unitateMasura: String
    var unitateAchizitie: String? = nil
    var factorConversie: Decimal = 1
    var tip: ProductKind
    var inCatalog: Bool = false
    var inStockSheet: Bool = false
    var hasRecipe: Bool = false
    var cotaTva: Decimal = 21
    var pretVanzare: Decimal = 0
    var imagineUrl: String?
}

enum ProductCreateError: LocalizedError {
    case missingName
    case duplicateBarcode(String)
    case invalidVatRate
    case invalidSalePrice

    var errorDescription: String? {
        switch self {
        case .missingName:
            return L10n.tr("module.products.error_missing_name")
        case .duplicateBarcode(let barcode):
            return L10n.tr("module.products.error_duplicate_barcode", barcode)
        case .invalidVatRate:
            return L10n.tr("module.products.error_invalid_vat")
        case .invalidSalePrice:
            return L10n.tr("module.products.error_invalid_sale_price")
        }
    }
}
