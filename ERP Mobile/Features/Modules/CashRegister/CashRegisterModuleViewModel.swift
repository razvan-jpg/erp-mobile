import Combine
import Foundation

enum CashRegisterManualListFilter: String, CaseIterable, Identifiable {
    case currentWeek
    case currentMonth
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentWeek: return L10n.tr("module.cash_register.filter_week")
        case .currentMonth: return L10n.tr("module.cash_register.filter_month")
        case .all: return L10n.tr("module.cash_register.filter_all")
        }
    }
}

@MainActor
final class CashRegisterModuleViewModel: ObservableObject {
    @Published var fromDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @Published var toDate = Date()
    @Published var openingBalanceText = ""
    @Published var dailyPages: [CashRegisterDailyJournal] = []
    @Published var manualEntries: [CashRegisterManualEntry] = []
    @Published var cashPayments: [SupplierPaymentRow] = []
    @Published var clientCashPayments: [ClientPaymentRow] = []
    @Published var workLocations: [CompanyWorkLocation] = []
    @Published var zettaSettings = ZettaSettingsPayload.defaults()
    @Published var isLoading = false
    @Published var isSavingEntry = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var selectedCasa: CashRegisterCasaTarget = .headquarters
    /// `false` = luna curentă (luna lui `toDate`); `true` = toate paginile generate în perioada selectată.
    @Published var registersListExpanded = false
    @Published var manualListFilter: CashRegisterManualListFilter = .currentMonth
    @Published var manualListSearch = ""
    @Published var suppliers: [Supplier] = []

    private var company: Company?
    private var templateData: Data?

    var availableCasas: [CashRegisterCasaTarget] {
        let active = workLocations.filter(\.isActive)
        if !zettaSettings.usesRegistersOnMultipleWorkLocations || active.count <= 1 {
            return [.headquarters]
        }
        return [.headquarters] + active.map { .workLocation($0.id) }
    }

    func casaTitle(_ target: CashRegisterCasaTarget) -> String {
        CashRegisterWorkLocationMatcher.displayName(for: target, locations: workLocations)
    }

    func load(company: Company?) async {
        self.company = company
        guard let company else {
            dailyPages = []
            manualEntries = []
            cashPayments = []
            clientCashPayments = []
            workLocations = []
            suppliers = []
            templateData = nil
            openingBalanceText = ""
            return
        }
        openingBalanceText = CashRegisterOpeningBalanceStore.loadText(companyId: company.id)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let settingsTask = ZettaSettingsService.fetchSettings(companyId: company.id)
            async let locationsTask = WorkLocationService.fetchWorkLocations(companyId: company.id)
            async let templateTask = UtilityTemplateService.templateData(.registruCasaModel)
            let settings = try await settingsTask
            let locations = try await locationsTask
            templateData = try await templateTask
            zettaSettings = settings.payload
            workLocations = locations
            await CashRegisterEntryService.migrateLocalEntriesIfNeeded(companyId: company.id)
            async let entriesTask = CashRegisterEntryService.fetchEntries(companyId: company.id)
            async let paymentsTask = SupplierService.fetchCashPayments()
            async let clientPaymentsTask = ClientService.fetchCashPayments()
            async let suppliersTask = SupplierService.fetchSuppliers(activeOnly: true)
            manualEntries = try await entriesTask
            cashPayments = try await paymentsTask
            clientCashPayments = try await clientPaymentsTask
            suppliers = (try? await suppliersTask) ?? []
            if let warning = CashRegisterEntryService.lastSyncWarning, !warning.isEmpty {
                statusMessage = L10n.tr("module.cash_register.sync_warning", warning)
            } else if CashRegisterEntryService.usesLocalFallback {
                statusMessage = L10n.tr("module.cash_register.local_fallback_hint")
            }
            if !availableCasas.contains(selectedCasa) {
                selectedCasa = .headquarters
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateRegisters() async {
        guard let company else { return }
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }

        do {
            async let reportsTask = ClientZReportService.fetchReports(companyId: company.id)
            async let entriesTask = CashRegisterEntryService.fetchEntries(companyId: company.id)
            async let supplierCashTask = SupplierService.fetchCashPayments()
            async let clientCashTask = ClientService.fetchCashPayments()
            let reports = try await reportsTask
            let fetchedEntries = try await entriesTask
            let allCashPayments = try await supplierCashTask
            let allClientCash = try await clientCashTask
            manualEntries = mergeManualEntries(fetched: fetchedEntries, existing: manualEntries)
            cashPayments = allCashPayments
            clientCashPayments = allClientCash
            let calendar = Calendar(identifier: .gregorian)
            let end = calendar.startOfDay(for: toDate)
            let supplierCashPayments = allCashPayments.filter {
                calendar.startOfDay(for: $0.dataPlata) <= end
            }
            let clientCashInPeriod = allClientCash.filter {
                calendar.startOfDay(for: $0.dataPlata) <= end
            }
            let context = CashRegisterJournalBuilder.Context(
                company: company,
                settings: zettaSettings,
                workLocations: workLocations,
                zReports: reports,
                manualEntries: manualEntries,
                supplierCashPayments: supplierCashPayments,
                clientCashPayments: clientCashInPeriod,
                explicitOpeningBalances: explicitOpeningBalances(companyId: company.id)
            )
            dailyPages = CashRegisterJournalBuilder.build(
                context: context,
                from: fromDate,
                to: toDate
            )
            CashRegisterOpeningBalanceStore.saveText(openingBalanceText, companyId: company.id)
            persistLastClosings(companyId: company.id, pages: dailyPages)
            registersListExpanded = true
            // Chitanțele rămân în listă; generarea doar reconstruiește paginile PDF.
            if dailyPages.isEmpty {
                statusMessage = L10n.tr("module.cash_register.no_pages")
            } else {
                statusMessage = L10n.tr("module.cash_register.pages_count", dailyPages.count)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pages(for casa: CashRegisterCasaTarget) -> [CashRegisterDailyJournal] {
        dailyPages
            .filter { $0.casaTarget == casa }
            .sorted { $0.date < $1.date }
    }

    func visiblePages(for casa: CashRegisterCasaTarget) -> [CashRegisterDailyJournal] {
        let all = pages(for: casa)
        guard !registersListExpanded else { return all }
        return filterToCurrentMonth(all)
    }

    var registersListToggleVisible: Bool {
        guard !dailyPages.isEmpty else { return false }
        if registersListExpanded { return true }
        return availableCasas.contains { hiddenPagesCount(for: $0) > 0 }
    }

    func hiddenPagesCount(for casa: CashRegisterCasaTarget) -> Int {
        max(0, pages(for: casa).count - visiblePages(for: casa).count)
    }

    private func filterToCurrentMonth(_ pages: [CashRegisterDailyJournal]) -> [CashRegisterDailyJournal] {
        guard !pages.isEmpty else { return [] }
        let calendar = Calendar(identifier: .gregorian)
        let reference = calendar.startOfDay(for: toDate)
        return pages.filter {
            calendar.isDate($0.date, equalTo: reference, toGranularity: .month)
        }
    }

    func exportPDF(for casa: CashRegisterCasaTarget) async -> Data? {
        let pages = pages(for: casa)
        guard !pages.isEmpty else { return nil }
        return await makePDF(pages: pages)
    }

    func exportAllPDF() async -> Data? {
        guard !dailyPages.isEmpty else { return nil }
        return await makePDF(pages: dailyPages)
    }

    func exportPDF(page: CashRegisterDailyJournal) async -> Data? {
        await makePDF(pages: [page])
    }

    func clearGeneratedRegisters() {
        dailyPages = []
        statusMessage = L10n.tr("module.cash_register.registers_cleared")
    }

    var filteredManualEntries: [CashRegisterManualEntry] {
        manualEntries.filter { matchesManualFilter($0.date) && matchesManualSearch(entry: $0) }
    }

    var filteredCashPayments: [SupplierPaymentRow] {
        cashPayments.filter { matchesManualFilter($0.dataPlata) && matchesManualSearch(text: cashPaymentSearchText($0)) }
    }

    var filteredClientCashPayments: [ClientPaymentRow] {
        clientCashPayments.filter { matchesManualFilter($0.dataPlata) && matchesManualSearch(text: clientCashPaymentSearchText($0)) }
    }

    var hasAnyManualDocuments: Bool {
        !manualEntries.isEmpty || !cashPayments.isEmpty || !clientCashPayments.isEmpty
    }

    var hasVisibleManualDocuments: Bool {
        !filteredManualEntries.isEmpty || !filteredCashPayments.isEmpty || !filteredClientCashPayments.isEmpty
    }

    func addManualEntry(
        date: Date,
        casa: CashRegisterCasaTarget,
        kind: CashRegisterManualEntryKind,
        documentNumber: String,
        explanation: String,
        amount: Decimal,
        supplierId: UUID? = nil,
        supplierName: String? = nil
    ) async -> Bool {
        guard let company else { return false }
        isSavingEntry = true
        errorMessage = nil
        defer { isSavingEntry = false }

        do {
            let entry = CashRegisterManualEntry(
                date: date,
                casaTarget: casa,
                kind: kind,
                documentNumber: documentNumber,
                explanation: explanation,
                amount: amount,
                supplierId: supplierId,
                supplierName: supplierName
            )
            let saved = try await CashRegisterEntryService.insert(entry, companyId: company.id)
            if let warning = CashRegisterEntryService.lastSyncWarning, !warning.isEmpty {
                statusMessage = L10n.tr("module.cash_register.sync_warning", warning)
            }
            manualEntries.removeAll { $0.id == saved.id }
            manualEntries.append(saved)
            manualEntries.sort { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.documentNumber.localizedCaseInsensitiveCompare(rhs.documentNumber) == .orderedAscending
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteManualEntry(_ entry: CashRegisterManualEntry) async {
        guard let company else { return }
        do {
            try await CashRegisterEntryService.delete(id: entry.id, companyId: company.id)
            manualEntries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func kindLabel(_ kind: CashRegisterManualEntryKind) -> String {
        switch kind {
        case .incasareClient: return L10n.tr("module.cash_register.kind_incasare_client")
        case .plataFurnizor: return L10n.tr("module.cash_register.kind_plata_furnizor")
        case .ridicareNumerarBanca: return L10n.tr("module.cash_register.kind_ridicare_banca")
        case .depunereBanca: return L10n.tr("module.cash_register.kind_depunere_banca")
        case .incasareDiverse: return L10n.tr("module.cash_register.kind_incasare_diverse")
        case .plataDiverse: return L10n.tr("module.cash_register.kind_plata_diverse")
        }
    }

    func cashPaymentDocumentNumber(_ payment: SupplierPaymentRow) -> String {
        if let referinta = payment.referinta?.trimmingCharacters(in: .whitespacesAndNewlines), !referinta.isEmpty {
            return referinta
        }
        return "PL-\(CashRegisterJournalFormatting.fileDate(payment.dataPlata))"
    }

    func cashPaymentExplanation(_ payment: SupplierPaymentRow) -> String {
        if let trimmed = payment.observatii?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        let supplier = payment.supplierName
        if let invoice = payment.invoiceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !invoice.isEmpty {
            return L10n.tr("module.cash_register.line_plata_furnizor", invoice, supplier)
        }
        return L10n.tr("module.cash_register.line_plata_furnizor_advance", supplier)
    }

    func clientCashPaymentDocumentNumber(_ payment: ClientPaymentRow) -> String {
        if let referinta = payment.referinta?.trimmingCharacters(in: .whitespacesAndNewlines), !referinta.isEmpty {
            return referinta
        }
        return "IC-\(CashRegisterJournalFormatting.fileDate(payment.dataPlata))"
    }

    func clientCashPaymentExplanation(_ payment: ClientPaymentRow) -> String {
        if let trimmed = payment.observatii?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            return trimmed
        }
        let client = payment.clientName
        if let invoice = payment.invoiceNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !invoice.isEmpty {
            return L10n.tr("module.cash_register.line_incasare_client", invoice, client)
        }
        return L10n.tr("module.cash_register.line_incasare_client_advance", client)
    }

    private func mergeManualEntries(
        fetched: [CashRegisterManualEntry],
        existing: [CashRegisterManualEntry]
    ) -> [CashRegisterManualEntry] {
        var byId: [UUID: CashRegisterManualEntry] = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        for entry in existing where byId[entry.id] == nil {
            byId[entry.id] = entry
        }
        return byId.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.documentNumber.localizedCaseInsensitiveCompare(rhs.documentNumber) == .orderedAscending
        }
    }

    private func makePDF(pages: [CashRegisterDailyJournal]) async -> Data? {
        if templateData == nil {
            templateData = try? await UtilityTemplateService.templateData(.registruCasaModel)
        }
        guard let templateData else { return nil }
        return CashRegisterJournalPDFBuilder.makePDF(pages: pages, templateData: templateData)
    }

    private func explicitOpeningBalances(companyId: UUID) -> [String: Decimal] {
        let calendar = Calendar(identifier: .gregorian)
        let periodStart = calendar.startOfDay(for: fromDate)
        var balances: [String: Decimal] = [:]
        if let typed = parsedOpeningBalance {
            balances[CashRegisterCasaTarget.headquarters.id] = typed
        }
        for casa in availableCasas {
            if balances[casa.id] != nil { continue }
            guard let stored = CashRegisterOpeningBalanceStore.loadLastClosing(
                companyId: companyId,
                casa: casa
            ) else { continue }
            guard calendar.startOfDay(for: stored.date) < periodStart else { continue }
            balances[casa.id] = stored.amount
        }
        return balances
    }

    private var parsedOpeningBalance: Decimal? {
        let trimmed = openingBalanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private func matchesManualFilter(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        switch manualListFilter {
        case .all:
            return true
        case .currentMonth:
            return calendar.isDate(day, equalTo: today, toGranularity: .month)
        case .currentWeek:
            let weekStart = startOfWeek(containing: today, calendar: calendar)
            guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return false }
            return day >= weekStart && day <= weekEnd
        }
    }

    private func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        var calendar = calendar
        calendar.firstWeekday = 2
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
    }

    private func matchesManualSearch(entry: CashRegisterManualEntry) -> Bool {
        matchesManualSearch(
            text: [
                entry.explanation,
                entry.documentNumber,
                kindLabel(entry.kind),
                entry.supplierName ?? ""
            ].joined(separator: " ")
        )
    }

    private func cashPaymentSearchText(_ payment: SupplierPaymentRow) -> String {
        [cashPaymentExplanation(payment), cashPaymentDocumentNumber(payment), payment.supplierName].joined(separator: " ")
    }

    private func clientCashPaymentSearchText(_ payment: ClientPaymentRow) -> String {
        [clientCashPaymentExplanation(payment), clientCashPaymentDocumentNumber(payment), payment.clientName].joined(separator: " ")
    }

    private func matchesManualSearch(text: String) -> Bool {
        let query = manualListSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return text.localizedStandardContains(query)
    }

    private func persistLastClosings(companyId: UUID, pages: [CashRegisterDailyJournal]) {
        let grouped = Dictionary(grouping: pages, by: \.casaTarget)
        for (casa, casaPages) in grouped {
            guard let last = casaPages.max(by: { $0.date < $1.date }) else { continue }
            CashRegisterOpeningBalanceStore.saveLastClosing(
                companyId: companyId,
                casa: casa,
                amount: last.closingBalance,
                date: last.date
            )
        }
    }
}

enum CashRegisterOpeningBalanceStore {
    private struct StoredClosing: Codable {
        var amount: String
        var date: String
    }

    static func loadText(companyId: UUID) -> String {
        UserDefaults.standard.string(forKey: textKey(companyId)) ?? ""
    }

    static func saveText(_ text: String, companyId: UUID) {
        UserDefaults.standard.set(text, forKey: textKey(companyId))
    }

    static func loadLastClosing(
        companyId: UUID,
        casa: CashRegisterCasaTarget
    ) -> (amount: Decimal, date: Date)? {
        guard let data = UserDefaults.standard.data(forKey: closingKey(companyId: companyId, casa: casa)),
              let stored = try? JSONDecoder().decode(StoredClosing.self, from: data),
              let amount = Decimal(string: stored.amount),
              let date = SupabaseDecoding.parseDate(stored.date)
        else { return nil }
        return (amount, date)
    }

    static func saveLastClosing(
        companyId: UUID,
        casa: CashRegisterCasaTarget,
        amount: Decimal,
        date: Date
    ) {
        let stored = StoredClosing(
            amount: NSDecimalNumber(decimal: amount).stringValue,
            date: SupabaseDecoding.dateOnlyString(from: date)
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: closingKey(companyId: companyId, casa: casa))
    }

    private static func textKey(_ companyId: UUID) -> String {
        "cash_register.opening_balance.\(companyId.uuidString)"
    }

    private static func closingKey(companyId: UUID, casa: CashRegisterCasaTarget) -> String {
        "cash_register.last_closing.\(companyId.uuidString).\(casa.id)"
    }
}
