import Foundation
import Supabase

enum PosDocumentStore {
    static let bucket = "pos-documents"

    static func target(companyId: UUID) throws -> (path: String, url: String) {
        let path = "\(companyId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).pdf"
        let url = try SupabaseManager.client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
        return (path, url)
    }

    static func upload(path: String, data: Data) async throws {
        try await SupabaseManager.client.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "application/pdf", upsert: true)
            )
    }
}
