import Foundation

enum SupabaseConfig {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "SupabaseSecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ) as? [String: Any]
        else {
            return [:]
        }
        return plist
    }()

    private static func value(for key: String) -> String? {
        if let plistValue = secrets[key] as? String,
           !plistValue.isEmpty,
           !plistValue.contains("YOUR_") {
            return plistValue
        }
        if let envValue = ProcessInfo.processInfo.environment[key],
           !envValue.isEmpty,
           !envValue.contains("YOUR_") {
            return envValue
        }
        return nil
    }

    static let projectURL: String = {
        value(for: "SUPABASE_URL") ?? "https://YOUR_PROJECT_REF.supabase.co"
    }()

    static let anonKey: String = {
        value(for: "SUPABASE_ANON_KEY") ?? "YOUR_SUPABASE_ANON_KEY"
    }()

    static var isConfigured: Bool {
        value(for: "SUPABASE_URL") != nil && value(for: "SUPABASE_ANON_KEY") != nil
    }
}
