import Foundation

enum OfflineFileStore {
    private static let folderName = "OfflineSync"

    static func companyDirectory(companyId: UUID) throws -> URL {
        let root = try applicationSupportRoot()
        let dir = root
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(companyId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func fileURL(companyId: UUID, name: String) throws -> URL {
        try companyDirectory(companyId: companyId).appendingPathComponent(name)
    }

    static func readData(companyId: UUID, name: String) -> Data? {
        guard let url = try? fileURL(companyId: companyId, name: name) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func writeData(_ data: Data, companyId: UUID, name: String) throws {
        let url = try fileURL(companyId: companyId, name: name)
        try data.write(to: url, options: [.atomic])
    }

    static func remove(companyId: UUID, name: String) {
        guard let url = try? fileURL(companyId: companyId, name: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func readJSON<T: Decodable>(_ type: T.Type, companyId: UUID, name: String) -> T? {
        guard let data = readData(companyId: companyId, name: name) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    static func writeJSON<T: Encodable>(_ value: T, companyId: UUID, name: String) throws {
        let data = try encoder.encode(value)
        try writeData(data, companyId: companyId, name: name)
    }

    private static func applicationSupportRoot() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ServiceError.server("Application Support unavailable")
        }
        let app = base.appendingPathComponent("ERPMobile", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        return app
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static var jsonEncoder: JSONEncoder { encoder }
    static var jsonDecoder: JSONDecoder { decoder }
}
