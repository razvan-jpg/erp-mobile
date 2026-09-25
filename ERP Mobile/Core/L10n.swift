import Foundation

enum L10n {
    private static var currentLanguage: AppLanguage = .romanian
    private static var cache: [AppLanguage: [String: String]] = [:]

    static var locale: Locale { currentLanguage.locale }

    static func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        // Păstrăm cache-urile deja încărcate — evită re-decodare JSON pe UI thread.
    }

    /// Încarcă tabelele RO/EN o dată la pornire (evită hitch la primul `tr`).
    static func preload() {
        _ = strings(for: .romanian)
        _ = strings(for: .english)
    }

    static func tr(_ key: String) -> String {
        tr(key, language: currentLanguage)
    }

    static func tr(_ key: String, language: AppLanguage) -> String {
        let table = strings(for: language)
        if let value = table[key] { return value }
        if language != .romanian, let ro = strings(for: .romanian)[key] { return ro }
        return key
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = tr(key)
        guard !args.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: args)
    }

    private static func strings(for language: AppLanguage) -> [String: String] {
        if let cached = cache[language] { return cached }
        let url = localizationURL(for: language)
        guard let url else {
            cache[language] = [:]
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            cache[language] = decoded
            return decoded
        } catch {
            cache[language] = [:]
            return [:]
        }
    }

    private static func localizationURL(for language: AppLanguage) -> URL? {
        let name = language.rawValue
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Resources/Localization"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Localization"),
            Bundle.main.url(forResource: name, withExtension: "json")
        ]
        return candidates.compactMap { $0 }.first
    }
}
