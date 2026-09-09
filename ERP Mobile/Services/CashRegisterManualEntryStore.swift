import Foundation

/// Stocare locală (UserDefaults) — fallback când migrarea Supabase nu e încă aplicată.
enum CashRegisterManualEntryStore {
    private static func key(companyId: UUID) -> String {
        "cash_register_manual_entries_\(companyId.uuidString)"
    }

    static func load(companyId: UUID) -> [CashRegisterManualEntry] {
        loadLocalOnly(companyId: companyId)
    }

    static func loadLocalOnly(companyId: UUID) -> [CashRegisterManualEntry] {
        guard let data = UserDefaults.standard.data(forKey: key(companyId: companyId)) else { return [] }
        return (try? SupabaseDecoding.jsonDecoder.decode([CashRegisterManualEntry].self, from: data)) ?? []
    }

    static func save(_ entries: [CashRegisterManualEntry], companyId: UUID) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key(companyId: companyId))
    }

    static func append(_ entry: CashRegisterManualEntry, companyId: UUID) {
        upsert(entry, companyId: companyId)
    }

    static func upsert(_ entry: CashRegisterManualEntry, companyId: UUID) {
        var entries = load(companyId: companyId)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        entries.sort { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.documentNumber.localizedCaseInsensitiveCompare(rhs.documentNumber) == .orderedAscending
        }
        save(entries, companyId: companyId)
    }

    static func delete(id: UUID, companyId: UUID) {
        var entries = load(companyId: companyId)
        entries.removeAll { $0.id == id }
        save(entries, companyId: companyId)
    }

    static func clearLocal(companyId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(companyId: companyId))
    }
}
