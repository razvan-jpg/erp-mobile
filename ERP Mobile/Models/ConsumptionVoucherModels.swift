import Foundation

struct ConsumptionVoucher: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let numar: String
    let dataBon: Date
    let warehouseId: UUID
    let motiv: String
    let status: String
    let createdBy: UUID?
    let shiftNo: Int?
    let warehouse: ProductionVoucherWarehouseRef?

    enum CodingKeys: String, CodingKey {
        case id, numar, motiv, status, warehouse
        case companyId = "company_id"
        case dataBon = "data_bon"
        case warehouseId = "warehouse_id"
        case createdBy = "created_by"
        case shiftNo = "shift_no"
    }

    var isDraft: Bool { status == "draft" }
    var isPartial: Bool { status == "partial" }
    var isApproved: Bool { status == "approved" }

    var statusLabel: String {
        switch status {
        case "approved": return L10n.tr("cashier.consumption_status_approved")
        case "partial": return L10n.tr("cashier.consumption_status_partial")
        default: return L10n.tr("cashier.consumption_status_draft")
        }
    }
}

struct ConsumptionVoucherLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let voucherId: UUID
    let productId: UUID
    let numarLinie: Int
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    let aprobat: Bool
    let product: ProductStockProductRef?

    enum CodingKeys: String, CodingKey {
        case id, cantitate, product, aprobat
        case voucherId = "voucher_id"
        case productId = "product_id"
        case numarLinie = "numar_linie"
        case unitateMasura = "unitate_masura"
    }

    var productName: String {
        product?.denumire ?? L10n.tr("inventory.unknown_product")
    }
}

enum ConsumptionShift {
    static var current: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
        return calendar.component(.hour, from: Date()) < 12 ? 2 : 1
    }

    static func label(_ shift: Int?) -> String? {
        switch shift {
        case 1: return L10n.tr("cashier.consumption_shift_day")
        case 2: return L10n.tr("cashier.consumption_shift_night")
        default: return nil
        }
    }

    static func suffix(_ shift: Int?) -> String {
        guard let label = label(shift) else { return "" }
        return " · " + label
    }
}

enum ConsumptionVoucherError: LocalizedError {
    case motivRequired
    case noLines
    case approveNone
    case invalidQuantity
    case insufficientStock
    case locked
    case forbidden
    case managerRequired
    case warehouse
    case duplicate
    case shiftRequired

    var errorDescription: String? {
        switch self {
        case .motivRequired: return L10n.tr("cashier.consumption_error_motiv")
        case .noLines: return L10n.tr("cashier.consumption_error_lines")
        case .approveNone: return L10n.tr("cashier.consumption_error_approve_none")
        case .invalidQuantity: return L10n.tr("cashier.consumption_error_quantity")
        case .insufficientStock: return L10n.tr("cashier.consumption_error_stock")
        case .locked: return L10n.tr("cashier.consumption_error_locked")
        case .forbidden: return L10n.tr("cashier.consumption_error_forbidden")
        case .managerRequired: return L10n.tr("cashier.consumption_error_manager")
        case .warehouse: return L10n.tr("cashier.consumption_error_warehouse")
        case .duplicate: return L10n.tr("cashier.consumption_error_duplicate")
        case .shiftRequired: return L10n.tr("cashier.consumption_error_shift")
        }
    }

    static func map(_ error: Error) -> Error {
        let message = error.localizedDescription.uppercased()
        if message.contains("CONSUMPTION_MOTIV_REQUIRED") { return ConsumptionVoucherError.motivRequired }
        if message.contains("CONSUMPTION_APPROVE_NONE") { return ConsumptionVoucherError.approveNone }
        if message.contains("CONSUMPTION_NO_LINES") { return ConsumptionVoucherError.noLines }
        if message.contains("CONSUMPTION_INVALID_QUANTITY") { return ConsumptionVoucherError.invalidQuantity }
        if message.contains("CONSUMPTION_INSUFFICIENT_STOCK") { return ConsumptionVoucherError.insufficientStock }
        if message.contains("CONSUMPTION_LOCKED") { return ConsumptionVoucherError.locked }
        if message.contains("CONSUMPTION_MANAGER_REQUIRED") { return ConsumptionVoucherError.managerRequired }
        if message.contains("CONSUMPTION_WAREHOUSE_INVALID") { return ConsumptionVoucherError.warehouse }
        if message.contains("CONSUMPTION_DUPLICATE_PRODUCT") { return ConsumptionVoucherError.duplicate }
        if message.contains("CONSUMPTION_SHIFT_REQUIRED") { return ConsumptionVoucherError.shiftRequired }
        if message.contains("FORBIDDEN") { return ConsumptionVoucherError.forbidden }
        return error
    }
}
