import Foundation
import Supabase

enum NIRDeleteError: LocalizedError {
    case notFound
    case forbidden
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return L10n.tr("nir.delete_not_found")
        case .forbidden:
            return L10n.tr("module.no_access")
        case .deleteFailed:
            return L10n.tr("nir.delete_failed")
        }
    }

    static func map(_ error: Error) -> Error {
        if let mapped = error as? NIRDeleteError {
            return mapped
        }

        if let postgrest = error as? PostgrestError {
            let combined = [postgrest.message, postgrest.detail, postgrest.hint]
                .compactMap { $0 }
                .joined(separator: " ")
                .uppercased()
            if combined.contains("NIR_NOT_FOUND") {
                return NIRDeleteError.notFound
            }
            if combined.contains("NIR_DELETE_FORBIDDEN") {
                return NIRDeleteError.forbidden
            }
        }

        let message = error.localizedDescription.uppercased()
        if message.contains("NIR_NOT_FOUND") {
            return NIRDeleteError.notFound
        }
        if message.contains("NIR_DELETE_FORBIDDEN") {
            return NIRDeleteError.forbidden
        }
        return error
    }
}
