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
    var cantitateMinima: Decimal = 0
    var cantitateOptima: Decimal = 0
    var inCatalog: Bool = false
    var inStockSheet: Bool = false
    var hasRecipe: Bool = false
    var cotaTva: Decimal = 21
    var pretVanzare: Decimal = 0
    var imagineUrl: String?
}

enum ProductCreateError: LocalizedError {
    case missingName
    case missingCode
    case duplicateBarcode(String)
    case duplicateCode(String)
    case invalidVatRate
    case invalidSalePrice

    var errorDescription: String? {
        switch self {
        case .missingName:
            return L10n.tr("module.products.error_missing_name")
        case .missingCode:
            return L10n.tr("module.products.error_missing_code")
        case .duplicateBarcode(let barcode):
            return L10n.tr("module.products.error_duplicate_barcode", barcode)
        case .duplicateCode(let code):
            return L10n.tr("module.products.error_duplicate_code", code)
        case .invalidVatRate:
            return L10n.tr("module.products.error_invalid_vat")
        case .invalidSalePrice:
            return L10n.tr("module.products.error_invalid_sale_price")
        }
    }
}
