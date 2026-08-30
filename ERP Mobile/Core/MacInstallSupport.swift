#if targetEnvironment(macCatalyst)
import CoreServices
import Darwin
import UIKit

enum MacInstallSupport {
    private static let desktopBookmarkKey = "mac.desktopFolderBookmark"
    private static let launchServicesKey = "mac.launchServicesRegistered"

    enum DesktopShortcutResult: Equatable {
        case created
        case alreadyExists
        case cancelled
        case failed(String)
    }

    static var hasSavedDesktopFolder: Bool {
        UserDefaults.standard.data(forKey: desktopBookmarkKey) != nil
    }

    static func configureOnLaunch() {
        registerWithLaunchServicesIfNeeded()
        DispatchQueue.main.async {
            configureMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            configureMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            configureMainWindow()
        }
    }

    static func saveDesktopFolderBookmark(_ url: URL) {
        let startedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        saveDesktopBookmark(url)
    }

    @MainActor
    @discardableResult
    static func installDesktopShortcut(forceRecreate: Bool) -> DesktopShortcutResult {
        guard let desktopURL = resolveSavedDesktopBookmark() else {
            return .failed(L10n.tr("settings.mac_desktop_shortcut_select_required"))
        }
        return installDesktopShortcut(on: desktopURL, forceRecreate: forceRecreate)
    }

    /// Ensures the app bundle is visible to Launch Services (Applications / Spotlight).
    private static func registerWithLaunchServicesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: launchServicesKey) else { return }

        let appURL = Bundle.main.bundleURL as NSURL
        let status = LSRegisterURL(appURL as CFURL, true)
        if status == noErr {
            UserDefaults.standard.set(true, forKey: launchServicesKey)
        }
    }

    @MainActor
    private static func installDesktopShortcut(on desktopURL: URL, forceRecreate: Bool) -> DesktopShortcutResult {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "ERP Mobile"
        let shortcutFileName = "\(displayName).app"
        let appURL = Bundle.main.bundleURL

        let desktopRoots = desktopSearchRoots(primary: desktopURL)
        let startedAccess = desktopURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                desktopURL.stopAccessingSecurityScopedResource()
            }
        }

        let existingShortcuts = findDesktopShortcuts(on: desktopRoots, appURL: appURL, preferredFileName: shortcutFileName)
        if !forceRecreate {
            if deduplicateShortcuts(existingShortcuts, preferredFileName: shortcutFileName) != nil {
                return .alreadyExists
            }
        } else {
            removeDesktopShortcuts(existingShortcuts)
        }

        let installRoot = desktopURL.standardizedFileURL
        let shortcutURL = installRoot.appendingPathComponent(shortcutFileName, isDirectory: false)

        do {
            try createDesktopShortcut(at: shortcutURL, pointingTo: appURL)
            LSRegisterURL(shortcutURL as CFURL, true)
            return .created
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func desktopSearchRoots(primary: URL) -> [URL] {
        var roots = [primary.standardizedFileURL]
        for url in FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask) {
            let standardized = url.standardizedFileURL
            if !roots.contains(standardized) {
                roots.append(standardized)
            }
        }
        return roots
    }

    private static func findDesktopShortcuts(
        on desktopRoots: [URL],
        appURL: URL,
        preferredFileName: String
    ) -> [URL] {
        var matches: [URL] = []
        var seenPaths = Set<String>()
        for root in desktopRoots {
            let preferred = root.appendingPathComponent(preferredFileName, isDirectory: false).standardizedFileURL
            if resolvesToApp(preferred, appURL: appURL), seenPaths.insert(preferred.path).inserted {
                matches.append(preferred)
            }

            guard let items = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in items where item.pathExtension == "app" {
                let standardized = item.standardizedFileURL
                if resolvesToApp(standardized, appURL: appURL), seenPaths.insert(standardized.path).inserted {
                    matches.append(standardized)
                }
            }
        }
        return matches
    }

    @discardableResult
    private static func deduplicateShortcuts(_ shortcuts: [URL], preferredFileName: String) -> URL? {
        guard !shortcuts.isEmpty else { return nil }

        let normalized = shortcuts.map(\.standardizedFileURL)
        let preferred = normalized.first { $0.lastPathComponent == preferredFileName } ?? normalized[0]
        let preferredPath = preferred.path
        for duplicate in normalized where duplicate.path != preferredPath {
            try? FileManager.default.removeItem(at: duplicate)
        }
        return preferred
    }

    private static func removeDesktopShortcuts(_ shortcuts: [URL]) {
        for shortcut in shortcuts {
            try? FileManager.default.removeItem(at: shortcut)
        }
    }

    private static func resolvesToApp(_ itemURL: URL, appURL: URL) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: itemURL.path) else { return false }

        let target = appURL.standardizedFileURL
        let item = itemURL.standardizedFileURL
        if item == target {
            return true
        }

        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: item.path) else {
            return false
        }

        let resolved: URL
        if destination.hasPrefix("/") {
            resolved = URL(fileURLWithPath: destination, isDirectory: true)
        } else {
            resolved = item.deletingLastPathComponent().appendingPathComponent(destination, isDirectory: true)
        }
        return resolved.standardizedFileURL == target
    }

    private static func saveDesktopBookmark(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmark, forKey: desktopBookmarkKey)
    }

    private static func resolveSavedDesktopBookmark() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: desktopBookmarkKey) else { return nil }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            UserDefaults.standard.removeObject(forKey: desktopBookmarkKey)
            return nil
        }

        if isStale {
            saveDesktopBookmark(url)
        }
        return url
    }

    private static func createDesktopShortcut(at shortcutURL: URL, pointingTo appURL: URL) throws {
        if FileManager.default.fileExists(atPath: shortcutURL.path) {
            try FileManager.default.removeItem(at: shortcutURL)
        }
        try FileManager.default.createSymbolicLink(at: shortcutURL, withDestinationURL: appURL)
    }

    private static let preferredWindowSize = CGSize(width: 1200, height: 800)
    private static let minimumWindowSize = CGSize(width: 960, height: 640)

    @MainActor
    private static func configureMainWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        if #available(iOS 16.0, *) {
            windowScene.sizeRestrictions?.minimumSize = minimumWindowSize
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 4096, height: 4096)
        }

        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
            return
        }

        if window.frame.width < minimumWindowSize.width || window.frame.height < minimumWindowSize.height {
            var frame = window.frame
            frame.size = preferredWindowSize
            window.frame = frame
        }
    }

    @MainActor
    static func quitApplication() {
        hideAllWindows()

        // Mac Catalyst does not support AppKit terminate selectors on SwiftUIApplication.
        // A clean process exit is the reliable option here.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            exit(EXIT_SUCCESS)
        }
    }

    @MainActor
    private static func hideAllWindows() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.isHidden = true
            }
        }
    }
}
#endif
