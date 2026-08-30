import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case romanian = "ro"
    case english = "en"
    case french = "fr"
    case italian = "it"
    case spanish = "es"
    case german = "de"
    case polish = "pl"
    case czech = "cs"
    case serbian = "sr"
    case hungarian = "hu"
    case russian = "ru"
    case bulgarian = "bg"
    case turkish = "tr"
    case nepali = "ne"
    case korean = "ko"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case arabic = "ar"
    case thai = "th"
    case dutch = "nl"

    var id: String { rawValue }

    /// Nume afișat în limba respectivă (pentru selector).
    var nativeName: String {
        switch self {
        case .romanian: return "Română"
        case .english: return "English"
        case .french: return "Français"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .polish: return "Polski"
        case .czech: return "Čeština"
        case .serbian: return "Srpski"
        case .hungarian: return "Magyar"
        case .russian: return "Русский"
        case .bulgarian: return "Български"
        case .turkish: return "Türkçe"
        case .nepali: return "नेपाली"
        case .korean: return "한국어"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .arabic: return "العربية"
        case .thai: return "ไทย"
        case .dutch: return "Nederlands"
        }
    }

    var sortOrder: Int {
        switch self {
        case .romanian: return 1
        case .english: return 2
        case .french: return 3
        case .italian: return 4
        case .spanish: return 5
        case .german: return 6
        case .polish: return 7
        case .czech: return 8
        case .serbian: return 9
        case .hungarian: return 10
        case .russian: return 11
        case .bulgarian: return 12
        case .turkish: return 13
        case .nepali: return 14
        case .korean: return 15
        case .chinese: return 16
        case .japanese: return 17
        case .arabic: return 18
        case .thai: return 19
        case .dutch: return 20
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var sortedAll: [AppLanguage] {
        allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func from(code: String?) -> AppLanguage {
        guard let code, let language = AppLanguage(rawValue: code) else {
            return .romanian
        }
        return language
    }
}
