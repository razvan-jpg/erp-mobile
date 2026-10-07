import Foundation

enum OfflineAwareGateway {
    /// Runs a remote write when online; on offline / transient network error, enqueues and returns optimistic value.
    static func run<T, Payload: Encodable>(
        companyId: UUID,
        operation: SyncOperationType,
        entityKind: String,
        entityId: UUID,
        title: String,
        payload: Payload,
        optimistic: T,
        remote: () async throws -> T
    ) async throws -> T {
        if OfflineWriteContext.isSyncDrain {
            return try await remote()
        }

        let online = await MainActor.run { NetworkMonitor.shared.isOnline }
        if online {
            do {
                return try await remote()
            } catch {
                guard OfflineNetwork.isTransient(error) else { throw error }
            }
        }

        try SyncOutbox.enqueue(
            companyId: companyId,
            operationType: operation,
            entityKind: entityKind,
            entityId: entityId,
            title: title,
            payload: payload
        )
        await MainActor.run {
            SyncEngine.shared.refreshPublishedState(companyId: companyId)
        }
        return optimistic
    }

    static func runVoid<Payload: Encodable>(
        companyId: UUID,
        operation: SyncOperationType,
        entityKind: String,
        entityId: UUID,
        title: String,
        payload: Payload,
        remote: () async throws -> Void
    ) async throws {
        _ = try await run(
            companyId: companyId,
            operation: operation,
            entityKind: entityKind,
            entityId: entityId,
            title: title,
            payload: payload,
            optimistic: true,
            remote: {
                try await remote()
                return true
            }
        )
    }
}
