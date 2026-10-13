import Foundation

struct ProductionVoucher: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let numar: String
    let dataBon: Date
    let warehouseId: UUID
    let productId: UUID
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    let observatii: String?
    let createdAt: Date?
    let product: ProductStockProductRef?
    let warehouse: ProductionVoucherWarehouseRef?

    enum CodingKeys: String, CodingKey {
        case id, numar, cantitate, observatii, product, warehouse
        case companyId = "company_id"
        case dataBon = "data_bon"
        case warehouseId = "warehouse_id"
        case productId = "product_id"
        case unitateMasura = "unitate_masura"
        case createdAt = "created_at"
    }
}

struct ProductionVoucherWarehouseRef: Codable, Hashable, Sendable {
    let id: UUID
    let denumire: String
    let cod: String?
}

struct ProductionVoucherLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let voucherId: UUID
    let productId: UUID
    let numarLinie: Int
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    let product: ProductStockProductRef?

    enum CodingKeys: String, CodingKey {
        case id, cantitate, product
        case voucherId = "voucher_id"
        case productId = "product_id"
        case numarLinie = "numar_linie"
        case unitateMasura = "unitate_masura"
    }
}

enum ProductionVoucherError: LocalizedError {
    case invalidQuantity
    case noProduct
    case noWarehouse
    case insufficientStock
    case productNotAllowed
    case recipeEmpty
    case forbidden

    var errorDescription: String? {
        switch self {
        case .invalidQuantity: return L10n.tr("cashier.production_error_quantity")
        case .noProduct: return L10n.tr("cashier.production_error_product")
        case .noWarehouse: return L10n.tr("cashier.production_error_warehouse")
        case .insufficientStock: return L10n.tr("cashier.production_error_insufficient")
        case .productNotAllowed: return L10n.tr("cashier.production_error_product_kind")
        case .recipeEmpty: return L10n.tr("cashier.production_error_recipe")
        case .forbidden: return L10n.tr("cashier.production_error_forbidden")
        }
    }

    static func map(_ error: Error) -> Error {
        let message = error.localizedDescription.uppercased()
        if message.contains("PRODUCTION_INSUFFICIENT_STOCK") { return ProductionVoucherError.insufficientStock }
        if message.contains("PRODUCTION_PRODUCT_NOT_ALLOWED") { return ProductionVoucherError.productNotAllowed }
        if message.contains("PRODUCTION_RECIPE_EMPTY") || message.contains("PRODUCTION_NESTED_RECIPE_EMPTY") {
            return ProductionVoucherError.recipeEmpty
        }
        if message.contains("PRODUCTION_INVALID_QUANTITY") { return ProductionVoucherError.invalidQuantity }
        if message.contains("PRODUCTION_WAREHOUSE_INVALID") { return ProductionVoucherError.noWarehouse }
        if message.contains("PRODUCTION_PRODUCT_NOT_FOUND") { return ProductionVoucherError.noProduct }
        if message.contains("FORBIDDEN") { return ProductionVoucherError.forbidden }
        return error
    }
}
