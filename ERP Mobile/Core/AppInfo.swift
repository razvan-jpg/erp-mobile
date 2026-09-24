import Foundation

enum AppInfo {
    /// Contact oficial ERP Mobile (suport, GDPR, legal).
    static let contactEmail = "ERPMobile@dateconta.ro"

    /// Ultima migrare Supabase aplicată (actualizați la fiecare `db push`).
    static let databaseSchemaVersion = "1.0.054"

    /// Versiunea integrării Resend (Edge Functions + email).
    static let resendIntegrationVersion = "1.0.001"

    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    static var displayVersion: String {
        "v\(marketingVersion)"
    }

    /// Etichetă versiune pe ecranul de pornire: „v 1.0.024”.
    static var splashVersionLabel: String {
        "v \(marketingVersion)"
    }

    /// App Store listing ID (https://apps.apple.com/app/id\(appStoreID))
    static let appStoreID = "6777165137"

    static var appStoreUpdateURL: URL? {
        #if targetEnvironment(macCatalyst)
        return URL(string: "macappstore://apps.apple.com/app/id\(appStoreID)")
        #else
        return URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)")
        #endif
    }

    static var marketingVersionWithBuildLabel: String {
        let build = buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !build.isEmpty else { return marketingVersion }
        return "\(marketingVersion) (Build: \(build))"
    }
}
