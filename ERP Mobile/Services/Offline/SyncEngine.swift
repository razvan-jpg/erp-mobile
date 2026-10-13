import Combine
import Foundation
import UIKit

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var pendingCount = 0
    @Published private(set) var failedCount = 0
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var activeCompanyId: UUID?

    private var syncTask: Task<Void, Never>?
    private var syncQueued = false
    private var didStartMonitor = false
    private var pollTimer: Timer?

    private init() {}

    func start() {
        guard !didStartMonitor else { return }
        didStartMonitor = true
        _ = NetworkMonitor.shared
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleSync(reason: "foreground")
            }
        }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncIfPending(reason: "connectivity_poll")
            }
        }
    }

    /// Când există operații în coadă, retrimite de îndată ce rețeaua răspunde.
    private func syncIfPending(reason: String) {
        guard let companyId = activeCompanyId else { return }
        let waiting = SyncOutbox.load(companyId: companyId).contains { $0.status == .pending || $0.status == .failed }
        guard waiting else { return }
        scheduleSync(reason: reason)
    }

    func setActiveCompany(_ companyId: UUID?) {
        activeCompanyId = companyId
        if let companyId {
            refreshPublishedState(companyId: companyId)
            scheduleSync(reason: "company_selected")
            Task {
                await MasterDataCache.refreshIfPossible(companyId: companyId)
            }
        } else {
            pendingCount = 0
            failedCount = 0
        }
    }

    func refreshPublishedState(companyId: UUID) {
        let items = SyncOutbox.load(companyId: companyId)
        pendingCount = items.filter { $0.status == .pending || $0.status == .syncing }.count
        failedCount = items.filter { $0.status == .failed }.count
    }

    func scheduleSync(reason: String) {
        start()
        guard let companyId = activeCompanyId else { return }
        guard NetworkMonitor.shared.isOnline else {
            refreshPublishedState(companyId: companyId)
            return
        }
        if syncTask != nil {
            syncQueued = true
            return
        }
        syncTask = Task { [weak self] in
            await self?.drain(companyId: companyId)
            self?.syncTask = nil
            if self?.syncQueued == true {
                self?.syncQueued = false
                self?.scheduleSync(reason: "queued")
            }
        }
    }

    func retryAllFailed() {
        guard let companyId = activeCompanyId else { return }
        for item in SyncOutbox.failedItems(companyId: companyId) {
            SyncOutbox.resetFailedToPending(id: item.id, companyId: companyId)
        }
        scheduleSync(reason: "retry_failed")
    }

    func discardItem(id: UUID) {
        guard let companyId = activeCompanyId else { return }
        SyncOutbox.discard(id: id, companyId: companyId)
        refreshPublishedState(companyId: companyId)
    }

    func pendingItems() -> [SyncOutboxItem] {
        guard let companyId = activeCompanyId else { return [] }
        return SyncOutbox.load(companyId: companyId).filter(\.isPendingLike)
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func drain(companyId: UUID) async {
        isSyncing = true
        lastError = nil
        defer {
            isSyncing = false
            refreshPublishedState(companyId: companyId)
            lastSyncAt = Date()
            NotificationCenter.default.post(name: .offlineSyncStateDidChange, object: nil)
        }

        let items = SyncOutbox.load(companyId: companyId)
            .filter { $0.status == .pending || $0.status == .failed }
            .sorted { $0.createdAt < $1.createdAt }

        for var item in items {
            guard !Task.isCancelled else { break }
            guard NetworkMonitor.shared.isOnline else { break }

            item.status = .syncing
            item.updatedAt = Date()
            SyncOutbox.update(item, companyId: companyId)

            do {
                try await SyncOperationExecutor.execute(item)
                SyncOutbox.remove(id: item.id, companyId: companyId)
                if let kind = LocalDocumentEntityKind(rawValue: item.entityKind) {
                    LocalDocumentStore.markSynced(id: item.entityId, companyId: companyId, kind: kind)
                }
            } catch {
                item.status = .failed
                item.attempts += 1
                item.lastError = error.localizedDescription
                item.updatedAt = Date()
                SyncOutbox.update(item, companyId: companyId)
                lastError = error.localizedDescription
                if !OfflineNetwork.isTransient(error) {
                    break
                }
            }
        }

        await MasterDataCache.refreshIfPossible(companyId: companyId)
    }
}
