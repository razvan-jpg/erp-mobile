import Foundation

enum SupplierDeleteError: LocalizedError {
    case hasRegisteredInvoices
    case notFound
    case forbidden

    var errorDescription: String? {
        switch self {
        case .hasRegisteredInvoices:
            return L10n.tr("suppliers.delete_blocked_invoices")
        case .notFound:
            return L10n.tr("suppliers.delete_not_found")
        case .forbidden:
            return L10n.tr("module.no_access")
        }
    }

    static func map(_ error: Error) -> Error {
        let message = error.localizedDescription.uppercased()
        if message.contains("SUPPLIER_HAS_INVOICES") {
            return SupplierDeleteError.hasRegisteredInvoices
        }
        if message.contains("SUPPLIER_NOT_FOUND") {
            return SupplierDeleteError.notFound
        }
        if message.contains("SUPPLIER_DELETE_FORBIDDEN") {
            return SupplierDeleteError.forbidden
        }
        return error
    }
}
