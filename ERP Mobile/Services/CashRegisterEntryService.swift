import Foundation
import Supabase

enum CashRegisterEntryService {
    private static let client = SupabaseManager.client

    static var usesLocalFallback: Bool {
        get { UserDefaults.standard.bool(forKey: "cash_register_entries_local_fallback") }
        set { UserDefaults.standard.set(newValue, forKey: "cash_register_entries_local_fallback") }
    }

    static func fetchEntries(companyId: UUID) async throws -> [CashRegisterManualEntry] {
        do {
            let rows: [CompanyCashRegisterEntryRecord] = try await client
                .from("company_cash_register_entries")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .order("entry_date", ascending: true)
                .order("document_number", ascending: true)
                .execute()
                .value
            usesLocalFallback = false
            return rows.map(\.asManualEntry)
        } catch {
            if isMissingRemoteTableError(error) {
                usesLocalFallback = true
                return CashRegisterManualEntryStore.load(companyId: companyId)
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
        do {
            let payload = CompanyCashRegisterEntryUpsert(entry: entry, companyId: companyId)
            let rows: [CompanyCashRegisterEntryRecord] = try await client
                .from("company_cash_register_entries")
                .insert(payload)
                .select()
                .execute()
                .value
            guard let saved = rows.first else { throw ServiceError.invalidResponse }
            usesLocalFallback = false
            return saved.asManualEntry
        } catch {
            if isMissingRemoteTableError(error) {
                usesLocalFallback = true
                CashRegisterManualEntryStore.append(entry, companyId: companyId)
                return entry
            }
            throw error
        }
    }

    static func delete(id: UUID, companyId: UUID) async throws {
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
                CashRegisterManualEntryStore.delete(id: id, companyId: companyId)
                return
            }
            throw error
        }
    }

    /// Migrează o singură dată intrările locale (UserDefaults) în Supabase.
    static func migrateLocalEntriesIfNeeded(companyId: UUID) async {
        let local = CashRegisterManualEntryStore.loadLocalOnly(companyId: companyId)
        guard !local.isEmpty else { return }
        for entry in local {
            do {
                _ = try await insert(entry, companyId: companyId)
            } catch {
                return
            }
        }
        if !usesLocalFallback {
            CashRegisterManualEntryStore.clearLocal(companyId: companyId)
        }
    }

    private static func isMissingRemoteTableError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("company_cash_register_entries") { return true }
        if message.contains("schema cache") { return true }
        if message.contains("pgrst205") { return true }
        if message.contains("does not exist") { return true }
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var asManualEntry: CashRegisterManualEntry {
        CashRegisterManualEntry(
            id: id,
            date: entryDate,
            casaTarget: workLocationId.map { CashRegisterCasaTarget.workLocation($0) } ?? .headquarters,
            kind: CashRegisterManualEntryKind.fromDatabase(kind),
            documentNumber: documentNumber,
            explanation: explanation,
            amount: amount
        )
    }
}

struct CompanyCashRegisterEntryUpsert: Encodable, Sendable {
    let companyId: UUID
    let workLocationId: UUID?
    let entryDate: String
    let kind: String
    let documentNumber: String
    let explanation: String
    let amount: String
    let isIncasare: Bool

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case workLocationId = "work_location_id"
        case entryDate = "entry_date"
        case kind
        case documentNumber = "document_number"
        case explanation
        case amount
        case isIncasare = "is_incasare"
    }

    init(entry: CashRegisterManualEntry, companyId: UUID) {
        self.companyId = companyId
        workLocationId = entry.resolvedCasaTarget().workLocationId()
        entryDate = SupabaseDecoding.dateOnlyString(from: entry.date)
        kind = entry.kind.databaseValue
        documentNumber = entry.documentNumber
        explanation = entry.explanation
        amount = NSDecimalNumber(decimal: entry.amount).stringValue
        isIncasare = entry.kind.isIncasare
    }
}

extension CashRegisterManualEntryKind {
    var databaseValue: String {
        switch self {
        case .incasareClient: return "incasare_client"
        case .plataFurnizor: return "plata_furnizor"
        case .ridicareNumerarBanca: return "ridicare_numerar_banca"
        case .incasareDiverse: return "incasare_diverse"
        case .plataDiverse: return "plata_diverse"
        }
    }

    static func fromDatabase(_ raw: String) -> CashRegisterManualEntryKind {
        switch raw {
        case "plata_furnizor": return .plataFurnizor
        case "ridicare_numerar_banca": return .ridicareNumerarBanca
        case "incasare_diverse": return .incasareDiverse
        case "plata_diverse": return .plataDiverse
        default: return .incasareClient
        }
    }
}
