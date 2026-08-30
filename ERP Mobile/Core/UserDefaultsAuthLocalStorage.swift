import Auth
import Foundation

/// Persists Supabase auth sessions in UserDefaults.
/// Used on Mac Catalyst because sandboxed Keychain storage often fails silently.
struct UserDefaultsAuthLocalStorage: AuthLocalStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "supabase.auth."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: keyPrefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: keyPrefix + key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: keyPrefix + key)
    }
}
