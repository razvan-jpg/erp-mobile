import Foundation

enum PartnerService {
    static func fetchPartnerListRows() async throws -> [PartnerListRow] {
        async let suppliersTask = SupplierService.fetchSupplierListRows()
        async let clientsTask = ClientService.fetchClientListRows()
        let (supplierRows, clientRows) = try await (suppliersTask, clientsTask)
        return merge(supplierRows: supplierRows, clientRows: clientRows)
    }

    private static func merge(
        supplierRows: [SupplierListRow],
        clientRows: [ClientListRow]
    ) -> [PartnerListRow] {
        var clientByCUI: [String: ClientListRow] = [:]
        var clientsWithoutCUI: [ClientListRow] = []

        for row in clientRows {
            if let key = normalizedCUIKey(from: row.client.cui) {
                clientByCUI[key] = row
            } else {
                clientsWithoutCUI.append(row)
            }
        }

        var partners: [PartnerListRow] = []
        var matchedClientKeys: Set<String> = []

        for supplierRow in supplierRows {
            if let key = normalizedCUIKey(from: supplierRow.supplier.cui),
               let clientRow = clientByCUI[key] {
                matchedClientKeys.insert(key)
                partners.append(
                    PartnerListRow(
                        id: "cui:\(key)",
                        denumire: preferredName(
                            supplierName: supplierRow.supplier.denumire,
                            clientName: clientRow.client.denumire
                        ),
                        cui: supplierRow.supplier.cui ?? clientRow.client.cui,
                        telefon: supplierRow.supplier.telefon ?? clientRow.client.telefon,
                        role: .both,
                        supplierRow: supplierRow,
                        clientRow: clientRow
                    )
                )
            } else {
                partners.append(
                    PartnerListRow(
                        id: "supplier:\(supplierRow.supplier.id.uuidString)",
                        denumire: supplierRow.supplier.denumire,
                        cui: supplierRow.supplier.cui,
                        telefon: supplierRow.supplier.telefon,
                        role: .supplierOnly,
                        supplierRow: supplierRow,
                        clientRow: nil
                    )
                )
            }
        }

        for (key, clientRow) in clientByCUI where !matchedClientKeys.contains(key) {
            partners.append(
                PartnerListRow(
                    id: "client:\(clientRow.client.id.uuidString)",
                    denumire: clientRow.client.denumire,
                    cui: clientRow.client.cui,
                    telefon: clientRow.client.telefon,
                    role: .clientOnly,
                    supplierRow: nil,
                    clientRow: clientRow
                )
            )
        }

        for clientRow in clientsWithoutCUI {
            partners.append(
                PartnerListRow(
                    id: "client:\(clientRow.client.id.uuidString)",
                    denumire: clientRow.client.denumire,
                    cui: clientRow.client.cui,
                    telefon: clientRow.client.telefon,
                    role: .clientOnly,
                    supplierRow: nil,
                    clientRow: clientRow
                )
            )
        }

        return partners.sorted {
            $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending
        }
    }

    private static func normalizedCUIKey(from cui: String?) -> String? {
        guard let cui, let normalized = EFacturaInvoiceParser.normalizeCUI(cui) else { return nil }
        return normalized
    }

    private static func preferredName(supplierName: String, clientName: String) -> String {
        let supplierTrimmed = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientTrimmed = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        if supplierTrimmed.caseInsensitiveCompare(clientTrimmed) == .orderedSame {
            return supplierTrimmed
        }
        return supplierTrimmed.count >= clientTrimmed.count ? supplierTrimmed : clientTrimmed
    }
}
