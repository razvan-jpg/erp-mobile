import Foundation
import Supabase

enum InvoiceDeleteError: LocalizedError {
    case hasRegisteredPayments
    case notFound
    case forbidden
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .hasRegisteredPayments:
            return L10n.tr("invoices.delete_blocked_payments")
        case .notFound:
            return L10n.tr("invoices.delete_not_found")
        case .forbidden:
            return L10n.tr("module.no_access")
        case .deleteFailed:
            return L10n.tr("invoices.delete_failed")
        }
    }

    static func map(_ error: Error) -> Error {
        if let mapped = error as? InvoiceDeleteError {
            return mapped
        }

        if let postgrest = error as? PostgrestError {
            let combined = [postgrest.message, postgrest.detail, postgrest.hint]
                .compactMap { $0 }
                .joined(separator: " ")
                .uppercased()
            if combined.contains("INVOICE_HAS_PAYMENTS") {
                return InvoiceDeleteError.hasRegisteredPayments
            }
            if combined.contains("INVOICE_NOT_FOUND") {
                return InvoiceDeleteError.notFound
            }
            if combined.contains("INVOICE_DELETE_FORBIDDEN") {
                return InvoiceDeleteError.forbidden
            }
        }

        let message = error.localizedDescription.uppercased()
        if message.contains("INVOICE_HAS_PAYMENTS") {
            return InvoiceDeleteError.hasRegisteredPayments
        }
        if message.contains("INVOICE_NOT_FOUND") {
            return InvoiceDeleteError.notFound
        }
        if message.contains("INVOICE_DELETE_FORBIDDEN") {
            return InvoiceDeleteError.forbidden
        }
        return error
    }
}
