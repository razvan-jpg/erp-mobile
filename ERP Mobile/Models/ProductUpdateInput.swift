import Foundation

struct ProductUpdateInput: Sendable {
    var denumire: String
    var cod: String?
    var codBare: String?
    var unitateMasura: String
    var unitateAchizitie: String?
    var factorConversie: Decimal
    var tip: ProductKind
}

enum ProductDeleteBlocker: Sendable {
    case hasStockMovements
    case hasInvoiceLines
    case hasPhysicalInventoryLines

    var localizedMessage: String {
        switch self {
        case .hasStockMovements:
            return L10n.tr("module.products.error_delete_has_movements")
        case .hasInvoiceLines:
            return L10n.tr("module.products.error_delete_has_invoices")
        case .hasPhysicalInventoryLines:
            return L10n.tr("module.products.error_delete_has_inventory")
        }
    }
}

enum ProductDeleteError: LocalizedError {
    case blocked(ProductDeleteBlocker)

    var errorDescription: String? {
        switch self {
        case .blocked(let blocker):
            return blocker.localizedMessage
        }
    }
}
