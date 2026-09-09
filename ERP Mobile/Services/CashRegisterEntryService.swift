import Foundation
import Supabase

enum CashRegisterEntryService {
    private static let client = SupabaseManager.client

    static var usesLocalFallback: Bool {
        get { UserDefaults.standard.bool(forKey: "cash_register_entries_local_fallback") }
        set { UserDefaults.standard.set(newValue, forKey: "cash_register_entries_local_fallback") }
    }

    static var lastSyncWarning: String?

    static func fetchEntries(companyId: UUID) async throws -> [CashRegisterManualEntry] {
        lastSyncWarning = nil
        let local = CashRegisterManualEntryStore.loadLocalOnly(companyId: companyId)
        do {
            let remote = try await fetchRemoteEntries(companyId: companyId)
            usesLocalFallback = false
            let merged = merge(remote: remote, local: local)
            CashRegisterManualEntryStore.save(merged, companyId: companyId)
            await pushLocalOnly(local: local, remote: remote, companyId: companyId)
            let afterPush = CashRegisterManualEntryStore.loadLocalOnly(companyId: companyId)
            return merge(remote: remote, local: afterPush)
        } catch {
            if isMissingRemoteTableError(error) {
                usesLocalFallback = true
                return local
            }
            if !local.isEmpty {
                usesLocalFallback = true
                lastSyncWarning = error.localizedDescription
                return local
            }
            throw error
        }
    }

    static func fetchEntries(companyId: UUID, from startDate: Date, to endDate: Date) async throws -> [CashRegisterManualEntry] {
        let all = try await fetchEntries(companyId: companyId)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return all.filter { entry in
            let day = calendar.startOfDay(for: entry.date)
            return day >= start && day <= end
        }
    }

    static func insert(_ entry: CashRegisterManualEntry, companyId: UUID) async throws -> CashRegisterManualEntry {
        lastSyncWarning = nil
        CashRegisterManualEntryStore.upsert(entry, companyId: companyId)
        do {
            let saved = try await upsertRemote(entry, companyId: companyId)
            usesLocalFallback = false
            CashRegisterManualEntryStore.upsert(saved, companyId: companyId)
            return saved
        } catch {
            if isMissingRemoteTableError(error) {
                usesLocalFallback = true
                return entry
            }
            usesLocalFallback = true
            lastSyncWarning = error.localizedDescription
            return entry
        }
    }

    static func delete(id: UUID, companyId: UUID) async throws {
        CashRegisterManualEntryStore.delete(id: id, companyId: companyId)
        do {
            _ = try await client
                .from("company_cash_register_entries")
                .delete()
                .eq("company_id", value: companyId.uuidString)
                .eq("id", value: id.uuidString)
                .execute()
            usesLocalFallback = false
        } catch {
            if isMissingRemoteTableError(error) {
                usesLocalFallback = true
                return
            }
            throw error
        }
    }

    static func migrateLocalEntriesIfNeeded(companyId: UUID) async {
        let local = CashRegisterManualEntryStore.loadLocalOnly(companyId: companyId)
        guard !local.isEmpty else { return }
        do {
            let remote = try await fetchRemoteEntries(companyId: companyId)
            await pushLocalOnly(local: local, remote: remote, companyId: companyId)
        } catch {
            usesLocalFallback = true
        }
    }

    private static func fetchRemoteEntries(companyId: UUID) async throws -> [CashRegisterManualEntry] {
        let rows: [CompanyCashRegisterEntryRecord] = try await client
            .from("company_cash_register_entries")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .order("entry_date", ascending: true)
            .order("document_number", ascending: true)
            .execute()
            .value
        return rows.map(\.asManualEntry)
    }

    private static func upsertRemote(
        _ entry: CashRegisterManualEntry,
        companyId: UUID
    ) async throws -> CashRegisterManualEntry {
        let payload = CompanyCashRegisterEntryUpsert(entry: entry, companyId: companyId)
        let rows: [CompanyCashRegisterEntryRecord] = try await client
            .from("company_cash_register_entries")
            .upsert(payload, onConflict: "id")
            .select()
            .execute()
            .value
        guard let saved = rows.first else { throw ServiceError.invalidResponse }
        return saved.asManualEntry
    }

    private static func pushLocalOnly(
        local: [CashRegisterManualEntry],
        remote: [CashRegisterManualEntry],
        companyId: UUID
    ) async {
        let remoteIds = Set(remote.map(\.id))
        for entry in local where !remoteIds.contains(entry.id) {
            do {
                let saved = try await upsertRemote(entry, companyId: companyId)
                CashRegisterManualEntryStore.upsert(saved, companyId: companyId)
            } catch {
                if isMissingRemoteTableError(error) {
                    usesLocalFallback = true
                    return
                }
                lastSyncWarning = error.localizedDescription
                return
            }
        }
    }

    private static func merge(
        remote: [CashRegisterManualEntry],
        local: [CashRegisterManualEntry]
    ) -> [CashRegisterManualEntry] {
        var byId: [UUID: CashRegisterManualEntry] = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for entry in remote {
            byId[entry.id] = entry
        }
        return byId.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.documentNumber.localizedCaseInsensitiveCompare(rhs.documentNumber) == .orderedAscending
        }
    }

    private static func isMissingRemoteTableError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("pgrst205") { return true }
        if message.contains("schema cache") { return true }
        if message.contains("relation") && message.contains("does not exist") { return true }
        return false
    }
}

struct CompanyCashRegisterEntryRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let companyId: UUID
    let workLocationId: UUID?
    let entryDate: Date
    let kind: String
    let documentNumber: String
    let explanation: String
    @SupabaseDecimal var amount: Decimal
    let isIncasare: Bool
    let supplierId: UUID?
    let supplierName: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case workLocationId = "work_location_id"
        case entryDate = "entry_date"
        case kind
        case documentNumber = "document_number"
        case explanation
        case amount
        case isIncasare = "is_incasare"
        case supplierId = "supplier_id"
        case supplierName = "supplier_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var asManualEntry: CashRegisterManualEntry {
        CashRegisterManualEntry(
            id: id,
            date: entryDate,
            casaTarget: workLocationId.map { CashRegisterCasaTarget.workLocation($0) } ?? .headquarters,
            kind: CashRegisterManualEntryKind.fromDatabase(kind, isIncasare: isIncasare),
            documentNumber: documentNumber,
            explanation: explanation,
            amount: amount,
            supplierId: supplierId,
            supplierName: supplierName
        )
    }
}

struct CompanyCashRegisterEntryUpsert: Encodable, Sendable {
    let id: UUID
    let companyId: UUID
    let workLocationId: UUID?
    let entryDate: String
    let kind: String
    let documentNumber: String
    let explanation: String
    let amount: String
    let isIncasare: Bool
    let supplierId: UUID?
    let supplierName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case workLocationId = "work_location_id"
        case entryDate = "entry_date"
        case kind
        case documentNumber = "document_number"
        case explanation
        case amount
        case isIncasare = "is_incasare"
        case supplierId = "supplier_id"
        case supplierName = "supplier_name"
    }

    init(entry: CashRegisterManualEntry, companyId: UUID) {
        id = entry.id
        self.companyId = companyId
        workLocationId = entry.resolvedCasaTarget().workLocationId()
        entryDate = SupabaseDecoding.dateOnlyString(from: entry.date)
        kind = entry.kind.databaseValue
        documentNumber = entry.documentNumber
        explanation = entry.explanation
        amount = NSDecimalNumber(decimal: entry.amount).stringValue
        isIncasare = entry.kind.isIncasare
        supplierId = entry.supplierId
        supplierName = entry.supplierName
    }
}

extension CashRegisterManualEntryKind {
    var databaseValue: String {
        switch self {
        case .incasareClient: return "incasare_client"
        case .plataFurnizor: return "plata_furnizor"
        case .ridicareNumerarBanca: return "ridicare_numerar_banca"
        case .depunereBanca: return "depunere_banca"
        case .incasareDiverse: return "incasare_diverse"
        case .plataDiverse: return "plata_diverse"
        }
    }

    static func fromDatabase(_ raw: String, isIncasare: Bool = true) -> CashRegisterManualEntryKind {
        switch raw {
        case "plata_furnizor", "plataFurnizor": return .plataFurnizor
        case "ridicare_numerar_banca", "ridicareNumerarBanca": return .ridicareNumerarBanca
        case "depunere_banca", "depunereBanca": return .depunereBanca
        case "incasare_diverse", "incasareDiverse": return .incasareDiverse
        case "plata_diverse", "plataDiverse": return .plataDiverse
        case "incasare_client", "incasareClient": return .incasareClient
        default: return isIncasare ? .incasareDiverse : .plataDiverse
        }
    }
}
