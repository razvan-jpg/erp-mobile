import SwiftUI

private struct HRListingPreview: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct HRListingExcelExport: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct HRListingsView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var period = HRMonthPeriod.current()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var preview: HRListingPreview?
    @State private var pendingExcel: HRListingExcelExport?
    @State private var noteStyle: HRPayrollNCNoteStyle = .simple

    var body: some View {
        List {
            Section {
                HRPeriodPicker(period: $period)
            }
            Section(L10n.tr("module.hr.listings_pdf")) {
                listingButton(.payrollGeneral, image: "doc.richtext")
                listingButton(.payrollByLocation, image: "building.2")
                listingButton(.payslips, image: "person.text.rectangle")
                listingButton(.timesheet, image: "calendar")
                listingButton(.journal, image: "book")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("utilities.payroll_nc.style"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Picker(L10n.tr("utilities.payroll_nc.style"), selection: $noteStyle) {
                        ForEach(HRPayrollNCNoteStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(L10n.tr("module.hr.listings_nextup_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                }
                Button {
                    Task { await export(.journal, applyNoteStyle: true) }
                } label: {
                    Label(L10n.tr("utilities.payroll_nc.preview"), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!access.canView || isLoading)
                Button {
                    Task { await export(.nextUpExcel) }
                } label: {
                    Label(L10n.tr("module.hr.listing_nextUpExcel"), systemImage: "tablecells")
                }
                .disabled(!access.canView || isLoading)
            } header: {
                Text(L10n.tr("module.hr.listings_excel"))
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_listings"))
        .appSafeAreaInsetBottom {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .sheet(item: $preview) { item in
            PDFDocumentPreviewSheet(title: item.title, pdfData: item.data, onClose: { preview = nil })
        }
        #if os(iOS) || targetEnvironment(macCatalyst)
        .sheet(item: $pendingExcel) { item in
            #if targetEnvironment(macCatalyst)
            LocalSaveDocumentPicker(sourceURLs: item.urls) {
                pendingExcel = nil
            }
            .ignoresSafeArea()
            #else
            ActivityShareSheet(items: item.urls, excludedActivityTypes: nil) {
                pendingExcel = nil
            }
            #endif
        }
        #endif
    }

    private func listingButton(_ kind: HRListingsKind, image: String) -> some View {
        Button {
            Task { await export(kind) }
        } label: {
            Label(L10n.tr("module.hr.listing_\(kind.rawValue)"), systemImage: image)
        }
        .disabled(!access.canView || isLoading)
    }

    private func export(_ kind: HRListingsKind, applyNoteStyle: Bool = false) async {
        guard let company = companyManager.currentCompany else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let run = try await HRPersonnelService.fetchRun(companyId: company.id, period: period) else {
                errorMessage = L10n.tr("module.hr.listings_no_payroll")
                return
            }
            async let employees = HRPersonnelService.fetchEmployees(companyId: company.id)
            async let contracts = HRPersonnelService.fetchContracts(companyId: company.id)
            async let locations = WorkLocationService.fetchWorkLocations(companyId: company.id)
            async let settings = HRPersonnelService.fetchSettings(companyId: company.id)
            let lines = try await HRPersonnelService.fetchLines(runId: run.id)
            let drafts = HRPersonnelService.drafts(
                lines: lines,
                employees: try await employees,
                contracts: try await contracts,
                locations: try await locations
            )
            let journal = HRPayrollNCUniqueAccountCollector.exportEntries(
                HRPayrollJournalBuilder.build(run: run, drafts: drafts, settings: try await settings),
                style: (kind == .nextUpExcel || applyNoteStyle) ? noteStyle : .simple
            )
            switch kind {
            case .payrollGeneral:
                let data = try HRPayrollPDFBuilder.payrollGeneral(company: company, period: period, drafts: drafts)
                preview = HRListingPreview(title: L10n.tr("module.hr.listing_payrollGeneral"), data: data)
            case .payrollByLocation:
                let data = try HRPayrollPDFBuilder.payrollByLocation(company: company, period: period, drafts: drafts)
                preview = HRListingPreview(title: L10n.tr("module.hr.listing_payrollByLocation"), data: data)
            case .payslips:
                let data = try HRPayrollPDFBuilder.payslips(company: company, period: period, drafts: drafts)
                preview = HRListingPreview(title: L10n.tr("module.hr.listing_payslips"), data: data)
            case .timesheet:
                let days = try await HRPersonnelService.fetchTimesheet(runId: run.id)
                let data = try HRPayrollPDFBuilder.timesheet(company: company, period: period, drafts: drafts, days: days)
                preview = HRListingPreview(title: L10n.tr("module.hr.listing_timesheet"), data: data)
            case .journal:
                let data = try HRPayrollPDFBuilder.journal(company: company, period: period, entries: journal)
                preview = HRListingPreview(title: L10n.tr("module.hr.listing_journal"), data: data)
            case .nextUpExcel:
                let url = try HRPayrollNextUpExporter.writeTemporary(entries: journal, company: company, period: period)
                pendingExcel = HRListingExcelExport(urls: [url])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
