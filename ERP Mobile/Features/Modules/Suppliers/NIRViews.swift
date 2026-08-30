import SwiftUI

struct NIRListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager

    @State private var nirs: [SupplierNIRRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var nirToDelete: SupplierNIRRow?
    @State private var showDeleteConfirm = false
    @State private var isSelectionMode = false
    @State private var selectedNIRIds = Set<UUID>()
    @State private var showBulkDeleteConfirm = false
    @State private var filterNirNumber = ""
    @State private var filterInvoiceNumber = ""
    @State private var filterSupplierName = ""
    @State private var filterDateIntervalEnabled = false
    @State private var filterDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var filterDateTo = Calendar.current.startOfDay(for: Date())

    private var hasActiveFilters: Bool {
        !filterNirNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filterDateIntervalEnabled
    }

    private var filteredNIRs: [SupplierNIRRow] {
        nirs.filter { nir in
            let nirQuery = filterNirNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !nirQuery.isEmpty,
               !nir.numarNir.localizedCaseInsensitiveContains(nirQuery) {
                return false
            }

            let invoiceQuery = filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !invoiceQuery.isEmpty,
               !nir.invoiceNumber.localizedCaseInsensitiveContains(invoiceQuery) {
                return false
            }

            let supplierQuery = filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !supplierQuery.isEmpty,
               !nir.supplierName.localizedCaseInsensitiveContains(supplierQuery) {
                return false
            }

            if filterDateIntervalEnabled {
                let nirDay = Calendar.current.startOfDay(for: nir.dataNir)
                let fromDay = Calendar.current.startOfDay(for: filterDateFrom)
                let toDay = Calendar.current.startOfDay(for: filterDateTo)
                let rangeStart = min(fromDay, toDay)
                let rangeEnd = max(fromDay, toDay)
                if nirDay < rangeStart || nirDay > rangeEnd { return false }
            }

            return true
        }
    }

    private var displayedNIRIds: Set<UUID> {
        Set(filteredNIRs.map(\.id))
    }

    private var allDisplayedNIRsSelected: Bool {
        !filteredNIRs.isEmpty && displayedNIRIds.isSubset(of: selectedNIRIds)
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            Group {
                if filteredNIRs.isEmpty && !isLoading {
                    AppEmptyStateView(
                        hasActiveFilters ? L10n.tr("nir.list_empty_filtered") : L10n.tr("nir.list_empty"),
                        systemImage: "shippingbox",
                        description: Text(
                            hasActiveFilters
                                ? L10n.tr("payments.empty_filtered_hint")
                                : L10n.tr("nir.list_empty_hint")
                        )
                    )
                } else {
                    List {
                        ForEach(filteredNIRs) { nir in
                            NIRListRowView(
                                nir: nir,
                                access: access,
                                canDelete: access.canDelete,
                                isSelectionMode: isSelectionMode && access.canDelete,
                                isSelected: selectedNIRIds.contains(nir.id),
                                onToggleSelection: { toggleNIRSelection(nir.id) },
                                onDelete: { requestDelete(nir) },
                                onChanged: {
                                    await loadNIRs()
                                    await onChanged()
                                }
                            )
                        }
                        .onDelete(perform: access.canDelete && !isSelectionMode ? deleteItems : { _ in })
                    }
                    .appScrollBottomPadding()
                }
            }
        }
        .appSafeAreaInsetBottom {
            if isSelectionMode && access.canDelete {
                BulkDeleteSelectionBottomBar(
                    selectedCount: selectedNIRIds.count,
                    onDelete: { showBulkDeleteConfirm = true }
                )
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadNIRs() }
        .appRefreshable { await loadNIRs() }
        .onChange(of: filteredNIRs.map(\.id)) { _ in
            pruneNIRSelection()
        }
        .bulkDeleteSelectionToolbar(
            enabled: access.canDelete,
            isSelectionMode: isSelectionMode,
            allVisibleSelected: allDisplayedNIRsSelected,
            hasVisibleItems: !filteredNIRs.isEmpty,
            selectedCount: selectedNIRIds.count,
            onEnterSelection: enterSelectionMode,
            onExitSelection: exitSelectionMode,
            onToggleSelectAll: toggleSelectAllDisplayedNIRs,
            onDeleteSelected: { showBulkDeleteConfirm = true }
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !isSelectionMode {
                    NavigationLink {
                        NIRMarkupAccountingView()
                    } label: {
                        Label(L10n.tr("nir.markup_accounting_action"), systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .alert(L10n.tr("nir.delete_title"), isPresented: $showDeleteConfirm, presenting: nirToDelete) { nir in
            Button(L10n.tr("common.delete")) {
                Task { @MainActor in
                    await deleteNIR(nir)
                }
            }
            Button(L10n.tr("common.cancel")) {
                nirToDelete = nil
            }
        } message: { nir in
            Text(L10n.tr("nir.delete_confirm", nir.numarNir))
        }
        .alert(L10n.tr("nir.bulk_delete_title"), isPresented: $showBulkDeleteConfirm) {
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { @MainActor in
                    await deleteSelectedNIRs()
                }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("nir.bulk_delete_confirm", selectedNIRIds.count))
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                if hasActiveFilters {
                    Button(L10n.tr("nir.list_filter_reset")) {
                        resetFilters()
                    }
                    .font(.subheadline)
                }
            }

            TextField(L10n.tr("nir.list_filter_nir_number"), text: $filterNirNumber)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .autocorrectionDisabled()

            TextField(L10n.tr("nir.list_filter_invoice_number"), text: $filterInvoiceNumber)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .autocorrectionDisabled()

            TextField(L10n.tr("nir.list_filter_supplier_name"), text: $filterSupplierName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Toggle(L10n.tr("nir.list_filter_date_interval"), isOn: $filterDateIntervalEnabled)
                .font(.subheadline)

            if filterDateIntervalEnabled {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("payments.filter_date_from"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        AppDatePicker(selection: $filterDateFrom)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("payments.filter_date_to"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        AppDatePicker(selection: $filterDateTo)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func resetFilters() {
        filterNirNumber = ""
        filterInvoiceNumber = ""
        filterSupplierName = ""
        filterDateIntervalEnabled = false
        filterDateFrom = Calendar.current.startOfDay(for: Date())
        filterDateTo = Calendar.current.startOfDay(for: Date())
        pruneNIRSelection()
    }

    private func enterSelectionMode() {
        isSelectionMode = true
        selectedNIRIds.removeAll()
        errorMessage = nil
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedNIRIds.removeAll()
        showBulkDeleteConfirm = false
    }

    private func toggleNIRSelection(_ id: UUID) {
        if selectedNIRIds.contains(id) {
            selectedNIRIds.remove(id)
        } else {
            selectedNIRIds.insert(id)
        }
    }

    private func toggleSelectAllDisplayedNIRs() {
        if allDisplayedNIRsSelected {
            selectedNIRIds.subtract(displayedNIRIds)
        } else {
            selectedNIRIds.formUnion(displayedNIRIds)
        }
    }

    private func pruneNIRSelection() {
        selectedNIRIds.formIntersection(displayedNIRIds)
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first, filteredNIRs.indices.contains(index) else { return }
        requestDelete(filteredNIRs[index])
    }

    private func requestDelete(_ nir: SupplierNIRRow) {
        nirToDelete = nir
        showDeleteConfirm = true
    }

    private func loadNIRs() async {
        guard let companyId = companyManager.currentCompany?.id else {
            await MainActor.run {
                nirs = []
                isLoading = false
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let rows = try await SupplierNIRService.fetchNIRRows(companyId: companyId)
            await MainActor.run {
                nirs = rows
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deleteNIR(_ nir: SupplierNIRRow) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            try await SupplierNIRService.deleteNIR(id: nir.id)
            await loadNIRs()
            await refreshParentAfterLocalUpdate()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
        await MainActor.run {
            nirToDelete = nil
        }
    }

    private func deleteSelectedNIRs() async {
        let ids = selectedNIRIds
        guard !ids.isEmpty else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        var deletedCount = 0
        var failedCount = 0

        for id in ids {
            do {
                try await SupplierNIRService.deleteNIR(id: id)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }

        exitSelectionMode()
        await loadNIRs()
        await refreshParentAfterLocalUpdate()

        await MainActor.run {
            isLoading = false
            showBulkDeleteConfirm = false
            if failedCount > 0 {
                errorMessage = L10n.tr("nir.bulk_delete_summary", deletedCount, failedCount)
            }
        }
    }

    private func refreshParentAfterLocalUpdate() async {
        await Task.yield()
        await onChanged()
    }
}

private struct NIRListRowView: View {
    let nir: SupplierNIRRow
    let access: ModuleAccessRights
    let canDelete: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    let onDelete: () -> Void
    let onChanged: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelectionMode {
                Button {
                    onToggleSelection?()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        BulkDeleteSelectionCheckbox(isSelected: isSelected)
                        NIRRowView(nir: nir)
                    }
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    NIRDetailView(
                        row: nir,
                        access: access,
                        onChanged: onChanged
                    )
                } label: {
                    NIRRowView(nir: nir)
                }
                .buttonStyle(.plain)

                if ListRowActions.prefersExplicitDeleteButton && canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(L10n.tr("common.delete"))
                }
            }
        }
        .contextMenu {
            if !isSelectionMode && canDelete {
                Button(action: onDelete) {
                    Label(L10n.tr("common.delete"), systemImage: "trash")
                }
            }
        }
        .appSwipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete && !isSelectionMode {
                Button(action: onDelete) {
                    Label(L10n.tr("common.delete"), systemImage: "trash")
                }
            }
        }
    }
}

private struct NIRRowView: View {
    let nir: SupplierNIRRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(nir.numarNir)
                    .font(.headline)
                Spacer()
                Text(SupplierFormatting.date(nir.dataNir))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            Text(nir.invoiceNumber)
                .font(.subheadline)
            Text(nir.supplierName)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NIRDetailView: View {
    let row: SupplierNIRRow
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var nir: SupplierNIR?
    @State private var nirLines: [SupplierNIRLine] = []
    @State private var invoice: SupplierInvoice?
    @State private var supplier: Supplier?
    @State private var workLocationName: String?
    @State private var warehouseName: String?
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var exportItem: NIRExportItem?
    @State private var editorContext: NIREditorContext?
    @State private var showDeleteConfirm = false

    var body: some View {
        Group {
            if isLoading && nir == nil {
                ProgressView(L10n.tr("common.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                detailContent
            }
        }
        .navigationTitle(L10n.tr("nir.detail_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if access.canEdit {
                        Button(L10n.tr("common.edit")) {
                            openEditor()
                        }
                        .disabled(isLoading || invoice == nil || supplier == nil || nir == nil)
                    }
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Group {
                    if access.canDelete {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading || isExporting) }
        .appTask { await loadDetail() }
        .appRefreshable { await loadDetail() }
        .sheet(item: $exportItem) { item in
            NIRExportFlowView(
                exportItem: item,
                defaultEmail: companyManager.currentCompany?.email,
                onFinish: { exportItem = nil }
            )
        }
        .fullScreenCover(item: $editorContext) { context in
            if let company = companyManager.currentCompany {
                NIREditorView(
                    context: context,
                    company: company,
                    createdBy: session.currentProfile?.id,
                    onSaved: {
                        await loadDetail()
                        await onChanged()
                    },
                    onFinish: { _ in
                        editorContext = nil
                    }
                )
            }
        }
        .alert(L10n.tr("nir.delete_title"), isPresented: $showDeleteConfirm) {
            Button(L10n.tr("common.delete")) {
                Task { @MainActor in
                    await deleteNIR()
                }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: {
            Text(L10n.tr("nir.delete_confirm", row.numarNir))
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        List {
            Section(header: Text(L10n.tr("nir.export_section_document"))) {
                AppLabeledContent(L10n.tr("nir.export_number"), value: nir?.numarNir ?? row.numarNir)
                AppLabeledContent(L10n.tr("nir.export_invoice"), value: row.invoiceNumber)
                AppLabeledContent(L10n.tr("nir.export_supplier"), value: supplier?.denumire ?? row.supplierName)
                AppLabeledContent(L10n.tr("invoices.field_invoice_date"), value: SupplierFormatting.date(invoice?.dataFactura ?? row.invoice?.dataFactura))
                AppLabeledContent(L10n.tr("nir.detail_date"), value: SupplierFormatting.date(nir?.dataNir ?? row.dataNir))
                if let workLocationName {
                    AppLabeledContent(L10n.tr("invoices.field_work_location_required"), value: workLocationName)
                }
                if let warehouseName {
                    AppLabeledContent(L10n.tr("invoices.field_warehouse_required"), value: warehouseName)
                }
            }

            Section(header: Text(L10n.tr("nir.detail_section_lines"))) {
                if nirLines.isEmpty {
                    Text(L10n.tr("nir.editor_no_selected_lines"))
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(nirLines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.denumire)
                                .font(.headline)
                            Text(
                                L10n.tr(
                                    "nir.editor_line_summary",
                                    SupplierFormatting.amountString(line.cantitate),
                                    line.unitateMasura,
                                    SupplierFormatting.amountString(line.pretUnitar),
                                    SupplierFormatting.amountString(line.sumaLinie)
                                )
                            )
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                            if let note = StockUnitConversion.reception(nirLine: line).note {
                                Text(note)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L10n.tr("nir.export_section_actions"))) {
                Button {
                    Task { await exportPDF() }
                } label: {
                    Label(L10n.tr("nir.export_save_pdf"), systemImage: "doc.richtext")
                }
                .disabled(isExporting || nir == nil || supplier == nil || invoice == nil)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
        .appScrollBottomPadding()
    }

    private func loadDetail() async {
        guard let company = companyManager.currentCompany else { return }

        isLoading = true
        errorMessage = nil
        do {
            let loadedNIR = try await SupplierNIRService.fetchNIR(id: row.id)
            let loadedInvoice = try await SupplierService.fetchInvoice(id: loadedNIR.invoiceId)
            let loadedSupplier = try await SupplierService.fetchSupplier(id: loadedInvoice.supplierId)
            let loadedLines = try await SupplierNIRService.fetchNIRLines(nirId: loadedNIR.id)
            let (workLocations, warehouses) = try await InvoiceReceptionSupport.loadOptionsData(companyId: company.id)
            let names = InvoiceReceptionSupport.receptionNames(
                workLocationId: loadedNIR.workLocationId,
                warehouseId: loadedNIR.warehouseId,
                workLocations: workLocations,
                warehouses: warehouses
            )
            await MainActor.run {
                nir = loadedNIR
                invoice = loadedInvoice
                supplier = loadedSupplier
                nirLines = loadedLines
                workLocationName = names.workLocationName
                warehouseName = names.warehouseName
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func openEditor() {
        guard let invoice, let supplier, let nir else { return }
        editorContext = NIREditorContext(
            invoice: invoice,
            supplier: supplier,
            workLocationId: nir.workLocationId,
            warehouseId: nir.warehouseId,
            workLocationName: workLocationName,
            warehouseName: warehouseName,
            existingNIR: nir
        )
    }

    private func exportPDF() async {
        guard let company = companyManager.currentCompany,
              let nir,
              let invoice,
              let supplier else { return }

        isExporting = true
        errorMessage = nil
        do {
            let item = try await SupplierNIRService.prepareExport(
                company: company,
                supplier: supplier,
                invoice: invoice,
                nir: nir,
                workLocationName: workLocationName,
                warehouseName: warehouseName
            )
            await MainActor.run {
                exportItem = item
                isExporting = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isExporting = false
            }
        }
    }

    private func deleteNIR() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            try await SupplierNIRService.deleteNIR(id: row.id)
            await MainActor.run {
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            }
            await Task.yield()
            await onChanged()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
