import SwiftUI

private enum SalesCashHubSection: CaseIterable, Identifiable {
    case zReports
    case clientInvoices

    var id: Self { self }

    var label: String {
        switch self {
        case .zReports: return L10n.tr("module.sales.cash_sale.hub_z")
        case .clientInvoices: return L10n.tr("module.sales.cash_sale.hub_invoices")
        }
    }
}

/// Vânzări → Vânzare casă marcat — UX tip BINA: Rapoarte Z + Facturi clienți.
struct SalesCashRegisterSaleView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var hubSection: SalesCashHubSection = .zReports
    @State private var locations: [CompanyWorkLocation] = []
    @State private var buckets: [FiscalSaleLocationBucket] = []
    @State private var zReportsById: [UUID: CompanyZReportRecord] = [:]
    @State private var selectedLocationId: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var periodFilter: SalesFiscalPeriodFilter = .thisMonth
    @State private var customDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var customDateTo = Calendar.current.startOfDay(for: Date())

    @State private var detailShift: FiscalSaleShiftBucket?
    @State private var pdfPreview: SalesPDFPreviewItem?
    @State private var receiptsNav: SalesReceiptsNavItem?
    @State private var clientAccess = ModuleAccessRights.none

    private var selectedBucket: FiscalSaleLocationBucket? {
        guard let selectedLocationId else { return buckets.first }
        return buckets.first(where: { $0.id == selectedLocationId }) ?? buckets.first
    }

    private var openShift: FiscalSaleShiftBucket? {
        selectedBucket?.days.flatMap(\.shifts).first(where: \.isOpen)
    }

    private var closedShifts: [FiscalSaleShiftBucket] {
        guard let selectedBucket else { return [] }
        return selectedBucket.days
            .filter {
                periodFilter.includes(date: $0.saleDate, customFrom: customDateFrom, customTo: customDateTo)
            }
            .flatMap(\.shifts)
            .filter { !$0.isOpen }
            .sorted { ($0.endsAt ?? $0.saleDate) > ($1.endsAt ?? $1.saleDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.sales.cash_sale.hub_picker"), selection: $hubSection) {
                ForEach(SalesCashHubSection.allCases) { section in
                    Text(section.label).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 8)

            switch hubSection {
            case .zReports:
                zHub
            case .clientInvoices:
                SalesClientInvoicesGridView(access: clientAccess)
            }
        }
        .appTask {
            await reload()
            await loadClientAccess()
        }
        .onChange(of: companyManager.currentCompany?.id) { _, _ in
            Task {
                await reload()
                await loadClientAccess()
            }
        }
        .refreshable { await reload() }
        .sheet(item: $detailShift) { shift in
            SalesZReportDetailSheet(
                shift: shift,
                locationName: locationName(for: shift),
                onPDF: { presentZPDF(for: shift) },
                onViewReceipts: {
                    detailShift = nil
                    receiptsNav = SalesReceiptsNavItem(shift: shift, locationName: locationName(for: shift))
                }
            )
        }
        .sheet(item: $pdfPreview) { item in
            PDFDocumentPreviewSheet(title: item.title, pdfData: item.data) {
                pdfPreview = nil
            }
        }
        .sheet(item: $receiptsNav) { item in
            NavigationView {
                SalesFiscalReceiptsListView(
                    shift: item.shift,
                    locationName: item.locationName,
                    locations: locations,
                    clientAccess: clientAccess
                )
            }
        }
    }

    @ViewBuilder
    private var zHub: some View {
        VStack(spacing: 0) {
            if !buckets.isEmpty {
                locationPicker
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                filterBar
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Group {
                if isLoading {
                    ProgressView(L10n.tr("module.sales.cash_sale.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if locations.isEmpty {
                    AppEmptyStateView(
                        L10n.tr("module.sales.cash_sale.no_locations_title"),
                        systemImage: "mappin.and.ellipse",
                        description: Text(L10n.tr("module.sales.cash_sale.no_locations_body"))
                    )
                } else if let errorMessage {
                    AppEmptyStateView(
                        L10n.tr("module.sales.cash_sale.error_title"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if closedShifts.isEmpty && openShift == nil {
                    AppEmptyStateView(
                        L10n.tr("module.sales.cash_sale.empty_period_title"),
                        systemImage: "receipt",
                        description: Text(L10n.tr("module.sales.cash_sale.empty_period_body"))
                    )
                } else {
                    zList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var zList: some View {
        List {
            if let openShift {
                Section(header: Text(L10n.tr("module.sales.cash_sale.mode_x"))) {
                    SalesZReportRowView(
                        shift: openShift,
                        locationName: locationName(for: openShift),
                        visual: nil,
                        onDetails: { detailShift = openShift },
                        onPDF: nil,
                        onReceipts: {
                            receiptsNav = SalesReceiptsNavItem(
                                shift: openShift,
                                locationName: locationName(for: openShift)
                            )
                        }
                    )
                }
            }

            Section(header: Text(L10n.tr("module.sales.cash_sale.z_list_section"))) {
                ForEach(closedShifts) { shift in
                    SalesZReportRowView(
                        shift: shift,
                        locationName: locationName(for: shift),
                        visual: shift.zReport.map { ZettaModelZReportFormatter.visualModel(for: $0.reportData) },
                        onDetails: { detailShift = shift },
                        onPDF: { presentZPDF(for: shift) },
                        onReceipts: {
                            receiptsNav = SalesReceiptsNavItem(
                                shift: shift,
                                locationName: locationName(for: shift)
                            )
                        }
                    )
                }
            }
        }
        .listStyle(.plain)
        .appScrollBottomPadding()
    }

    @ViewBuilder
    private var locationPicker: some View {
        if buckets.count <= 3 {
            Picker(L10n.tr("module.sales.cash_sale.location_picker"), selection: locationSelection) {
                ForEach(buckets) { bucket in
                    Text(bucket.location.denumire).tag(Optional(bucket.id))
                }
            }
            .pickerStyle(.segmented)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(buckets) { bucket in
                        let selected = selectedLocationId == bucket.id
                        Button {
                            selectedLocationId = bucket.id
                        } label: {
                            Text(bucket.location.denumire)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? AppColors.accent.opacity(0.18) : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var locationSelection: Binding<UUID?> {
        Binding(
            get: { selectedLocationId ?? buckets.first?.id },
            set: { selectedLocationId = $0 }
        )
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.tr("module.sales.cash_sale.period"), selection: $periodFilter) {
                ForEach(SalesFiscalPeriodFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.menu)

            if periodFilter == .customRange {
                HStack {
                    DatePicker(
                        L10n.tr("module.sales.cash_sale.period_from"),
                        selection: $customDateFrom,
                        displayedComponents: .date
                    )
                    DatePicker(
                        L10n.tr("module.sales.cash_sale.period_to"),
                        selection: $customDateTo,
                        displayedComponents: .date
                    )
                }
                .font(.caption)
            }
        }
    }

    private func locationName(for shift: FiscalSaleShiftBucket) -> String {
        if let locId = shift.workLocationId,
           let loc = locations.first(where: { $0.id == locId }) {
            return loc.denumire
        }
        return shift.zReport?.reportData.locatieLabel
            ?? selectedBucket?.location.denumire
            ?? "—"
    }

    private func presentZPDF(for shift: FiscalSaleShiftBucket) {
        guard let report = shift.zReport else { return }
        let data = ZettaModelZReportFormatter.makePDF(for: report.reportData)
        pdfPreview = SalesPDFPreviewItem(
            title: L10n.tr("module.sales.cash_sale.z_pdf_title", report.zNumber),
            data: data
        )
    }

    @MainActor
    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else {
            locations = []
            buckets = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let locs = WorkLocationService.fetchWorkLocations(companyId: companyId)
            async let reports = ClientZReportService.fetchReports(companyId: companyId)
            async let receipts = FiscalSaleReceiptService.fetchReceipts(companyId: companyId)
            let loadedLocations = try await locs
            let loadedReports = try await reports
            let loadedReceipts = (try? await receipts) ?? []
            locations = loadedLocations.filter(\.isActive)
            zReportsById = Dictionary(uniqueKeysWithValues: loadedReports.map { ($0.id, $0) })
            buckets = FiscalSaleReceiptService.buildLocationBuckets(
                locations: loadedLocations,
                zReports: loadedReports,
                receipts: loadedReceipts
            )
            if selectedLocationId == nil || !buckets.contains(where: { $0.id == selectedLocationId }) {
                selectedLocationId = buckets.first?.id
            }
        } catch {
            if OfflineNetwork.isTransient(error) || !NetworkMonitor.isOnlineSnapshot {
                let cachedLocations = MasterDataCache.workLocations(companyId: companyId)
                locations = cachedLocations.filter(\.isActive)
                buckets = FiscalSaleReceiptService.buildLocationBuckets(
                    locations: cachedLocations,
                    zReports: [],
                    receipts: []
                )
                if buckets.isEmpty {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadClientAccess() async {
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            clientAccess = .none
            return
        }
        do {
            let modules = try await ModuleService.fetchActiveModules()
            guard let clientsModule = modules.first(where: { $0.code == ModuleCode.clientInvoicesPayments }) else {
                clientAccess = .none
                return
            }
            let moduleAccess = try await ModuleAccessRights.load(moduleId: clientsModule.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            clientAccess = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            clientAccess = .none
        }
    }
}

// MARK: - Navigation / preview items

private struct SalesPDFPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct SalesReceiptsNavItem: Identifiable, Hashable {
    let id: UUID
    let shift: FiscalSaleShiftBucket
    let locationName: String

    init(shift: FiscalSaleShiftBucket, locationName: String) {
        self.id = shift.id
        self.shift = shift
        self.locationName = locationName
    }
}

// MARK: - Z row

private struct SalesZReportRowView: View {
    let shift: FiscalSaleShiftBucket
    let locationName: String
    let visual: BinaZReportVisualModel?
    let onDetails: () -> Void
    let onPDF: (() -> Void)?
    let onReceipts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(L10n.tr("module.sales.cash_sale.action_details"), action: onDetails)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                if let onPDF {
                    Button("PDF", action: onPDF)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button(L10n.tr("module.sales.cash_sale.action_receipts"), action: onReceipts)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(numberLabel)
                    .font(.headline)
                Spacer()
                Text(SupplierFormatting.currency(shift.totalAmount))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }

            HStack(spacing: 12) {
                Text(dateLabel)
                Text(locationName)
                if let pos = visual?.posNumber, !pos.isEmpty {
                    Text(L10n.tr("module.sales.cash_sale.pos_short", pos))
                }
                Text(L10n.tr("module.sales.cash_sale.documents_count", shift.receiptCount))
            }
            .font(.caption)
            .foregroundColor(AppColors.secondary)
        }
        .padding(.vertical, 4)
    }

    private var numberLabel: String {
        if shift.isOpen {
            return L10n.tr("module.sales.cash_sale.shift_open_since_last_z")
        }
        if let z = shift.zNumber {
            return L10n.tr("module.sales.cash_sale.z_number", z)
        }
        return L10n.tr("module.sales.cash_sale.z_list_section")
    }

    private var dateLabel: String {
        if let to = visual?.toDate, !to.isEmpty { return to }
        if let ends = shift.endsAt {
            return SupplierFormatting.dateTime(ends)
        }
        return SupplierFormatting.date(shift.saleDate)
    }
}

// MARK: - Period filter

enum SalesFiscalPeriodFilter: CaseIterable, Identifiable {
    case thisMonth
    case last7Days
    case last3Days
    case customRange
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .thisMonth: return L10n.tr("module.sales.cash_sale.period_this_month")
        case .last7Days: return L10n.tr("module.sales.cash_sale.period_last_7_days")
        case .last3Days: return L10n.tr("module.sales.cash_sale.period_last_3_days")
        case .customRange: return L10n.tr("module.sales.cash_sale.period_custom")
        case .all: return L10n.tr("module.sales.cash_sale.period_all")
        }
    }

    func includes(date: Date, customFrom: Date, customTo: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        switch self {
        case .thisMonth:
            return calendar.isDate(day, equalTo: today, toGranularity: .month)
        case .last7Days:
            guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return false }
            return day >= start && day <= today
        case .last3Days:
            guard let start = calendar.date(byAdding: .day, value: -2, to: today) else { return false }
            return day >= start && day <= today
        case .customRange:
            let from = calendar.startOfDay(for: min(customFrom, customTo))
            let to = calendar.startOfDay(for: max(customFrom, customTo))
            return day >= from && day <= to
        case .all:
            return true
        }
    }
}
