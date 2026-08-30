import Foundation
import Supabase

enum ProductImageService {
    static let bucket = "product-images"

    private static let client = SupabaseManager.client

    static func upload(
        companyId: UUID,
        productId: UUID,
        imageData: Data,
        contentType: String
    ) async throws -> String {
        let ext = fileExtension(for: contentType)
        let path = "\(companyId.uuidString.lowercased())/\(productId.uuidString.lowercased()).\(ext)"
        try await client.storage
            .from(bucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: contentType, upsert: true)
            )
        return try client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }

    static func deleteIfStored(_ imagineUrl: String?) async {
        guard let path = storagePath(from: imagineUrl) else { return }
        _ = try? await client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    static func storagePath(from imagineUrl: String?) -> String? {
        guard let imagineUrl,
              imagineUrl.contains("/storage/v1/object/public/\(bucket)/") else {
            return nil
        }
        let marker = "/storage/v1/object/public/\(bucket)/"
        guard let range = imagineUrl.range(of: marker) else { return nil }
        let path = String(imagineUrl[range.upperBound...])
        return path.isEmpty ? nil : path
    }

    private static func fileExtension(for contentType: String) -> String {
        switch contentType.lowercased() {
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "image/heic", "image/heif": return "heic"
        default: return "jpg"
        }
    }
}
