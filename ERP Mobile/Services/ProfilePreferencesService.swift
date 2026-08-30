import Foundation
import Supabase

enum ProfilePreferencesService {
    private static let client = SupabaseManager.client

    private struct LanguageUpdate: Encodable {
        let preferredLanguageCode: String

        enum CodingKeys: String, CodingKey {
            case preferredLanguageCode = "preferred_language_code"
        }
    }

    static func setPreferredLanguage(_ language: AppLanguage) async throws {
        guard let userId = await AuthService.currentUserId() else {
            throw ServiceError.invalidResponse
        }
        let payload = LanguageUpdate(preferredLanguageCode: language.rawValue)
        try await client
            .from("user_profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
