import Foundation
import Supabase

enum ClientZReportService {
    private static let client = SupabaseManager.client

    static func fetchReports(companyId: UUID) async throws -> [CompanyZReportRecord] {
        try await client
            .from("company_z_reports")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("report_date", ascending: true)
            .order("z_number", ascending: true)
            .execute()
            .value
    }

    static func upsertReports(companyId: UUID, reports: [ZReportData]) async throws -> Int {
        let rows = reports.compactMap { report -> CompanyZReportUpsert? in
            guard report.zNumber > 0, report.importDedupKey != nil else { return nil }
            return CompanyZReportUpsert(companyId: companyId, report: report)
        }
        guard !rows.isEmpty else { return 0 }

        var saved: [CompanyZReportRecord] = try await client
            .from("company_z_reports")
            .upsert(rows, onConflict: "company_id,dedup_key")
            .select()
            .execute()
            .value

        if saved.isEmpty {
            // Fallback: `.in(dedup_key, …)` nu e sigur pentru chei cu `:` / `|`.
            let dedupKeys = Set(rows.map(\.dedupKey))
            let existing = try await fetchReports(companyId: companyId)
            saved = existing.filter { dedupKeys.contains($0.dedupKey) }
        }

        for record in saved {
            try await syncCollections(for: record)
        }

        return saved.isEmpty ? 0 : saved.count
    }

    static func deleteReport(id: UUID, companyId: UUID) async throws {
        try await deleteReports(ids: [id], companyId: companyId)
    }

    static func deleteReports(ids: [UUID], companyId: UUID) async throws {
        guard !ids.isEmpty else { return }
        _ = try await client
            .from("company_z_reports")
            .delete()
            .eq("company_id", value: companyId.uuidString)
            .in("id", values: ids.map(\.uuidString))
            .execute()
    }

    /// Resincronizează încasările (casă / bancă / plată modernă) pentru un Raport Z salvat.
    static func syncCollections(for record: CompanyZReportRecord) async throws {
        _ = try await client
            .from("company_z_report_collections")
            .delete()
            .eq("z_report_id", value: record.id.uuidString)
            .execute()

        var inserts: [CompanyZReportCollectionUpsert] = []
        if record.numerar > 0 {
            inserts.append(CompanyZReportCollectionUpsert(record: record, type: .numerar, amount: record.numerar))
        }
        if record.card > 0 {
            inserts.append(CompanyZReportCollectionUpsert(record: record, type: .card, amount: record.card))
        }
        if record.plataModerna > 0 {
            inserts.append(CompanyZReportCollectionUpsert(record: record, type: .plataModerna, amount: record.plataModerna))
        }

        guard !inserts.isEmpty else { return }

        _ = try await client
            .from("company_z_report_collections")
            .insert(inserts)
            .execute()
    }

    /// Backfill încasări pentru rapoarte existente (fără colecții).
    static func backfillCollections(companyId: UUID) async throws {
        let reports = try await fetchReports(companyId: companyId)
        for record in reports {
            try await syncCollections(for: record)
        }
    }
}
