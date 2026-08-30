import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum AppStoreLinkOpener {
    @MainActor
    static func open(_ url: URL) {
#if targetEnvironment(macCatalyst)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
#elseif canImport(UIKit)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
#elseif canImport(AppKit)
        if NSWorkspace.shared.open(url) {
            return
        }
        if let fallbackURL = httpsFallbackURL(for: url) {
            _ = NSWorkspace.shared.open(fallbackURL)
        }
#endif
    }

    private static func httpsFallbackURL(for url: URL) -> URL? {
        let absolute = url.absoluteString
        if absolute.hasPrefix("macappstore://") {
            return URL(string: absolute.replacingOccurrences(of: "macappstore://", with: "https://"))
        }
        if absolute.hasPrefix("itms-apps://") {
            return URL(string: absolute.replacingOccurrences(of: "itms-apps://", with: "https://"))
        }
        return nil
    }
}

enum AppVersionComparison {
    static func compare(_ installed: String, _ store: String) -> ComparisonResult {
        let installedParts = installed.split(separator: ".").map { Int($0) ?? 0 }
        let storeParts = store.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(installedParts.count, storeParts.count)

        for index in 0..<count {
            let installedValue = index < installedParts.count ? installedParts[index] : 0
            let storeValue = index < storeParts.count ? storeParts[index] : 0
            if installedValue < storeValue { return .orderedAscending }
            if installedValue > storeValue { return .orderedDescending }
        }
        return .orderedSame
    }
}

enum AppStoreVersionService {
    struct UpdateCheckResult: Sendable {
        let isUpdateRequired: Bool
        let storeURL: URL?
        let storeVersion: String?
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let version: String
            let trackViewUrl: String?
            let trackId: Int?
        }

        let resultCount: Int?
        let results: [Result]
    }

    static func checkForUpdate() async -> UpdateCheckResult {
        guard let listing = await fetchListing() else {
            return UpdateCheckResult(isUpdateRequired: false, storeURL: nil, storeVersion: nil)
        }

        let installedVersion = AppInfo.marketingVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !installedVersion.isEmpty, installedVersion != "—" else {
            return UpdateCheckResult(isUpdateRequired: false, storeURL: nil, storeVersion: listing.version)
        }

        let comparison = AppVersionComparison.compare(installedVersion, listing.version)
        let isUpdateRequired = comparison == .orderedAscending
        let storeURL = preferredUpdateURL(
            trackId: listing.trackId,
            trackViewUrl: listing.trackViewUrl
        )

        return UpdateCheckResult(
            isUpdateRequired: isUpdateRequired,
            storeURL: storeURL,
            storeVersion: listing.version
        )
    }

    static func preferredUpdateURL(trackId: Int? = nil, trackViewUrl: String? = nil) -> URL? {
        if let trackId {
            #if targetEnvironment(macCatalyst)
            return URL(string: "macappstore://apps.apple.com/app/id\(trackId)")
            #else
            return URL(string: "itms-apps://apps.apple.com/app/id\(trackId)")
            #endif
        }
        if let trackViewUrl,
           let url = URL(string: trackViewUrl.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return AppInfo.appStoreUpdateURL
    }

    private static func fetchListing() async -> (version: String, trackId: Int?, trackViewUrl: String?)? {
        if let listing = await fetchListing(queryItems: bundleLookupQueryItems()) {
            return listing
        }
        return await fetchListing(queryItems: [
            URLQueryItem(name: "id", value: AppInfo.appStoreID),
            URLQueryItem(name: "country", value: "ro"),
        ])
    }

    private static func bundleLookupQueryItems() -> [URLQueryItem]? {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return nil }
        return [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: "ro"),
        ]
    }

    private static func fetchListing(queryItems: [URLQueryItem]?) async -> (version: String, trackId: Int?, trackViewUrl: String?)? {
        guard let queryItems, !queryItems.isEmpty else { return nil }

        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = queryItems
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard decoded.resultCount ?? decoded.results.count > 0,
                  let result = decoded.results.first else {
                return nil
            }

            let version = result.version.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !version.isEmpty else { return nil }

            return (version: version, trackId: result.trackId, trackViewUrl: result.trackViewUrl)
        } catch {
            return nil
        }
    }
}
