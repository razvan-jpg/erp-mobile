import Foundation

enum OfflineCompany {
    @MainActor
    static var currentId: UUID? { SyncEngine.shared.activeCompanyId }

    static func requireId() async -> UUID {
        await MainActor.run { SyncEngine.shared.activeCompanyId } ?? UUID()
    }
}
