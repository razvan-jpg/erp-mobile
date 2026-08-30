import Foundation

enum PartnerRoleService {
    static func hasClientCounterpart(for supplier: Supplier) async throws -> Bool {
        guard let normalized = EFacturaInvoiceParser.normalizeCUI(supplier.cui) else { return false }
        let clients = try await ClientService.fetchClients()
        return clients.contains { client in
            guard let clientCUI = EFacturaInvoiceParser.normalizeCUI(client.cui) else { return false }
            return clientCUI == normalized
        }
    }

    static func hasSupplierCounterpart(for client: Client) async throws -> Bool {
        guard let normalized = EFacturaInvoiceParser.normalizeCUI(client.cui) else { return false }
        let suppliers = try await SupplierService.fetchSuppliers()
        return suppliers.contains { supplier in
            guard let supplierCUI = EFacturaInvoiceParser.normalizeCUI(supplier.cui) else { return false }
            return supplierCUI == normalized
        }
    }
}
