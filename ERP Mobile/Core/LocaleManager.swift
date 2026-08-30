import Combine
import Foundation
import SwiftUI

@MainActor
final class LocaleManager: ObservableObject {
    private static let storageKey = "erp_mobile_preferred_language"

    @Published var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            L10n.setLanguage(language)
            PrivacyPolicyLoader.clearCache()
            TermsOfServiceLoader.clearCache()
            GDPRPolicyLoader.clearCache()
            persistGuestLanguage()
        }
    }

    var locale: Locale { language.locale }

    init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppLanguage(rawValue: stored) {
            language = saved
        } else {
            language = Self.systemDefaultLanguage()
        }
        L10n.setLanguage(language)
    }

    func configure(profile: UserProfile?) {
        guard let profile else { return }
        let profileLanguage = AppLanguage.from(code: profile.preferredLanguageCode)
        if language != profileLanguage {
            language = profileLanguage
        }
    }

    func setLanguage(_ newLanguage: AppLanguage, persistToServer: Bool) async throws {
        language = newLanguage
        if persistToServer {
            try await ProfilePreferencesService.setPreferredLanguage(newLanguage)
        }
    }

    private func persistGuestLanguage() {
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
    }

    private static func systemDefaultLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "ro"
        let code = Locale(identifier: preferred).languageCode ?? "ro"
        if let match = AppLanguage.allCases.first(where: { $0.rawValue == code || preferred.hasPrefix($0.rawValue) }) {
            return match
        }
        return .romanian
    }
}
