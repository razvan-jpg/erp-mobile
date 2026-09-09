import Foundation

enum SupabasePaging {
    /// Request a large page; if the server caps lower (e.g. 20), `fetchAll` still walks by `page.count`.
    static let pageSize = 1000

    static func fetchAll<T>(
        _ fetchPage: (_ from: Int, _ to: Int) async throws -> [T]
    ) async throws -> [T] {
        var all: [T] = []
        var offset = 0
        while true {
            let page = try await fetchPage(offset, offset + pageSize - 1)
            if page.isEmpty { break }
            all.append(contentsOf: page)
            offset += page.count
            if page.count < pageSize { break }
        }
        return all
    }
}
