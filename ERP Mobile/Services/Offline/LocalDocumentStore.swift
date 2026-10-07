import Foundation

enum LocalDocumentEntityKind: String, Codable, Sendable {
    case cashRegisterEntry
    case supplierInvoice
    case supplierInvoiceLines
    case supplierPayment
    case supplierNIR
    case stockTransfer
    case physicalInventory
    case clientInvoice
    case clientPayment
    case zReport
    case cmGroup
    case cmMenu
    case stockSnapshot
}

struct LocalDocumentRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let companyId: UUID
    let kind: String
    let updatedAt: Date
    let payloadJSON: Data
    var pendingSync: Bool
}

enum LocalDocumentStore {
    private static let fileName = "documents.json"
    private static let remapFileName = "id_remap.json"
    private static let lock = NSLock()
    private static let pruneDays = 45

    static func loadAll(companyId: UUID) -> [LocalDocumentRecord] {
        lock.lock()
        defer { lock.unlock() }
        return OfflineFileStore.readJSON([LocalDocumentRecord].self, companyId: companyId, name: fileName) ?? []
    }

    private static func saveAll(_ records: [LocalDocumentRecord], companyId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = Calendar.current.date(byAdding: .day, value: -pruneDays, to: Date()) ?? Date.distantPast
        let pruned = records.filter { $0.pendingSync || $0.updatedAt >= cutoff }
        try? OfflineFileStore.writeJSON(pruned, companyId: companyId, name: fileName)
    }

    static func upsert<T: Encodable>(
        id: UUID,
        companyId: UUID,
        kind: LocalDocumentEntityKind,
        value: T,
        pendingSync: Bool
    ) {
        guard let data = try? OfflineFileStore.jsonEncoder.encode(value) else { return }
        var records = loadAll(companyId: companyId)
        records.removeAll { $0.id == id && $0.kind == kind.rawValue }
        records.append(
            LocalDocumentRecord(
                id: id,
                companyId: companyId,
                kind: kind.rawValue,
                updatedAt: Date(),
                payloadJSON: data,
                pendingSync: pendingSync
            )
        )
        saveAll(records, companyId: companyId)
    }

    static func load<T: Decodable>(_ type: T.Type, id: UUID, companyId: UUID, kind: LocalDocumentEntityKind) -> T? {
        guard let record = loadAll(companyId: companyId).first(where: { $0.id == id && $0.kind == kind.rawValue }) else {
            return nil
        }
        return try? OfflineFileStore.jsonDecoder.decode(T.self, from: record.payloadJSON)
    }

    static func loadAll<T: Decodable>(_ type: T.Type, companyId: UUID, kind: LocalDocumentEntityKind) -> [T] {
        loadAll(companyId: companyId)
            .filter { $0.kind == kind.rawValue }
            .compactMap { try? OfflineFileStore.jsonDecoder.decode(T.self, from: $0.payloadJSON) }
    }

    static func markSynced(id: UUID, companyId: UUID, kind: LocalDocumentEntityKind) {
        var records = loadAll(companyId: companyId)
        guard let index = records.firstIndex(where: { $0.id == id && $0.kind == kind.rawValue }) else { return }
        records[index] = LocalDocumentRecord(
            id: records[index].id,
            companyId: records[index].companyId,
            kind: records[index].kind,
            updatedAt: Date(),
            payloadJSON: records[index].payloadJSON,
            pendingSync: false
        )
        saveAll(records, companyId: companyId)
    }

    static func remove(id: UUID, companyId: UUID, kind: LocalDocumentEntityKind) {
        var records = loadAll(companyId: companyId)
        records.removeAll { $0.id == id && $0.kind == kind.rawValue }
        saveAll(records, companyId: companyId)
    }

    static func removeEntity(entityId: UUID, companyId: UUID) {
        var records = loadAll(companyId: companyId)
        records.removeAll { $0.id == entityId }
        saveAll(records, companyId: companyId)
    }

    static func isPending(id: UUID, companyId: UUID) -> Bool {
        loadAll(companyId: companyId).contains { $0.id == id && $0.pendingSync }
            || SyncOutbox.load(companyId: companyId).contains { $0.entityId == id && $0.isPendingLike }
    }

    // MARK: - ID remap

    static func remap(localId: UUID, to remoteId: UUID, companyId: UUID) {
        var map = loadRemap(companyId: companyId)
        map[localId.uuidString] = remoteId.uuidString
        try? OfflineFileStore.writeJSON(map, companyId: companyId, name: remapFileName)
    }

    static func resolvedId(_ id: UUID, companyId: UUID) -> UUID {
        let map = loadRemap(companyId: companyId)
        guard let remote = map[id.uuidString], let uuid = UUID(uuidString: remote) else { return id }
        return uuid
    }

    private static func loadRemap(companyId: UUID) -> [String: String] {
        OfflineFileStore.readJSON([String: String].self, companyId: companyId, name: remapFileName) ?? [:]
    }

    // MARK: - Invoice lines cache (for offline NIR)

    static func cacheInvoiceLines(_ lines: [SupplierInvoiceLine], invoiceId: UUID, companyId: UUID) {
        upsert(id: invoiceId, companyId: companyId, kind: .supplierInvoiceLines, value: lines, pendingSync: false)
    }

    static func cachedInvoiceLines(invoiceId: UUID, companyId: UUID) -> [SupplierInvoiceLine]? {
        load([SupplierInvoiceLine].self, id: invoiceId, companyId: companyId, kind: .supplierInvoiceLines)
    }

    // MARK: - Stock snapshot

    static func cacheStock(_ map: [UUID: Decimal], warehouseId: UUID, companyId: UUID) {
        let boxed = map.mapKeys(\.uuidString)
        upsert(id: warehouseId, companyId: companyId, kind: .stockSnapshot, value: boxed, pendingSync: false)
    }

    static func cachedStock(warehouseId: UUID, companyId: UUID) -> [UUID: Decimal]? {
        guard let boxed = load([String: Decimal].self, id: warehouseId, companyId: companyId, kind: .stockSnapshot) else {
            return nil
        }
        var result: [UUID: Decimal] = [:]
        for (key, value) in boxed {
            guard let id = UUID(uuidString: key) else { continue }
            result[id] = value
        }
        return result
    }
}

private extension Dictionary where Key == UUID, Value == Decimal {
    func mapKeys(_ transform: (UUID) -> String) -> [String: Decimal] {
        var out: [String: Decimal] = [:]
        for (key, value) in self {
            out[transform(key)] = value
        }
        return out
    }
}
