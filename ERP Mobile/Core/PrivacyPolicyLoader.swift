import Foundation

enum PrivacyPolicyLoader {
    private static var cache: [AppLanguage: String] = [:]

    static func text(for language: AppLanguage) -> String {
        if let cached = cache[language] { return cached }

        let candidates = [
            language.rawValue,
            language.rawValue.replacingOccurrences(of: "-", with: "_")
        ]

        for code in candidates {
            if let loaded = loadFile(named: "privacy-policy-\(code)") {
                cache[language] = loaded
                return loaded
            }
        }

        if language != .romanian, let romanian = loadFile(named: "privacy-policy-ro") {
            cache[language] = romanian
            return romanian
        }

        return ""
    }

    static func clearCache() {
        cache.removeAll()
    }

    private static func loadFile(named name: String) -> String? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Resources/Legal"),
            Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Legal"),
            Bundle.main.url(forResource: name, withExtension: "txt")
        ]
        guard let url = candidates.compactMap({ $0 }).first else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
