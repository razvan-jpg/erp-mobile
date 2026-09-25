import Foundation
import Supabase

enum StockTransferService {
    private static let client = SupabaseManager.client

    private struct TransferLineParam: Encodable {
        let productId: UUID
        let cantitate: Double

        enum CodingKeys: String, CodingKey {
            case productId = "product_id"
            case cantitate
        }
    }

    private struct PostParams: Encodable {
        let pCompanyId: UUID
        let pDataBon: String
        let pSourceWarehouseId: UUID
        let pDestinationWarehouseId: UUID
        let pObservatii: String?
        let pLines: [TransferLineParam]

        enum CodingKeys: String, CodingKey {
            case pCompanyId = "p_company_id"
            case pDataBon = "p_data_bon"
            case pSourceWarehouseId = "p_source_warehouse_id"
            case pDestinationWarehouseId = "p_destination_warehouse_id"
            case pObservatii = "p_observatii"
            case pLines = "p_lines"
        }
    }

    private struct UpdateParams: Encodable {
        let pTransferId: UUID
        let pDataBon: String
        let pSourceWarehouseId: UUID
        let pDestinationWarehouseId: UUID
        let pObservatii: String?
        let pLines: [TransferLineParam]

        enum CodingKeys: String, CodingKey {
            case pTransferId = "p_transfer_id"
            case pDataBon = "p_data_bon"
            case pSourceWarehouseId = "p_source_warehouse_id"
            case pDestinationWarehouseId = "p_destination_warehouse_id"
            case pObservatii = "p_observatii"
            case pLines = "p_lines"
        }
    }

    private struct DeleteParams: Encodable {
        let pTransferId: UUID

        enum CodingKeys: String, CodingKey {
            case pTransferId = "p_transfer_id"
        }
    }

    static let transferableKinds: Set<ProductKind> = [
        .materiePrima, .marfa, .ambalaj, .materialeConsumabile
    ]

    static func fetchTransfers(companyId: UUID) async throws -> [StockTransfer] {
        try await client
            .from("stock_transfers")
            .select("id, company_id, numar, data_bon, source_warehouse_id, destination_warehouse_id, observatii, created_at")
            .eq("company_id", value: companyId.uuidString)
            .order("data_bon", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchTransfer(id: UUID) async throws -> StockTransfer {
        let rows: [StockTransfer] = try await client
            .from("stock_transfers")
            .select("id, company_id, numar, data_bon, source_warehouse_id, destination_warehouse_id, observatii, created_at")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let transfer = rows.first else { throw ServiceError.invalidResponse }
        return transfer
    }

    static func fetchLines(transferId: UUID) async throws -> [StockTransferLine] {
        try await client
            .from("stock_transfer_lines")
            .select("id, transfer_id, product_id, numar_linie, cantitate, unitate_masura, product:products(id, denumire, cod, cod_bare, unitate_masura, tip)")
            .eq("transfer_id", value: transferId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
    }

    /// Stoc pe gestiune sursă: productId → cantitate.
    static func fetchAvailableQuantities(
        companyId: UUID,
        warehouseId: UUID
    ) async throws -> [UUID: Decimal] {
        let rows = try await InventoryService.fetchStockRows(companyId: companyId, warehouseId: warehouseId)
        var map: [UUID: Decimal] = [:]
        for row in rows {
            map[row.productId] = row.cantitate
        }
        return map
    }

    static func postTransfer(
        companyId: UUID,
        dataBon: Date,
        sourceWarehouseId: UUID,
        destinationWarehouseId: UUID,
        observatii: String?,
        lines: [(productId: UUID, quantity: Decimal)]
    ) async throws -> UUID {
        let payload = PostParams(
            pCompanyId: companyId,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pSourceWarehouseId: sourceWarehouseId,
            pDestinationWarehouseId: destinationWarehouseId,
            pObservatii: observatii,
            pLines: lines.map {
                TransferLineParam(
                    productId: $0.productId,
                    cantitate: NSDecimalNumber(decimal: $0.quantity).doubleValue
                )
            }
        )
        do {
            let id: UUID = try await client
                .rpc("post_stock_transfer", params: payload)
                .execute()
                .value
            return id
        } catch {
            throw StockTransferError.map(error)
        }
    }

    static func updateTransfer(
        id: UUID,
        dataBon: Date,
        sourceWarehouseId: UUID,
        destinationWarehouseId: UUID,
        observatii: String?,
        lines: [(productId: UUID, quantity: Decimal)]
    ) async throws {
        let payload = UpdateParams(
            pTransferId: id,
            pDataBon: SupabaseDecoding.dateOnlyString(from: dataBon),
            pSourceWarehouseId: sourceWarehouseId,
            pDestinationWarehouseId: destinationWarehouseId,
            pObservatii: observatii,
            pLines: lines.map {
                TransferLineParam(
                    productId: $0.productId,
                    cantitate: NSDecimalNumber(decimal: $0.quantity).doubleValue
                )
            }
        )
        do {
            try await client
                .rpc("update_stock_transfer", params: payload)
                .execute()
        } catch {
            throw StockTransferError.map(error)
        }
    }

    static func deleteTransfer(id: UUID) async throws {
        do {
            try await client
                .rpc("delete_stock_transfer", params: DeleteParams(pTransferId: id))
                .execute()
        } catch {
            throw StockTransferError.map(error)
        }
    }

    static func prepareExport(
        company: Company?,
        transfer: StockTransfer,
        lines: [StockTransferLine],
        sourceWarehouseName: String,
        destinationWarehouseName: String
    ) async throws -> StockTransferExportItem {
        let snapshot = StockTransferSnapshot(
            company: company,
            transfer: transfer,
            lines: lines,
            sourceWarehouseName: sourceWarehouseName,
            destinationWarehouseName: destinationWarehouseName,
            generatedAt: Date()
        )
        return try await Task.detached(priority: .userInitiated) {
            let pdfURL = try StockTransferPDFBuilder.writeTemporaryPDF(from: snapshot)
            let pdfData = try Data(contentsOf: pdfURL)
            return StockTransferExportItem(
                title: StockTransferPDFBuilder.exportFileName(from: snapshot),
                pdfData: pdfData,
                pdfURL: pdfURL
            )
        }.value
    }
}

struct StockTransferExportItem: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let pdfData: Data
    let pdfURL: URL
}
