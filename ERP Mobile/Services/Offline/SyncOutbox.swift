import Foundation

enum SyncItemStatus: String, Codable, Sendable {
    case pending
    case syncing
    case failed
}

enum SyncOperationType: String, Codable, Sendable, CaseIterable {
    case cashRegisterUpsert
    case cashRegisterDelete
    case supplierInvoiceCreate
    case supplierInvoiceUpdate
    case supplierInvoiceDelete
    case supplierInvoiceLinesReplace
    case supplierPaymentCreate
    case supplierPaymentUpdate
    case supplierPaymentDelete
    case supplierReceptionClosed
    case supplierCreditOffsetsReplace
    case supplierNIRSave
    case supplierNIRDelete
    case stockTransferPost
    case stockTransferUpdate
    case stockTransferDelete
    case physicalInventoryCreate
    case physicalInventoryUpsertLine
    case physicalInventoryFinalize
    case physicalInventoryReopen
    case physicalInventoryDelete
    case physicalInventoryDeleteLine
    case clientInvoiceCreate
    case clientInvoiceUpdate
    case clientInvoiceDelete
    case clientPaymentCreate
    case clientPaymentUpdate
    case clientPaymentDelete
    case zReportUpsertBatch
    case zReportDelete
    case cmGroupCreate
    case cmGroupRename
    case cmGroupDelete
    case cmSetProductGroups
    case cmMenuCreate
    case cmMenuUpdate
    case cmMenuDelete
}

struct SyncOutboxItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let createdAt: Date
    var updatedAt: Date
    var status: SyncItemStatus
    var attempts: Int
    var lastError: String?
    let operationType: SyncOperationType
    let entityKind: String
    let entityId: UUID
    let title: String
    let payloadJSON: Data

    var isPendingLike: Bool {
        status == .pending || status == .failed || status == .syncing
    }
}

enum SyncOutbox {
    private static let fileName = "outbox.json"
    private static let lock = NSLock()

    static func load(companyId: UUID) -> [SyncOutboxItem] {
        lock.lock()
        defer { lock.unlock() }
        return OfflineFileStore.readJSON([SyncOutboxItem].self, companyId: companyId, name: fileName) ?? []
    }

    static func save(_ items: [SyncOutboxItem], companyId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        try? OfflineFileStore.writeJSON(items, companyId: companyId, name: fileName)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .offlineSyncStateDidChange, object: nil)
            SyncEngine.shared.refreshPublishedState(companyId: companyId)
        }
    }

    static func enqueue<Payload: Encodable>(
        companyId: UUID,
        operationType: SyncOperationType,
        entityKind: String,
        entityId: UUID,
        title: String,
        payload: Payload
    ) throws {
        let data = try OfflineFileStore.jsonEncoder.encode(payload)
        var items = load(companyId: companyId)
        // Replace pending/failed op for same entity+type (last-write-wins).
        items.removeAll {
            $0.entityId == entityId
                && $0.operationType == operationType
                && ($0.status == .pending || $0.status == .failed)
        }
        let item = SyncOutboxItem(
            id: UUID(),
            companyId: companyId,
            createdAt: Date(),
            updatedAt: Date(),
            status: .pending,
            attempts: 0,
            lastError: nil,
            operationType: operationType,
            entityKind: entityKind,
            entityId: entityId,
            title: title,
            payloadJSON: data
        )
        items.append(item)
        save(items, companyId: companyId)
    }

    static func pendingCount(companyId: UUID) -> Int {
        load(companyId: companyId).filter(\.isPendingLike).count
    }

    static func failedItems(companyId: UUID) -> [SyncOutboxItem] {
        load(companyId: companyId).filter { $0.status == .failed }
    }

    static func update(_ item: SyncOutboxItem, companyId: UUID) {
        var items = load(companyId: companyId)
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        save(items, companyId: companyId)
    }

    static func remove(id: UUID, companyId: UUID) {
        var items = load(companyId: companyId)
        items.removeAll { $0.id == id }
        save(items, companyId: companyId)
    }

    static func discard(id: UUID, companyId: UUID) {
        let entityId = load(companyId: companyId).first(where: { $0.id == id })?.entityId
        remove(id: id, companyId: companyId)
        if let entityId {
            LocalDocumentStore.removeEntity(entityId: entityId, companyId: companyId)
        }
    }

    static func resetFailedToPending(id: UUID, companyId: UUID) {
        var items = load(companyId: companyId)
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .pending
        items[index].lastError = nil
        items[index].updatedAt = Date()
        save(items, companyId: companyId)
    }
}
