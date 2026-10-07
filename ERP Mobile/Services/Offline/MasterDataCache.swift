import Foundation

struct MasterDataSnapshot: Codable, Sendable {
    var updatedAt: Date
    var products: [Product]
    var warehouses: [CompanyWarehouse]
    var workLocations: [CompanyWorkLocation]
    var suppliers: [Supplier]
    var clients: [Client]
}

enum MasterDataCache {
    private static let fileName = "master_data.json"

    static func load(companyId: UUID) -> MasterDataSnapshot? {
        OfflineFileStore.readJSON(MasterDataSnapshot.self, companyId: companyId, name: fileName)
    }

    static func save(_ snapshot: MasterDataSnapshot, companyId: UUID) {
        try? OfflineFileStore.writeJSON(snapshot, companyId: companyId, name: fileName)
    }

    static func products(companyId: UUID) -> [Product] {
        load(companyId: companyId)?.products ?? []
    }

    static func warehouses(companyId: UUID) -> [CompanyWarehouse] {
        load(companyId: companyId)?.warehouses ?? []
    }

    static func workLocations(companyId: UUID) -> [CompanyWorkLocation] {
        load(companyId: companyId)?.workLocations ?? []
    }

    static func suppliers(companyId: UUID) -> [Supplier] {
        load(companyId: companyId)?.suppliers ?? []
    }

    static func clients(companyId: UUID) -> [Client] {
        load(companyId: companyId)?.clients ?? []
    }

    static func isStale(companyId: UUID, maxAge: TimeInterval = 86_400) -> Bool {
        guard let snap = load(companyId: companyId) else { return true }
        return Date().timeIntervalSince(snap.updatedAt) > maxAge
    }

    @MainActor
    static func refreshIfPossible(companyId: UUID) async {
        guard NetworkMonitor.shared.isOnline else { return }
        do {
            async let products = ProductService.fetchProducts(companyId: companyId)
            async let warehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            async let workLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            async let suppliers = SupplierService.fetchSuppliers(activeOnly: false)
            async let clients = ClientService.fetchClients(activeOnly: false)
            let snapshot = MasterDataSnapshot(
                updatedAt: Date(),
                products: try await products,
                warehouses: try await warehouses,
                workLocations: try await workLocations,
                suppliers: try await suppliers,
                clients: try await clients
            )
            save(snapshot, companyId: companyId)
        } catch {
            // Keep previous snapshot; sync will retry later.
        }
    }
}
