import Foundation
import Supabase

enum SupabaseManager {
    private static func makeAuthOptions() -> SupabaseClientOptions.AuthOptions {
#if targetEnvironment(macCatalyst)
        return SupabaseClientOptions.AuthOptions(
            storage: UserDefaultsAuthLocalStorage(),
            emitLocalSessionAsInitialSession: true
        )
#else
        return SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
#endif
    }

    static let client: SupabaseClient = {
        guard let url = URL(string: SupabaseConfig.projectURL) else {
            fatalError("URL Supabase invalid: \(SupabaseConfig.projectURL)")
        }
        let decoder = SupabaseDecoding.jsonDecoder
        let options = SupabaseClientOptions(
            db: .init(decoder: decoder),
            auth: makeAuthOptions(),
            functions: .init(decoder: decoder)
        )
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }()
}
