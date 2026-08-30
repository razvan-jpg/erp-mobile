import Combine
import Foundation

@MainActor
final class CashRegisterModuleViewModel: ObservableObject {
    @Published var fromDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @Published var toDate = Date()
    @Published var dailyPages: [CashRegisterDailyJournal] = []
    @Published var manualEntries: [CashRegisterManualEntry] = []
    @Published var workLocations: [CompanyWorkLocation] = []
    @Published var zettaSettings = ZettaSettingsPayload.defaults()
    @Published var isLoading = false
    @Published var isSavingEntry = false
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var selectedCasa: CashRegisterCasaTarget = .headquarters
    /// `false` = luna curentă (luna lui `toDate`); `true` = toate paginile generate în perioada selectată.
    @Published var registersListExpanded = false

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
            workLocations = []
            templateData = nil
            return
        }

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
            manualEntries = try await CashRegisterEntryService.fetchEntries(companyId: company.id)
            if CashRegisterEntryService.usesLocalFallback {
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
            async let supplierCashTask = SupplierService.fetchCashPayments(upTo: toDate)
            let reports = try await reportsTask
            let entries = try await entriesTask
            let supplierCashPayments = try await supplierCashTask
            manualEntries = entries.filter { entry in
                let calendar = Calendar(identifier: .gregorian)
                let start = calendar.startOfDay(for: fromDate)
                let end = calendar.startOfDay(for: toDate)
                let day = calendar.startOfDay(for: entry.date)
                return day >= start && day <= end
            }
            let context = CashRegisterJournalBuilder.Context(
                company: company,
                settings: zettaSettings,
                workLocations: workLocations,
                zReports: reports,
                manualEntries: entries,
                supplierCashPayments: supplierCashPayments
            )
            dailyPages = CashRegisterJournalBuilder.build(
                context: context,
                from: fromDate,
                to: toDate
            )
            registersListExpanded = !availableCasas.contains {
                filterToCurrentMonth(pages(for: $0)).count < pages(for: $0).count
            }
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

    func addManualEntry(
        date: Date,
        casa: CashRegisterCasaTarget,
        kind: CashRegisterManualEntryKind,
        documentNumber: String,
        explanation: String,
        amount: Decimal
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
                amount: amount
            )
            let saved = try await CashRegisterEntryService.insert(entry, companyId: company.id)
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
        case .incasareDiverse: return L10n.tr("module.cash_register.kind_incasare_diverse")
        case .plataDiverse: return L10n.tr("module.cash_register.kind_plata_diverse")
        }
    }

    private func makePDF(pages: [CashRegisterDailyJournal]) async -> Data? {
        if templateData == nil {
            templateData = try? await UtilityTemplateService.templateData(.registruCasaModel)
        }
        guard let templateData else { return nil }
        return CashRegisterJournalPDFBuilder.makePDF(pages: pages, templateData: templateData)
    }
}
