import Foundation

enum CashRegisterExportDirectoryResolver {
    private static let bookmarkKeyPrefix = "utility.cashregister.export.bookmark."

    static func defaultDirectory(companyName: String) -> URL {
        let sanitized = sanitize(companyName)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents
            .appendingPathComponent("ERP Mobile", isDirectory: true)
            .appendingPathComponent("Rapoarte Z", isDirectory: true)
            .appendingPathComponent(sanitized, isDirectory: true)
    }

    static func resolve(storedPath: String?, companyName: String, companyId: UUID? = nil) -> URL {
        if let companyId, let bookmarkURL = resolveBookmark(companyId: companyId) {
            return bookmarkURL
        }
        if let storedPath, !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: storedPath, isDirectory: true)
        }
        return defaultDirectory(companyName: companyName)
    }

    static func saveBookmark(for url: URL, companyId: UUID) {
        let startedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let bookmark = try? url.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(bookmark, forKey: bookmarkKeyPrefix + companyId.uuidString)
    }

    static func resolveBookmark(companyId: UUID) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKeyPrefix + companyId.uuidString) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        if isStale {
            saveBookmark(for: url, companyId: companyId)
        }
        return url
    }

    static func startAccess(for url: URL, companyId: UUID?) -> Bool {
        if let companyId, let bookmarkURL = resolveBookmark(companyId: companyId), bookmarkURL.path == url.path {
            return bookmarkURL.startAccessingSecurityScopedResource()
        }
        return url.startAccessingSecurityScopedResource()
    }

    static func stopAccess(for url: URL, companyId: UUID?) {
        if let companyId, let bookmarkURL = resolveBookmark(companyId: companyId), bookmarkURL.path == url.path {
            bookmarkURL.stopAccessingSecurityScopedResource()
            return
        }
        url.stopAccessingSecurityScopedResource()
    }

    static func ensureExists(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    private static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = trimmed.components(separatedBy: invalid).joined(separator: " ")
        return cleaned.isEmpty ? "Firma" : cleaned
    }
}
