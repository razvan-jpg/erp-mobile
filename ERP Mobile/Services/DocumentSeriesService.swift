import Foundation
import Supabase

enum DocumentSeriesKind: String, Codable, CaseIterable, Identifiable {
    case invoice = "factura"
    case fiscalCash = "factura_fiscala_casa"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invoice: return L10n.tr("module.nomenclatoare.document_series.kind_invoice")
        case .fiscalCash: return L10n.tr("module.nomenclatoare.document_series.kind_fiscal")
        }
    }
}

struct DocumentSeries: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var kind: String
    var serie: String
    var nextNumber: Int
    var workLocationId: UUID?
    var isActive: Bool

    var seriesKind: DocumentSeriesKind {
        DocumentSeriesKind(rawValue: kind) ?? .invoice
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, serie
        case companyId = "company_id"
        case nextNumber = "next_number"
        case workLocationId = "work_location_id"
        case isActive = "is_active"
    }
}

private struct DocumentSeriesWrite: Encodable {
    let companyId: UUID
    let kind: String
    let serie: String
    let nextNumber: Int
    let workLocationId: UUID?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case kind, serie
        case companyId = "company_id"
        case nextNumber = "next_number"
        case workLocationId = "work_location_id"
        case isActive = "is_active"
    }
}

enum DocumentSeriesService {
    private static let client = SupabaseManager.client

    static func fetch(companyId: UUID) async throws -> [DocumentSeries] {
        let rows: [DocumentSeries] = try await client
            .from("document_series")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("serie", ascending: true)
            .execute()
            .value
        return rows
    }

    static func fiscalSeries(companyId: UUID, workLocationId: UUID) async throws -> DocumentSeries? {
        let rows: [DocumentSeries] = try await client
            .from("document_series")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("work_location_id", value: workLocationId.uuidString)
            .eq("kind", value: DocumentSeriesKind.fiscalCash.rawValue)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func save(
        id: UUID?,
        companyId: UUID,
        kind: DocumentSeriesKind,
        serie: String,
        nextNumber: Int,
        workLocationId: UUID?,
        isActive: Bool
    ) async throws {
        let payload = DocumentSeriesWrite(
            companyId: companyId,
            kind: kind.rawValue,
            serie: serie,
            nextNumber: nextNumber,
            workLocationId: kind == .fiscalCash ? workLocationId : nil,
            isActive: isActive
        )
        if let id {
            try await client
                .from("document_series")
                .update(payload)
                .eq("id", value: id.uuidString)
                .execute()
        } else {
            try await client
                .from("document_series")
                .insert(payload)
                .execute()
        }
    }

    static func consumeFiscalNumber(id: UUID) async throws -> (serie: String, number: Int) {
        struct Params: Encodable {
            let seriesId: UUID
            enum CodingKeys: String, CodingKey { case seriesId = "p_series_id" }
        }
        struct Issued: Decodable {
            let serie: String
            let issuedNumber: Int
            enum CodingKeys: String, CodingKey {
                case serie
                case issuedNumber = "issued_number"
            }
        }
        let rows: [Issued] = try await client
            .rpc("consume_fiscal_invoice_number", params: Params(seriesId: id))
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return (row.serie, row.issuedNumber)
    }

    static func delete(id: UUID) async throws {
        try await client
            .from("document_series")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
