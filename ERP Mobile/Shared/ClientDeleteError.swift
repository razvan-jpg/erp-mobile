import Foundation

enum ClientDeleteError: LocalizedError {
    case hasRegisteredInvoices
    case notFound
    case forbidden

    var errorDescription: String? {
        switch self {
        case .hasRegisteredInvoices:
            return L10n.tr("clients.delete_blocked_invoices")
        case .notFound:
            return L10n.tr("clients.delete_not_found")
        case .forbidden:
            return L10n.tr("module.no_access")
        }
    }

    static func map(_ error: Error) -> Error {
        let message = error.localizedDescription.uppercased()
        if message.contains("CLIENT_HAS_INVOICES") {
            return ClientDeleteError.hasRegisteredInvoices
        }
        if message.contains("CLIENT_NOT_FOUND") {
            return ClientDeleteError.notFound
        }
        if message.contains("CLIENT_DELETE_FORBIDDEN") {
            return ClientDeleteError.forbidden
        }
        return error
    }
}
