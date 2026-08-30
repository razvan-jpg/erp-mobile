import SwiftUI

private enum ZReportPeriodFilter: CaseIterable, Identifiable {
    case thisMonth
    case last7Days
    case last3Days
    case customRange
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .thisMonth: return L10n.tr("module.clients.z_reports.period_this_month")
        case .last7Days: return L10n.tr("module.clients.z_reports.period_last_7_days")
        case .last3Days: return L10n.tr("module.clients.z_reports.period_last_3_days")
        case .customRange: return L10n.tr("module.clients.z_reports.period_custom")
        case .all: return L10n.tr("module.clients.z_reports.period_all")
        }
    }

    func includes(reportDate: Date, customFrom: Date, customTo: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: reportDate)
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

struct ClientZReportsListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @StateObject private var exportModel = ZettaAppViewModel()

    @State private var records: [CompanyZReportRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var periodFilter: ZReportPeriodFilter = .thisMonth
    @State private var customDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var customDateTo = Calendar.current.startOfDay(for: Date())
    @State private var zettaNCConfig: ZettaNCConfig?

    @State private var recordToDelete: CompanyZReportRecord?
    @State private var showDeleteConfirm = false
    @State private var isSelectionMode = false
    @State private var selectedRecordIds = Set<UUID>()
    @State private var showBulkDeleteConfirm = false
    @State private var pdfPreview: ZReportPDFPreviewItem?

    private var filteredRecords: [CompanyZReportRecord] {
        records
            .filter { record in
                periodFilter.includes(
                    reportDate: record.accountingDate,
                    customFrom: customDateFrom,
                    customTo: customDateTo
                )
            }
            .sorted { lhs, rhs in
                let calendar = Calendar.current
                let leftDay = calendar.startOfDay(for: lhs.accountingDate)
                let rightDay = calendar.startOfDay(for: rhs.accountingDate)
                if leftDay != rightDay { return leftDay < rightDay }
                if lhs.zNumber != rhs.zNumber { return lhs.zNumber < rhs.zNumber }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private var filteredRecordIds: Set<UUID> {
        Set(filteredRecords.map(\.id))
    }

    private var allFilteredRecordsSelected: Bool {
        !filteredRecords.isEmpty && filteredRecordIds.isSubset(of: selectedRecordIds)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal)
                .padding(.bottom, 8)

            if periodFilter == .customRange {
                customRangePicker
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            Group {
                if isLoading {
                    ProgressView(L10n.tr("module.clients.z_reports.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredRecords.isEmpty {
                    AppEmptyStateView(
                        L10n.tr("module.clients.z_reports.empty_title"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(L10n.tr("module.clients.z_reports.empty_hint"))
                    )
                } else {
                    reportsTable
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !filteredRecords.isEmpty && !isSelectionMode {
                exportBar
            }
        }
        .appSafeAreaInsetBottom {
            if isSelectionMode && access.canDelete {
                BulkDeleteSelectionBottomBar(
                    selectedCount: selectedRecordIds.count,
                    onDelete: { showBulkDeleteConfirm = true }
                )
            }
        }
        .bulkDeleteSelectionToolbar(
            enabled: access.canDelete && !filteredRecords.isEmpty,
            isSelectionMode: isSelectionMode,
            allVisibleSelected: allFilteredRecordsSelected,
            hasVisibleItems: !filteredRecords.isEmpty,
            selectedCount: selectedRecordIds.count,
            onEnterSelection: enterSelectionMode,
            onExitSelection: exitSelectionMode,
            onToggleSelectAll: toggleSelectAllFilteredRecords,
            onDeleteSelected: { showBulkDeleteConfirm = true }
        )
        .appTask { await reload() }
        .onChange(of: filteredRecords.map(\.id)) { _ in
            pruneSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clientZReportsDidChange)) { _ in
            Task { await reload() }
        }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await reload() }
        }
        #if os(iOS)
        .sheet(item: $exportModel.pendingShare) { item in
            ZettaShareSheet(urls: item.urls) {
                exportModel.pendingShare = nil
            }
        }
        #if targetEnvironment(macCatalyst)
        .sheet(item: $exportModel.pendingLocalSave) { item in
            LocalSaveDocumentPicker(sourceURLs: item.urls) {
                exportModel.pendingLocalSave = nil
            }
            .ignoresSafeArea()
        }
        #endif
        #endif
        .alert(
            L10n.tr("module.clients.z_reports.delete_title"),
            isPresented: $showDeleteConfirm,
            presenting: recordToDelete
        ) { record in
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { await deleteRecord(record) }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {
                recordToDelete = nil
            }
        } message: { record in
            Text(deleteConfirmationMessage(for: record))
        }
        .alert(L10n.tr("module.clients.z_reports.bulk_delete_title"), isPresented: $showBulkDeleteConfirm) {
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { await deleteSelectedRecords() }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("module.clients.z_reports.bulk_delete_confirm", selectedRecordIds.count))
        }
        .sheet(item: $pdfPreview) { item in
            PDFDocumentPreviewSheet(title: item.title, pdfData: item.pdfData) {
                pdfPreview = nil
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ZReportPeriodFilter.allCases) { filter in
                    Button {
                        periodFilter = filter
                    } label: {
                        Text(filter.label)
                            .font(.subheadline.weight(periodFilter == filter ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(periodFilter == filter ? AppColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customRangePicker: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("module.clients.z_reports.from_date"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $customDateFrom)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("module.clients.z_reports.to_date"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                AppDatePicker(selection: $customDateTo)
            }
        }
        .font(.subheadline)
    }

    private var reportsTable: some View {
        GeometryReader { geometry in
            let tableWidth = max(geometry.size.width, 320)
            let hasCheckbox = isSelectionMode && access.canDelete
            let hasPreview = !isSelectionMode
            let hasDelete = access.canDelete && !isSelectionMode
            let columnWidths = Self.columnWidths(
                totalWidth: tableWidth,
                hasCheckbox: hasCheckbox,
                hasPreview: hasPreview,
                hasDelete: hasDelete
            )

            List {
                Section {
                    tableHeaderRow(
                        columnWidths: columnWidths,
                        hasCheckbox: hasCheckbox,
                        hasPreview: hasPreview,
                        hasDelete: hasDelete
                    )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color(.secondarySystemBackground))
                }

                ForEach(filteredRecords) { record in
                    tableDataRow(
                        record: record,
                        columnWidths: columnWidths,
                        hasCheckbox: hasCheckbox,
                        hasPreview: hasPreview,
                        hasDelete: hasDelete
                    )
                    .listRowInsets(EdgeInsets())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelectionMode && access.canDelete {
                            toggleRecordSelection(record.id)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if access.canDelete && !isSelectionMode {
                            Button(role: .destructive) {
                                recordToDelete = record
                                showDeleteConfirm = true
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(width: tableWidth, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScrollBottomPadding()
    }

    private func tableHeaderRow(
        columnWidths: [CGFloat],
        hasCheckbox: Bool,
        hasPreview: Bool,
        hasDelete: Bool
    ) -> some View {
        HStack(spacing: 0) {
            if hasCheckbox {
                Color.clear.frame(width: Self.checkboxWidth)
            }
            headerCell(L10n.tr("module.clients.z_reports.col_z_number"), width: columnWidths[0], alignment: .leading)
            headerCell(L10n.tr("module.clients.z_reports.col_date"), width: columnWidths[1], alignment: .leading)
            headerCell(L10n.tr("module.clients.z_reports.col_total"), width: columnWidths[2], alignment: .trailing)
            headerCell(L10n.tr("module.clients.z_reports.col_cash"), width: columnWidths[3], alignment: .trailing)
            headerCell(L10n.tr("module.clients.z_reports.col_card"), width: columnWidths[4], alignment: .trailing)
            headerCell(L10n.tr("module.clients.z_reports.col_modern"), width: columnWidths[5], alignment: .trailing)
            if hasPreview {
                Color.clear.frame(width: Self.previewWidth)
            }
            if hasDelete {
                Color.clear.frame(width: Self.deleteWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func tableDataRow(
        record: CompanyZReportRecord,
        columnWidths: [CGFloat],
        hasCheckbox: Bool,
        hasPreview: Bool,
        hasDelete: Bool
    ) -> some View {
        HStack(spacing: 0) {
            if hasCheckbox {
                Button {
                    toggleRecordSelection(record.id)
                } label: {
                    BulkDeleteSelectionCheckbox(isSelected: selectedRecordIds.contains(record.id))
                }
                .buttonStyle(.plain)
                .frame(width: Self.checkboxWidth)
            }

            valueCell("\(record.zNumber)", width: columnWidths[0], alignment: .leading)
            valueCell(accountingDateLabel(for: record), width: columnWidths[1], alignment: .leading)
            valueCell(SupplierFormatting.currency(record.totalVanzari), width: columnWidths[2], alignment: .trailing)
            valueCell(SupplierFormatting.currency(record.numerar), width: columnWidths[3], alignment: .trailing)
            valueCell(SupplierFormatting.currency(record.card), width: columnWidths[4], alignment: .trailing)
            valueCell(SupplierFormatting.currency(record.plataModerna), width: columnWidths[5], alignment: .trailing)

            if hasPreview {
                Button {
                    openPreview(for: record)
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(record.canPreviewPDF ? Color.accentColor : AppColors.tertiary)
                }
                .buttonStyle(.plain)
                .frame(width: Self.previewWidth)
                .disabled(!record.canPreviewPDF)
                .accessibilityLabel(L10n.tr("module.clients.z_reports.preview_action"))
            }

            if hasDelete {
                Button {
                    recordToDelete = record
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .frame(width: Self.deleteWidth)
                .accessibilityLabel(L10n.tr("common.delete"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private static let checkboxWidth: CGFloat = 40
    private static let previewWidth: CGFloat = 44
    private static let deleteWidth: CGFloat = 44

    /// Proporții coloane: Nr Z, Dată, Total, Numerar, Card, Plată modernă
    private static let columnWidthFractions: [CGFloat] = [0.09, 0.14, 0.19, 0.19, 0.19, 0.20]

    private static func columnWidths(
        totalWidth: CGFloat,
        hasCheckbox: Bool,
        hasPreview: Bool,
        hasDelete: Bool
    ) -> [CGFloat] {
        var reserved: CGFloat = 0
        if hasCheckbox { reserved += checkboxWidth }
        if hasPreview { reserved += previewWidth }
        if hasDelete { reserved += deleteWidth }
        let available = max(0, totalWidth - reserved)
        var widths = columnWidthFractions.map { floor(available * $0) }
        let used = widths.reduce(0, +)
        if let lastIndex = widths.indices.last {
            widths[lastIndex] += max(0, available - used)
        }
        return widths
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(AppColors.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: alignment)
    }

    private func valueCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title)
            .font(.body.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 6)
            .frame(width: width, alignment: alignment)
    }

    private var exportBar: some View {
        VStack(spacing: 8) {
            Text(L10n.tr("module.clients.z_reports.export_hint", filteredRecords.count))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                exportFilteredNC()
            } label: {
                #if targetEnvironment(macCatalyst)
                Label(L10n.tr("module.clients.z_reports.export_nc_mac"), systemImage: "square.and.arrow.down")
                #elseif os(iOS)
                Label(L10n.tr("module.clients.z_reports.export_nc_ios"), systemImage: "square.and.arrow.up")
                #else
                Label(L10n.tr("module.clients.z_reports.export_nc_mac"), systemImage: "square.and.arrow.up")
                #endif
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else {
            records = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            records = try await ClientZReportService.fetchReports(companyId: companyId)
            zettaNCConfig = try await loadZettaNCConfig(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func accountingDateLabel(for record: CompanyZReportRecord) -> String {
        SupplierFormatting.date(record.accountingDate)
    }

    private func openPreview(for record: CompanyZReportRecord) {
        guard record.canPreviewPDF else {
            errorMessage = L10n.tr("module.clients.z_reports.preview_unavailable")
            return
        }
        guard let pdfData = ZReportPDFBuilder.makePDF(from: record.reportData) else {
            errorMessage = L10n.tr("module.clients.z_reports.preview_unavailable")
            return
        }
        errorMessage = nil
        pdfPreview = ZReportPDFPreviewItem(record: record, pdfData: pdfData)
    }

    private func deleteConfirmationMessage(for record: CompanyZReportRecord) -> String {
        var parts: [String] = [
            L10n.tr(
                "module.clients.z_reports.delete_confirm_base",
                record.zNumber,
                SupplierFormatting.date(record.accountingDate)
            )
        ]
        if record.numerar > 0 {
            parts.append(L10n.tr("module.clients.z_reports.delete_confirm_cash", SupplierFormatting.currency(record.numerar)))
        }
        if record.card > 0 {
            parts.append(L10n.tr("module.clients.z_reports.delete_confirm_bank", SupplierFormatting.currency(record.card)))
        }
        if record.plataModerna > 0 {
            parts.append(L10n.tr("module.clients.z_reports.delete_confirm_modern", SupplierFormatting.currency(record.plataModerna)))
        }
        return parts.joined(separator: "\n")
    }

    private func deleteRecord(_ record: CompanyZReportRecord) async {
        await deleteRecords([record.id], successMessage: L10n.tr("module.clients.z_reports.deleted", record.zNumber))
        recordToDelete = nil
    }

    private func deleteSelectedRecords() async {
        let ids = Array(selectedRecordIds)
        guard !ids.isEmpty else { return }
        await deleteRecords(
            ids,
            successMessage: L10n.tr("module.clients.z_reports.bulk_deleted", ids.count)
        )
        exitSelectionMode()
    }

    private func deleteRecords(_ ids: [UUID], successMessage: String) async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            try await ClientZReportService.deleteReports(ids: ids, companyId: companyId)
            NotificationCenter.default.post(name: .clientZReportsDidChange, object: companyId)
            statusMessage = successMessage
            await reload()
        } catch {
            errorMessage = L10n.tr("module.clients.z_reports.delete_failed", error.localizedDescription)
        }
    }

    private func enterSelectionMode() {
        isSelectionMode = true
        selectedRecordIds.removeAll()
        errorMessage = nil
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedRecordIds.removeAll()
        showBulkDeleteConfirm = false
    }

    private func toggleRecordSelection(_ id: UUID) {
        if selectedRecordIds.contains(id) {
            selectedRecordIds.remove(id)
        } else {
            selectedRecordIds.insert(id)
        }
    }

    private func toggleSelectAllFilteredRecords() {
        if allFilteredRecordsSelected {
            selectedRecordIds.subtract(filteredRecordIds)
        } else {
            selectedRecordIds.formUnion(filteredRecordIds)
        }
    }

    private func pruneSelection() {
        selectedRecordIds.formIntersection(filteredRecordIds)
    }

    private func loadZettaNCConfig(companyId: UUID) async throws -> ZettaNCConfig? {
        _ = try await ZettaSettingsService.ensureWarehousesForWorkLocations(companyId: companyId)
        let locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
        var settings = try await ZettaSettingsService.fetchSettings(companyId: companyId)
        settings.payload.syncLocationAccounts(with: locations)
        return ZettaNCConfig(settings: settings.payload, workLocations: locations)
    }

    private func exportFilteredNC() {
        let reports = filteredRecords.map(\.reportData).sortedForExport()
        guard !reports.isEmpty else { return }

        exportModel.prepareForExport(reports: reports, config: zettaNCConfig)
        errorMessage = exportModel.errorMessage
        exportModel.exportExcel()
        statusMessage = exportModel.statusMessage
        errorMessage = exportModel.errorMessage
    }
}

private struct ZReportPDFPreviewItem: Identifiable {
    let id: UUID
    let title: String
    let pdfData: Data

    init(record: CompanyZReportRecord, pdfData: Data) {
        id = record.id
        self.pdfData = pdfData
        title = L10n.tr(
            "module.clients.z_reports.preview_title",
            record.zNumber,
            SupplierFormatting.date(record.accountingDate)
        )
    }
}
