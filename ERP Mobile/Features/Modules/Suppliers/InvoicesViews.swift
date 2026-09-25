import SwiftUI

struct InvoicesListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var invoices: [SupplierInvoiceRow] = []
    @State private var invoiceIdsWithNIR: Set<UUID> = []
    @State private var incompleteReceptionInvoiceIds: Set<UUID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var invoiceToEdit: SupplierInvoiceRow?
    @State private var invoiceToDelete: SupplierInvoiceRow?
    @State private var showDeleteConfirm = false
    @State private var invoiceToCloseReception: SupplierInvoiceRow?
    @State private var showCloseReceptionConfirm = false
    @State private var isSelectionMode = false
    @State private var selectedInvoiceIds = Set<UUID>()
    @State private var showBulkDeleteConfirm = false
    @State private var statusFilter: InvoiceStatus?
    @State private var entryPeriodFilter: InvoiceListPeriodFilter = .today
    @State private var filterInvoiceNumber = ""
    @State private var filterSupplierName = ""
    @State private var filterDateIntervalEnabled = false
    @State private var filterDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var filterDateTo = Calendar.current.startOfDay(for: Date())
    @State private var showImportSourceDialog = false
    @State private var showDirectoryPicker = false
    @State private var showFilePicker = false
    @State private var importSummaryMessage: String?
    @State private var showImportSummary = false
    @State private var pendingImportSummaryMessage: String?
    @State private var importPreviewItems: [EFacturaImportPreviewItem] = []
    @State private var showImportPreviewSheet = false
    @State private var importReceptionOptions = InvoiceReceptionOptions()
    @State private var importReceptionRequirements = InvoiceReceptionRequirements(workLocations: [], warehouses: [])
    @State private var importWorkLocations: [CompanyWorkLocation] = []
    @State private var importWarehouses: [CompanyWarehouse] = []
    @State private var nirEditorContexts: [NIREditorContext] = []
    @State private var showNIREditorQueue = false
    @State private var creditNoteOffsetContexts: [CreditNoteOffsetContext] = []
    @State private var showCreditNoteOffsetQueue = false
    @State private var pendingCreditNoteOffsetInvoiceIds: [UUID] = []

    private var hasActiveFilters: Bool {
        entryPeriodFilter != .today
            || statusFilter != nil
            || !filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filterDateIntervalEnabled
    }

    private var listDateQueryKey: String {
        if filterDateIntervalEnabled {
            return "invoice|\(filterDateFrom.timeIntervalSince1970)|\(filterDateTo.timeIntervalSince1970)"
        }
        return "created|\(String(describing: entryPeriodFilter))"
    }

    private var filteredInvoices: [SupplierInvoiceRow] {
        invoices.filter { invoice in
            if !filterDateIntervalEnabled,
               !entryPeriodFilter.includes(createdAt: invoice.createdAt) {
                return false
            }

            if let statusFilter, invoice.status != statusFilter { return false }

            let numberQuery = filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !numberQuery.isEmpty,
               !invoice.numarFactura.localizedCaseInsensitiveContains(numberQuery) {
                return false
            }

            let supplierQuery = filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !supplierQuery.isEmpty,
               !invoice.supplierName.localizedCaseInsensitiveContains(supplierQuery) {
                return false
            }

            if filterDateIntervalEnabled {
                let invoiceDay = Calendar.current.startOfDay(for: invoice.dataFactura)
                let fromDay = Calendar.current.startOfDay(for: filterDateFrom)
                let toDay = Calendar.current.startOfDay(for: filterDateTo)
                let rangeStart = min(fromDay, toDay)
                let rangeEnd = max(fromDay, toDay)
                if invoiceDay < rangeStart || invoiceDay > rangeEnd { return false }
            }

            return true
        }
    }

    private var displayedInvoices: [SupplierInvoiceRow] {
        filteredInvoices.sorted { lhs, rhs in
            if lhs.dataFactura != rhs.dataFactura {
                return lhs.dataFactura > rhs.dataFactura
            }
            return lhs.numarFactura.localizedStandardCompare(rhs.numarFactura) == .orderedAscending
        }
    }

    private var displayedInvoiceIds: Set<UUID> {
        Set(displayedInvoices.map(\.id))
    }

    private var allDisplayedInvoicesSelected: Bool {
        !displayedInvoices.isEmpty && displayedInvoiceIds.isSubset(of: selectedInvoiceIds)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Menu {
                        ForEach(InvoiceListPeriodFilter.allCases) { period in
                            Button(period.label) { entryPeriodFilter = period }
                        }
                    } label: {
                        Label(entryPeriodFilter.label, systemImage: "calendar")
                            .font(.subheadline)
                    }

                    Menu {
                        Button(L10n.tr("invoices.filter_all")) { statusFilter = nil }
                        Divider()
                        ForEach(InvoiceStatus.allCases) { status in
                            Button(status.label) { statusFilter = status }
                        }
                    } label: {
                        Label(statusFilter?.label ?? L10n.tr("invoices.all"), systemImage: "line.3.horizontal.decrease.circle")
                            .font(.subheadline)
                    }

                    Spacer()

                    if hasActiveFilters {
                        Button(L10n.tr("invoices.filter_reset")) {
                            resetFilters()
                        }
                        .font(.subheadline)
                    }
                }

                TextField(L10n.tr("invoices.filter_invoice_number"), text: $filterInvoiceNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField(L10n.tr("invoices.filter_supplier_name"), text: $filterSupplierName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Toggle(L10n.tr("invoices.filter_date_interval"), isOn: $filterDateIntervalEnabled)
                    .font(.subheadline)
                    .onChange(of: filterDateIntervalEnabled) { enabled in
                        if enabled {
                            entryPeriodFilter = .all
                        }
                    }

                if filterDateIntervalEnabled {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("invoices.filter_date_from"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            AppDatePicker(selection: $filterDateFrom)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("invoices.filter_date_to"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            AppDatePicker(selection: $filterDateTo)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Group {
                if displayedInvoices.isEmpty && !isLoading {
                    AppEmptyStateView(
                        hasActiveFilters ? L10n.tr("invoices.empty_filtered") : L10n.tr("invoices.empty"),
                        systemImage: "doc.text",
                        description: Text(
                            hasActiveFilters
                                ? L10n.tr("invoices.empty_filtered_hint")
                                : (access.canCreate
                                    ? L10n.tr("invoices.empty_create")
                                    : L10n.tr("invoices.empty_readonly"))
                        )
                    )
                } else {
                    List {
                        Section {
                            ForEach(displayedInvoices) { invoice in
                                InvoiceRowView(
                                    invoice: invoice,
                                    receptionStatus: InvoiceReceptionListStatus.resolve(
                                        isCreditNote: invoice.isCreditNote,
                                        status: invoice.status,
                                        receptionClosed: invoice.receptionClosed,
                                        hasNIR: invoiceIdsWithNIR.contains(invoice.id),
                                        isIncomplete: incompleteReceptionInvoiceIds.contains(invoice.id)
                                    ),
                                    canEditReception: access.canEdit || access.canCreate,
                                    canDelete: access.canDelete,
                                    isSelectionMode: isSelectionMode && access.canDelete,
                                    isSelected: selectedInvoiceIds.contains(invoice.id),
                                    onToggleSelection: { toggleInvoiceSelection(invoice.id) },
                                    onEdit: {
                                        if access.canEdit { invoiceToEdit = invoice }
                                    },
                                    onAddReception: {
                                        Task { await openReception(for: invoice) }
                                    },
                                    onCloseReception: {
                                        invoiceToCloseReception = invoice
                                        showCloseReceptionConfirm = true
                                    },
                                    onDelete: { requestDelete(invoice) }
                                )
                            }
                            .onDelete(perform: access.canDelete && !isSelectionMode ? deleteItems : { _ in })
                        } header: {
                            HStack {
                                Text(L10n.tr("invoices.list_count", displayedInvoices.count))
                                Spacer()
                                Text(L10n.tr("invoices.column_reception"))
                                    .frame(minWidth: 120, alignment: .trailing)
                            }
                            .font(.caption.bold())
                            .foregroundColor(AppColors.secondary)
                            .textCase(nil)
                        }
                    }
                    .appScrollBottomPadding()
                }
            }
        }
        .floatingBottomTrailing {
            if access.canCreate && !isSelectionMode {
                VStack(alignment: .trailing, spacing: 10) {
                    Button { showImportSourceDialog = true } label: {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 36))
                            .appSymbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(L10n.tr("invoices.import_efactura"))

                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .appSymbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .appSafeAreaInsetBottom {
            if isSelectionMode && access.canDelete {
                BulkDeleteSelectionBottomBar(
                    selectedCount: selectedInvoiceIds.count,
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
        .bulkDeleteSelectionToolbar(
            enabled: access.canDelete,
            isSelectionMode: isSelectionMode,
            allVisibleSelected: allDisplayedInvoicesSelected,
            hasVisibleItems: !displayedInvoices.isEmpty,
            selectedCount: selectedInvoiceIds.count,
            onEnterSelection: enterSelectionMode,
            onExitSelection: exitSelectionMode,
            onToggleSelectAll: toggleSelectAllDisplayedInvoices,
            onDeleteSelected: { showBulkDeleteConfirm = true }
        )
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadInvoices() }
        .appRefreshable { await loadInvoices() }
        .onChange(of: listDateQueryKey) { _ in
            Task { await loadInvoices() }
        }
        .onChange(of: displayedInvoices.map(\.id)) { _ in
            pruneInvoiceSelection()
        }
        .fullScreenCover(isPresented: $showCreate) {
            InvoiceFormView(mode: .create, access: access) {
                await loadInvoices()
                await onChanged()
            }
        }
        .fullScreenCover(item: $invoiceToEdit) { invoice in
            InvoiceFormView(mode: .edit(invoice), access: access) {
                await loadInvoices()
                await onChanged()
            }
        }
        .alert(L10n.tr("invoices.delete_title"), isPresented: $showDeleteConfirm, presenting: invoiceToDelete) { invoice in
            Button(L10n.tr("common.delete")) {
                Task { @MainActor in
                    await deleteInvoice(invoice)
                }
            }
            Button(L10n.tr("common.cancel")) {
                invoiceToDelete = nil
            }
        } message: { invoice in
            Text(L10n.tr("invoices.delete_confirm", invoice.numarFactura))
        }
        .alert(
            L10n.tr("invoices.close_reception_title"),
            isPresented: $showCloseReceptionConfirm,
            presenting: invoiceToCloseReception
        ) { invoice in
            Button(L10n.tr("invoices.close_reception_action")) {
                Task { await closeReception(invoice) }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {
                invoiceToCloseReception = nil
            }
        } message: { invoice in
            Text(L10n.tr("invoices.close_reception_confirm", invoice.numarFactura))
        }
        .alert(L10n.tr("invoices.bulk_delete_title"), isPresented: $showBulkDeleteConfirm) {
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { @MainActor in
                    await deleteSelectedInvoices()
                }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("invoices.bulk_delete_confirm", selectedInvoiceIds.count))
        }
        .confirmationDialog(
            L10n.tr("invoices.import_choose_source"),
            isPresented: $showImportSourceDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("invoices.import_from_directory")) {
                showDirectoryPicker = true
            }
            Button(L10n.tr("invoices.import_from_files")) {
                showFilePicker = true
            }
            Button(L10n.tr("common.cancel")) {}
        } message: {
            Text(L10n.tr("invoices.import_source_hint"))
        }
        .fullScreenCover(isPresented: $showDirectoryPicker) {
            DocumentDirectoryPicker(
                isPresented: $showDirectoryPicker,
                onPick: { directoryURL in
                    Task { await prepareImportDirectory(directoryURL) }
                },
                onCancel: {}
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showFilePicker) {
            DocumentXMLFilePicker(
                isPresented: $showFilePicker,
                onPick: { urls in
                    Task { await prepareImportFiles(urls) }
                },
                onCancel: {}
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImportPreviewSheet) {
            InvoiceImportPreviewSheet(
                items: $importPreviewItems,
                options: $importReceptionOptions,
                requirements: importReceptionRequirements,
                workLocations: importWorkLocations,
                warehouses: importWarehouses,
                onConfirm: {
                    let items = importPreviewItems
                    let options = importReceptionOptions
                    showImportPreviewSheet = false
                    Task { @MainActor in
                        await Task.yield()
                        importPreviewItems = []
                        await importEFacturaFiles(items, options: options)
                    }
                },
                onCancel: {
                    showImportPreviewSheet = false
                    Task { @MainActor in
                        await Task.yield()
                        importPreviewItems = []
                    }
                }
            )
        }
        .appFullOverlay {
            if showCreditNoteOffsetQueue, !creditNoteOffsetContexts.isEmpty {
                CreditNoteOffsetQueueView(
                    contexts: $creditNoteOffsetContexts,
                    onFinish: {
                        showCreditNoteOffsetQueue = false
                        creditNoteOffsetContexts = []
                        pendingCreditNoteOffsetInvoiceIds = []
                        Task { @MainActor in
                            await Task.yield()
                            await loadInvoices()
                            await onChanged()
                            if let pendingImportSummaryMessage {
                                importSummaryMessage = pendingImportSummaryMessage
                                showImportSummary = true
                                self.pendingImportSummaryMessage = nil
                            }
                        }
                    }
                )
            } else if showNIREditorQueue, let company = companyManager.currentCompany {
                NIREditorQueueView(
                    contexts: $nirEditorContexts,
                    company: company,
                    createdBy: session.currentProfile?.id,
                    onSaved: {
                        await loadInvoices()
                    },
                    onFinish: {
                        showNIREditorQueue = false
                        nirEditorContexts = []
                        Task { @MainActor in
                            await Task.yield()
                            await onChanged()
                            if !pendingCreditNoteOffsetInvoiceIds.isEmpty {
                                let ids = pendingCreditNoteOffsetInvoiceIds
                                pendingCreditNoteOffsetInvoiceIds = []
                                Task {
                                    await prepareCreditNoteOffsetQueue(invoiceIds: ids)
                                }
                            } else if let pendingImportSummaryMessage {
                                importSummaryMessage = pendingImportSummaryMessage
                                showImportSummary = true
                                self.pendingImportSummaryMessage = nil
                            }
                        }
                    }
                )
            }
        }
        .alert(L10n.tr("invoices.import_summary_title"), isPresented: $showImportSummary) {
            Button(L10n.tr("common.ok")) {}
        } message: {
            if let importSummaryMessage {
                Text(importSummaryMessage)
            }
        }
    }

    private func loadInvoices() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let dateFilter = InvoiceListDateFilter.listQuery(
                period: entryPeriodFilter,
                intervalEnabled: filterDateIntervalEnabled,
                intervalFrom: filterDateFrom,
                intervalTo: filterDateTo
            )
            let loaded: [SupplierInvoiceRow]
            var nirInvoiceIds = Set<UUID>()
            var incompleteIds = Set<UUID>()
            if let companyId = companyManager.currentCompany?.id {
                async let loadedTask = SupplierService.fetchInvoices(dateFilter: dateFilter)
                async let nirTask = SupplierNIRService.fetchInvoiceIdsWithNIR(companyId: companyId)
                async let incompleteTask = SupplierNIRService.fetchIncompleteReceptionInvoiceIds(companyId: companyId)
                loaded = try await loadedTask
                nirInvoiceIds = try await nirTask
                incompleteIds = try await incompleteTask
            } else {
                loaded = try await SupplierService.fetchInvoices(dateFilter: dateFilter)
            }
            await MainActor.run {
                invoices = loaded
                invoiceIdsWithNIR = nirInvoiceIds
                incompleteReceptionInvoiceIds = incompleteIds
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func resetFilters() {
        entryPeriodFilter = .today
        statusFilter = nil
        filterInvoiceNumber = ""
        filterSupplierName = ""
        filterDateIntervalEnabled = false
        filterDateFrom = Calendar.current.startOfDay(for: Date())
        filterDateTo = Calendar.current.startOfDay(for: Date())
        pruneInvoiceSelection()
    }

    private func enterSelectionMode() {
        isSelectionMode = true
        selectedInvoiceIds.removeAll()
        errorMessage = nil
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedInvoiceIds.removeAll()
        showBulkDeleteConfirm = false
    }

    private func toggleInvoiceSelection(_ id: UUID) {
        if selectedInvoiceIds.contains(id) {
            selectedInvoiceIds.remove(id)
        } else {
            selectedInvoiceIds.insert(id)
        }
    }

    private func toggleSelectAllDisplayedInvoices() {
        if allDisplayedInvoicesSelected {
            selectedInvoiceIds.subtract(displayedInvoiceIds)
        } else {
            selectedInvoiceIds.formUnion(displayedInvoiceIds)
        }
    }

    private func pruneInvoiceSelection() {
        selectedInvoiceIds.formIntersection(displayedInvoiceIds)
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first, displayedInvoices.indices.contains(index) else { return }
        requestDelete(displayedInvoices[index])
    }

    private func requestDelete(_ invoice: SupplierInvoiceRow) {
        Task { @MainActor in
            do {
                if try await SupplierService.invoiceHasPayments(invoiceId: invoice.id) {
                    errorMessage = L10n.tr("invoices.delete_blocked_payments")
                    return
                }
                invoiceToDelete = invoice
                showDeleteConfirm = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteInvoice(_ invoice: SupplierInvoiceRow) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            invoiceToDelete = nil
            showDeleteConfirm = false
        }
        do {
            try await SupplierService.deleteInvoice(id: invoice.id)
            await loadInvoices()
            await Task.yield()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedInvoices() async {
        let ids = selectedInvoiceIds
        guard !ids.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            showBulkDeleteConfirm = false
        }

        var deletedCount = 0
        var failedCount = 0

        for id in ids {
            do {
                try await SupplierService.deleteInvoice(id: id)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }

        exitSelectionMode()
        await loadInvoices()
        await Task.yield()
        await onChanged()

        if failedCount > 0 {
            errorMessage = L10n.tr("invoices.bulk_delete_summary", deletedCount, failedCount)
        }
    }

    private func prepareImportDirectory(_ directoryURL: URL) async {
        guard companyManager.currentCompany != nil else {
            errorMessage = L10n.tr("module.suppliers.no_company_selected")
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let xmlFiles = try EFacturaImportFileCollector.collectXMLFiles(in: directoryURL)
            guard !xmlFiles.isEmpty else {
                throw EFacturaImportCollectorError.noXMLFiles
            }
            await prepareImportFiles(xmlFiles)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func prepareImportFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        guard let company = companyManager.currentCompany else {
            errorMessage = L10n.tr("module.suppliers.no_company_selected")
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            async let dataTask = InvoiceReceptionSupport.loadOptionsData(companyId: company.id)
            async let previewTask = SupplierInvoiceEFacturaImport.previewFiles(urls: urls, company: company)
            let data = try await dataTask
            let previewItems = await previewTask
            await MainActor.run {
                importWorkLocations = data.workLocations
                importWarehouses = data.warehouses
                importReceptionRequirements = InvoiceReceptionSupport.requirements(
                    workLocations: data.workLocations,
                    warehouses: data.warehouses
                )
                importReceptionOptions = InvoiceReceptionSupport.defaultOptions(
                    workLocations: data.workLocations,
                    warehouses: data.warehouses
                )
                importPreviewItems = previewItems
                showImportPreviewSheet = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func importEFacturaFiles(_ items: [EFacturaImportPreviewItem], options: InvoiceReceptionOptions) async {
        guard let company = companyManager.currentCompany else {
            await MainActor.run {
                errorMessage = L10n.tr("module.suppliers.no_company_selected")
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let result = await SupplierInvoiceEFacturaImport.importFiles(
            items: items,
            company: company,
            receptionOptions: options,
            receptionRequirements: importReceptionRequirements,
            createdBy: session.currentProfile?.id
        )

        if result.importedCount > 0 {
            await loadInvoices()
        }

        let summary = buildImportSummary(result)
        let hasPendingNIR = !result.pendingNIRInvoiceIds.isEmpty
        let hasPendingCreditOffset = !result.pendingCreditNoteOffsetInvoiceIds.isEmpty

        if hasPendingNIR {
            pendingImportSummaryMessage = summary
            pendingCreditNoteOffsetInvoiceIds = result.pendingCreditNoteOffsetInvoiceIds
            await prepareNIREditorQueue(
                company: company,
                invoiceIds: result.pendingNIRInvoiceIds,
                options: options
            )
            await MainActor.run {
                isLoading = false
                if !showNIREditorQueue, !showCreditNoteOffsetQueue, let pendingImportSummaryMessage {
                    importSummaryMessage = pendingImportSummaryMessage
                    showImportSummary = true
                    self.pendingImportSummaryMessage = nil
                }
            }
        } else if hasPendingCreditOffset {
            pendingImportSummaryMessage = summary
            await prepareCreditNoteOffsetQueue(invoiceIds: result.pendingCreditNoteOffsetInvoiceIds)
            await MainActor.run {
                isLoading = false
                if !showCreditNoteOffsetQueue, let pendingImportSummaryMessage {
                    importSummaryMessage = pendingImportSummaryMessage
                    showImportSummary = true
                    self.pendingImportSummaryMessage = nil
                }
            }
        } else {
            await MainActor.run {
                importSummaryMessage = summary
                showImportSummary = true
                isLoading = false
            }
            if result.importedCount > 0 {
                await Task.yield()
                await onChanged()
            }
        }
    }

    private func prepareNIREditorQueue(
        company: Company,
        invoiceIds: [UUID],
        options: InvoiceReceptionOptions
    ) async {
        var contexts: [NIREditorContext] = []
        do {
            let invoices = try await SupplierService.fetchInvoices(ids: invoiceIds)
            let suppliers = try await SupplierService.fetchSuppliers(ids: invoices.map(\.supplierId))
            let suppliersById = Dictionary(uniqueKeysWithValues: suppliers.map { ($0.id, $0) })
            let names = InvoiceReceptionSupport.receptionNames(
                workLocationId: options.workLocationId,
                warehouseId: options.warehouseId,
                workLocations: importWorkLocations,
                warehouses: importWarehouses
            )
            for invoice in invoices {
                guard let supplier = suppliersById[invoice.supplierId] else { continue }
                contexts.append(
                    NIREditorContext(
                        invoice: invoice,
                        supplier: supplier,
                        workLocationId: options.workLocationId,
                        warehouseId: options.warehouseId,
                        workLocationName: names.workLocationName,
                        warehouseName: names.warehouseName
                    )
                )
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            return
        }

        await MainActor.run {
            if !contexts.isEmpty {
                nirEditorContexts = contexts
                showNIREditorQueue = true
            }
        }
    }

    private func openReception(for row: SupplierInvoiceRow) async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        do {
            let invoice = try await SupplierService.fetchInvoice(id: row.id)
            let suppliers = try await SupplierService.fetchSuppliers(ids: [invoice.supplierId])
            guard let supplier = suppliers.first else {
                await MainActor.run {
                    errorMessage = L10n.tr("invoices.reception_supplier_missing")
                }
                return
            }
            var workLocations = importWorkLocations
            var warehouses = importWarehouses
            if workLocations.isEmpty || warehouses.isEmpty {
                let receptionData = try await InvoiceReceptionSupport.loadOptionsData(companyId: companyId)
                workLocations = receptionData.workLocations
                warehouses = receptionData.warehouses
                await MainActor.run {
                    importWorkLocations = workLocations
                    importWarehouses = warehouses
                    importReceptionRequirements = InvoiceReceptionSupport.requirements(
                        workLocations: workLocations,
                        warehouses: warehouses
                    )
                }
            }
            let defaults = InvoiceReceptionSupport.defaultOptions(
                workLocations: workLocations,
                warehouses: warehouses
            )
            if invoice.receptionClosed {
                try await SupplierService.setReceptionClosed(invoiceId: invoice.id, closed: false)
            }
            let context = NIREditorContext(
                invoice: invoice,
                supplier: supplier,
                workLocationId: invoice.workLocationId ?? defaults.workLocationId,
                warehouseId: nil,
                workLocationName: nil,
                warehouseName: nil
            )
            await MainActor.run {
                nirEditorContexts = [context]
                showNIREditorQueue = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func closeReception(_ row: SupplierInvoiceRow) async {
        do {
            try await SupplierService.setReceptionClosed(invoiceId: row.id, closed: true)
            await loadInvoices()
            await onChanged()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
        await MainActor.run {
            invoiceToCloseReception = nil
        }
    }

    private func prepareCreditNoteOffsetQueue(invoiceIds: [UUID]) async {
        var contexts: [CreditNoteOffsetContext] = []
        do {
            let invoices = try await SupplierService.fetchInvoices(ids: invoiceIds)
            let suppliers = try await SupplierService.fetchSuppliers(ids: invoices.map(\.supplierId))
            let suppliersById = Dictionary(uniqueKeysWithValues: suppliers.map { ($0.id, $0) })
            for invoice in invoices where invoice.isCreditNote && invoice.availableCreditAmount > 0 {
                let supplierName = suppliersById[invoice.supplierId]?.denumire ?? "—"
                contexts.append(
                    CreditNoteOffsetContext(
                        invoice: invoice,
                        supplierName: supplierName
                    )
                )
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            return
        }

        await MainActor.run {
            if !contexts.isEmpty {
                creditNoteOffsetContexts = contexts
                showCreditNoteOffsetQueue = true
            }
        }
    }

    private func buildImportSummary(_ result: EFacturaImportResult) -> String {
        var lines: [String] = []
        lines.append(L10n.tr("invoices.import_summary_imported", result.importedCount))
        if result.linesImportedCount > 0 {
            lines.append(L10n.tr("invoices.import_summary_lines", result.linesImportedCount))
        }
        if result.productsCreatedCount > 0 {
            lines.append(L10n.tr("invoices.import_summary_products_created", result.productsCreatedCount))
        }
        if !result.pendingCreditNoteOffsetInvoiceIds.isEmpty {
            lines.append(
                L10n.tr(
                    "invoices.import_summary_pending_credit_offsets",
                    result.pendingCreditNoteOffsetInvoiceIds.count
                )
            )
        }
        if !result.pendingNIRInvoiceIds.isEmpty {
            lines.append(L10n.tr("invoices.import_summary_pending_nirs", result.pendingNIRInvoiceIds.count))
        }
        if !result.skippedDuplicates.isEmpty {
            lines.append(L10n.tr("invoices.import_summary_skipped", result.skippedDuplicates.count))
            lines.append(contentsOf: result.skippedDuplicates.prefix(5))
            if result.skippedDuplicates.count > 5 {
                lines.append(L10n.tr("invoices.import_summary_more", result.skippedDuplicates.count - 5))
            }
        }
        if !result.failures.isEmpty {
            lines.append(L10n.tr("invoices.import_summary_failed", result.failures.count))
            for failure in result.failures.prefix(5) {
                lines.append(L10n.tr("invoices.import_summary_failure_line", failure.fileName, failure.message))
            }
            if result.failures.count > 5 {
                lines.append(L10n.tr("invoices.import_summary_more", result.failures.count - 5))
            }
        }
        return lines.joined(separator: "\n")
    }
}

private struct InvoiceRowView: View {
    let invoice: SupplierInvoiceRow
    let receptionStatus: InvoiceReceptionListStatus
    let canEditReception: Bool
    let canDelete: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    let onEdit: () -> Void
    let onAddReception: () -> Void
    let onCloseReception: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelectionMode {
                Button {
                    onToggleSelection?()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        BulkDeleteSelectionCheckbox(isSelected: isSelected)
                        rowContent
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onEdit) {
                    invoiceMainContent
                }
                .buttonStyle(.plain)

                receptionActionsColumn

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
            if !isSelectionMode {
                Button(action: onEdit) {
                    Label(L10n.tr("common.edit"), systemImage: "pencil")
                }
                if canEditReception, receptionStatus == .needsReception {
                    Button(action: onAddReception) {
                        Label(L10n.tr("invoices.add_reception"), systemImage: "shippingbox")
                    }
                    Button(action: onCloseReception) {
                        Label(L10n.tr("invoices.close_reception_action"), systemImage: "checkmark.seal")
                    }
                }
                if canDelete {
                    Button(action: onDelete) {
                        Label(L10n.tr("common.delete"), systemImage: "trash")
                    }
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

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            invoiceMainContent
            receptionStatusLabel
        }
        .padding(.vertical, 2)
    }

    private var invoiceMainContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(invoice.numarFactura)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                Spacer()
                Text(invoice.status.label)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor(invoice.status).opacity(0.15))
                    .foregroundColor(statusColor(invoice.status))
                    .clipShape(Capsule())
            }
            Text(invoice.supplierName)
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
            HStack {
                Text(SupplierFormatting.currency(invoice.sumaTotala, code: invoice.moneda))
                if invoice.restDePlata != 0 && invoice.status != .anulata {
                    Text(L10n.tr("invoices.rest", SupplierFormatting.currency(invoice.restDePlata, code: invoice.moneda)))
                        .foregroundColor(invoice.restDePlata > 0 ? .orange : .green)
                }
            }
            .font(.caption)
            HStack {
                Text(L10n.tr("invoices.invoice_date", SupplierFormatting.date(invoice.dataFactura)))
                if let scadenta = invoice.dataScadenta {
                    Text(L10n.tr("invoices.due_date", SupplierFormatting.date(scadenta)))
                        .foregroundColor(scadenta < Date() && invoice.status != .platita ? .red : .secondary)
                }
            }
            .font(.caption2)
            .foregroundColor(AppColors.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var receptionStatusLabel: some View {
        switch receptionStatus {
        case .notApplicable:
            EmptyView()
        case .closed:
            Text(L10n.tr("invoices.reception_closed_label"))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.green)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 100, alignment: .trailing)
        case .needsReception:
            if isSelectionMode || !canEditReception {
                Text(L10n.tr("invoices.reception_open_label"))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 100, alignment: .trailing)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var receptionActionsColumn: some View {
        if !isSelectionMode, canEditReception, receptionStatus == .needsReception {
            VStack(alignment: .trailing, spacing: 6) {
                Button(action: onAddReception) {
                    Text(L10n.tr("invoices.add_reception"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: onCloseReception) {
                    Text(L10n.tr("invoices.close_reception_action"))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(minWidth: 120, alignment: .trailing)
        } else if !isSelectionMode {
            receptionStatusLabel
        }
    }

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .neplatita: return .orange
        case .partial: return .blue
        case .platita: return .green
        case .anulata: return .gray
        }
    }
}

enum InvoiceFormMode: Identifiable {
    case create
    case edit(SupplierInvoiceRow)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let invoice): return invoice.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("invoices.create_title")
        case .edit: return L10n.tr("invoices.edit_title")
        }
    }
}

struct InvoiceFormView: View {
    let mode: InvoiceFormMode
    let access: ModuleAccessRights
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void

    private static let addNewSupplierSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var suppliers: [Supplier] = []
    @State private var selectedSupplierId: UUID?
    @State private var numarFactura = ""
    @State private var dataFactura = Date()
    @State private var hasScadenta = false
    @State private var dataScadenta = Date()
    @State private var sumaTotala = ""
    @State private var moneda = "RON"
    @State private var status: InvoiceStatus = .neplatita
    @State private var observatii = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastAutoScadenta: Date?
    @State private var showCreateSupplier = false
    @State private var invoiceLines: [EditableInvoiceLine] = []
    @State private var receptionOptions = InvoiceReceptionOptions()
    @State private var workLocations: [CompanyWorkLocation] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var nirEditorContext: NIREditorContext?
    @State private var existingNIRs: [SupplierNIR] = []
    @State private var invoiceReceptionIncomplete = false

    @State private var receptionRequirements = InvoiceReceptionRequirements(workLocations: [], warehouses: [])

    @State private var supplierAccountInvoices: [SupplierInvoice] = []
    @State private var selectedOffsetInvoiceIds: [UUID] = []
    @State private var existingCreditOffsets: [SupplierInvoiceCreditOffset] = []

    private var parsedTotalAmount: Decimal? {
        SupplierFormatting.parseAmount(
            sumaTotala,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        ).map { SupplierFormatting.roundAmount($0) }
    }

    private var isCreditNoteForm: Bool {
        guard let parsedTotalAmount else { return false }
        return parsedTotalAmount < 0
    }

    private var creditOffsetTargetInvoices: [SupplierInvoice] {
        let existingTargetIds = Set(existingCreditOffsets.map(\.targetInvoiceId))
        return CreditNoteOffsetAllocation.openTargetInvoices(
            supplierAccountInvoices,
            excludingCreditInvoiceId: currentCreditInvoiceForOffset?.id
        )
        .filter { !existingTargetIds.contains($0.id) }
    }

    private var isCreditNoteAllocationLocked: Bool {
        CreditNoteOffsetAllocation.isLocked(
            availableCredit: creditAmountForOffset,
            existingOffsetCount: existingCreditOffsets.count
        )
    }

    private var creditAmountForOffset: Decimal {
        if let invoice = currentCreditInvoiceForOffset {
            return invoice.availableCreditAmount
        }
        return abs(parsedTotalAmount ?? 0)
    }

    private var currentCreditInvoiceForOffset: SupplierInvoiceRow? {
        guard case .edit(let invoiceRow) = mode, invoiceRow.isCreditNote else { return nil }
        return invoiceRow
    }

    private var creditOffsetPlan: PaymentAllocationPlan {
        CreditNoteOffsetAllocation.plan(
            invoices: supplierAccountInvoices,
            selectedInvoiceIds: selectedOffsetInvoiceIds,
            creditAmount: creditAmountForOffset
        )
    }

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("invoices.section_supplier"))) {
                    supplierPickerContent
                }

                Section(header: Text(L10n.tr("invoices.section_data"))) {
                    FormTextField(
                        title: L10n.tr("invoices.field_invoice_number"),
                        text: numarFacturaBinding,
                        isRequired: true,
                        autocapitalization: .characters
                    )
                    DateInputField(title: L10n.tr("invoices.field_invoice_date"), date: $dataFactura, isRequired: true)
                    if selectedSupplier != nil {
                        DateInputField(title: L10n.tr("invoices.field_due_date"), date: $dataScadenta)
                        Text(
                            selectedSupplierPaymentTermDays > 0
                                ? L10n.tr("invoices.due_auto_hint", selectedSupplierPaymentTermDays)
                                : L10n.tr("invoices.due_auto_hint_zero")
                        )
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    } else {
                        Toggle(L10n.tr("invoices.has_due_date"), isOn: $hasScadenta)
                        if hasScadenta {
                            DateInputField(title: L10n.tr("invoices.field_due_date"), date: $dataScadenta)
                        }
                    }
                    FormTextField(
                        title: L10n.tr("invoices.field_total_amount"),
                        text: sumaTotalaBinding,
                        isRequired: true,
                        keyboardType: .decimalPad,
                        placeholder: SupplierFormatting.amountPlaceholder
                    )
                    Text(L10n.tr("invoices.total_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text(SupplierFormatting.invoiceAmountHint)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    FormTextField(title: L10n.tr("invoices.field_currency"), text: $moneda)
                }

                if case .edit = mode {
                    Section(header: Text(L10n.tr("invoices.section_status"))) {
                        Picker(L10n.tr("invoices.field_status"), selection: $status) {
                            ForEach(InvoiceStatus.allCases) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        Text(L10n.tr("invoices.status_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }

                    InvoiceLinesEditorView(
                        lines: $invoiceLines,
                        currency: moneda.trimmingCharacters(in: .whitespaces).isEmpty ? "RON" : moneda,
                        canEdit: access.canEdit
                    )

                    nirEditSection
                } else {
                    InvoiceReceptionSection(
                        options: $receptionOptions,
                        requirements: receptionRequirements,
                        workLocations: workLocations,
                        warehouses: warehouses,
                        showCreateNIRToggle: !isCreditNoteForm
                    )
                }

                if isCreditNoteForm, selectedSupplier != nil {
                    if isCreditNoteAllocationLocked {
                        CreditNoteOffsetLockedSection(
                            creditInvoiceNumber: numarFactura.isEmpty ? "—" : numarFactura,
                            currency: moneda.trimmingCharacters(in: .whitespaces).isEmpty ? "RON" : moneda,
                            lines: lockedCreditOffsetLines
                        )
                    } else {
                        CreditNoteOffsetSelectionSection(
                            creditInvoiceNumber: numarFactura.isEmpty ? "—" : numarFactura,
                            creditAmount: creditAmountForOffset,
                            currency: moneda.trimmingCharacters(in: .whitespaces).isEmpty ? "RON" : moneda,
                            targetInvoices: creditOffsetTargetInvoices,
                            selectedInvoiceIds: $selectedOffsetInvoiceIds,
                            existingLines: existingCreditOffsetLines
                        )
                    }
                }

                Section(header: Text(L10n.tr("invoices.section_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("common.field_notes"), text: $observatii)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(!canSave || !isFormValid || isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .fullScreenCover(isPresented: $showCreateSupplier) {
                SupplierFormView(mode: .create, access: access, onSaved: {}, onCreated: { supplier in
                    await loadSuppliers(selecting: supplier.id)
                    recalculateScadenta(force: true)
                })
            }
            .appTask {
                await loadSuppliers()
                await loadReceptionData()
                populateFields()
                await loadCreditOffsetData()
                if case .edit = mode {
                    await loadInvoiceLines()
                    await loadExistingNIR()
                    await loadCreditOffsetData()
                }
                recalculateScadenta(force: true)
            }
            .onChangeCompat(of: selectedSupplierId) { previous, newValue in
                guard newValue != Self.addNewSupplierSentinel else {
                    selectedSupplierId = previous
                    showCreateSupplier = true
                    return
                }
                lastAutoScadenta = nil
                recalculateScadenta(force: true)
                Task { await loadCreditOffsetData() }
            }
            .onChange(of: dataFactura) { _ in
                recalculateScadenta(force: false)
            }
            .onChange(of: sumaTotala) { _ in
                if !isCreditNoteForm {
                    selectedOffsetInvoiceIds = []
                }
            }
            .onChange(of: dataScadenta) { newValue in
                if let lastAutoScadenta, Calendar.current.isDate(newValue, inSameDayAs: lastAutoScadenta) {
                    return
                }
                if lastAutoScadenta != nil {
                    lastAutoScadenta = nil
                }
            }
            .fullScreenCover(item: $nirEditorContext) { context in
                if let company = companyManager.currentCompany {
                    NIREditorView(
                        context: context,
                        company: company,
                        createdBy: session.currentProfile?.id,
                        onSaved: {
                            await loadExistingNIR()
                            await onSaved()
                        },
                        onFinish: { _ in
                            nirEditorContext = nil
                            if case .create = mode, dismissAfterSave {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var nirEditSection: some View {
        Section(header: Text(L10n.tr("nir.editor_section_title"))) {
            if invoiceReceptionIncomplete {
                Label(L10n.tr("invoices.partial_nir_hint"), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if existingNIRs.isEmpty {
                Text(L10n.tr("nir.editor_not_created_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            } else {
                ForEach(existingNIRs) { nir in
                    Button {
                        openNIREditor(existingNIR: nir)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nir.numarNir)
                                .font(.headline)
                            Text(nirWarehouseLabel(nir))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
            }
            Button {
                openNIREditor(existingNIR: nil)
            } label: {
                Label(
                    existingNIRs.isEmpty
                        ? L10n.tr("nir.editor_create_action")
                        : L10n.tr("nir.editor_add_another"),
                    systemImage: "doc.badge.plus"
                )
            }
        }
    }

    private func nirWarehouseLabel(_ nir: SupplierNIR) -> String {
        let warehouse = warehouses.first { $0.id == nir.warehouseId }?.denumire
        let location = workLocations.first { $0.id == nir.workLocationId }?.denumire
        return [warehouse, location].compactMap { $0 }.joined(separator: " · ")
    }

    private func openNIREditor(existingNIR: SupplierNIR?) {
        guard case .edit(let invoiceRow) = mode,
              let supplier = selectedSupplier else { return }
        Task {
            do {
                let invoice = try await SupplierService.fetchInvoice(id: invoiceRow.id)
                let usedWarehouseIds = Set(existingNIRs.compactMap(\.warehouseId))
                let workLocationId = existingNIR?.workLocationId ?? invoice.workLocationId
                // NIR nou: nu forțăm gestiunea facturii / NIR-ului anterior — se alege alta (sau rest pe aceeași).
                let warehouseId: UUID?
                if let existingNIR {
                    warehouseId = existingNIR.warehouseId
                } else {
                    warehouseId = warehouses
                        .filter(\.isActive)
                        .first { warehouse in
                            (workLocationId == nil || warehouse.workLocationId == workLocationId)
                                && !usedWarehouseIds.contains(warehouse.id)
                        }?.id
                }
                let names = InvoiceReceptionSupport.receptionNames(
                    workLocationId: workLocationId,
                    warehouseId: warehouseId,
                    workLocations: workLocations,
                    warehouses: warehouses
                )
                await MainActor.run {
                    nirEditorContext = NIREditorContext(
                        invoice: invoice,
                        supplier: supplier,
                        workLocationId: workLocationId,
                        warehouseId: warehouseId,
                        workLocationName: names.workLocationName,
                        warehouseName: names.warehouseName,
                        existingNIR: existingNIR
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadExistingNIR() async {
        guard case .edit(let invoice) = mode else { return }
        do {
            let nirs = try await SupplierNIRService.fetchNIRs(forInvoice: invoice.id)
            let received = try await SupplierNIRService.receivedInvoiceQuantities(
                invoiceId: invoice.id,
                excludingNirId: nil
            )
            let lines = try await SupplierService.fetchInvoiceLines(invoiceId: invoice.id)
            let incomplete = lines.contains { line in
                guard line.cantitate > 0, !NIRLineEligibility.isGarantieLine(line) else { return false }
                let got = received[line.id] ?? 0
                return got + NSDecimalNumber(string: "0.0001").decimalValue < line.cantitate
            }
            await MainActor.run {
                existingNIRs = nirs
                invoiceReceptionIncomplete = incomplete && !nirs.isEmpty
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var supplierPickerContent: some View {
        if case .create = mode, access.canCreate {
            Picker(L10n.tr("invoices.field_supplier_required"), selection: $selectedSupplierId) {
                Text(L10n.tr("invoices.add_new_supplier"))
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .tag(Optional(Self.addNewSupplierSentinel))
                ForEach(suppliers) { supplier in
                    Text(supplier.denumire).tag(Optional(supplier.id))
                }
            }
            if suppliers.isEmpty {
                Text(L10n.tr("invoices.no_suppliers"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        } else if suppliers.isEmpty {
            Text(L10n.tr("invoices.no_suppliers"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        } else {
            Picker(L10n.tr("invoices.field_supplier_required"), selection: $selectedSupplierId) {
                Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                ForEach(suppliers) { supplier in
                    Text(supplier.denumire).tag(Optional(supplier.id))
                }
            }
        }
    }

    private var sumaTotalaBinding: Binding<String> {
        Binding(
            get: { sumaTotala },
            set: {
                sumaTotala = SupplierFormatting.limitAmountInputFractionDigits(
                    $0,
                    maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
                )
            }
        )
    }

    private var numarFacturaBinding: Binding<String> {
        Binding(
            get: { numarFactura },
            set: { numarFactura = $0.uppercased() }
        )
    }

    private var selectedSupplier: Supplier? {
        guard let selectedSupplierId, selectedSupplierId != Self.addNewSupplierSentinel else { return nil }
        return suppliers.first { $0.id == selectedSupplierId }
    }

    private var selectedSupplierPaymentTermDays: Int {
        selectedSupplier?.nrZileScadenta ?? 0
    }

    private func recalculateScadenta(force: Bool) {
        guard let calculated = SupplierFormatting.dueDate(
            from: dataFactura,
            paymentTermDays: selectedSupplierPaymentTermDays
        ) else { return }

        let matchesLastAuto = lastAutoScadenta.map {
            Calendar.current.isDate(dataScadenta, inSameDayAs: $0)
        } ?? false
        if force || lastAutoScadenta == nil || matchesLastAuto {
            dataScadenta = calculated
            lastAutoScadenta = calculated
            hasScadenta = true
        }
    }

    private var sumaTvaForSave: Decimal {
        if case .edit(let invoice) = mode {
            return invoice.sumaTva
        }
        return 0
    }

    private var effectiveScadenta: Date? {
        if selectedSupplier != nil {
            return dataScadenta
        }
        return hasScadenta ? dataScadenta : nil
    }

    private var isFormValid: Bool {
        let baseValid = selectedSupplier != nil
            && !numarFactura.trimmingCharacters(in: .whitespaces).isEmpty
            && SupplierFormatting.parseAmount(
                sumaTotala,
                maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
            ) != nil
        if case .create = mode {
            if isCreditNoteForm { return baseValid }
            return baseValid && receptionRequirements.isValid(receptionOptions)
        }
        return baseValid
    }

    private func loadReceptionData() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        do {
            let data = try await InvoiceReceptionSupport.loadOptionsData(companyId: companyId)
            await MainActor.run {
                workLocations = data.workLocations
                warehouses = data.warehouses
                receptionRequirements = InvoiceReceptionSupport.requirements(
                    workLocations: data.workLocations,
                    warehouses: data.warehouses
                )
                if case .create = mode {
                    receptionOptions = InvoiceReceptionSupport.defaultOptions(
                        workLocations: data.workLocations,
                        warehouses: data.warehouses
                    )
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadSuppliers(selecting supplierId: UUID? = nil) async {
        do {
            let loaded = try await SupplierService.fetchSuppliers(activeOnly: true)
            await MainActor.run {
                suppliers = loaded
                if let supplierId {
                    selectedSupplierId = supplierId
                } else if selectedSupplierId == nil || selectedSupplierId == Self.addNewSupplierSentinel {
                    selectedSupplierId = loaded.first?.id
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var existingCreditOffsetLines: [CreditNoteOffsetDisplayLine] {
        creditOffsetDisplayLines(from: existingCreditOffsets)
    }

    private var lockedCreditOffsetLines: [CreditNoteOffsetDisplayLine] {
        existingCreditOffsetLines
    }

    private func creditOffsetDisplayLines(
        from offsets: [SupplierInvoiceCreditOffset]
    ) -> [CreditNoteOffsetDisplayLine] {
        let invoicesById = Dictionary(uniqueKeysWithValues: supplierAccountInvoices.map { ($0.id, $0) })
        return offsets.map { offset in
            CreditNoteOffsetDisplayLine(
                id: offset.id,
                invoiceNumber: invoicesById[offset.targetInvoiceId]?.numarFactura ?? "—",
                amount: offset.amount
            )
        }
    }

    private func loadCreditOffsetData() async {
        guard let supplierId = selectedSupplierId,
              supplierId != Self.addNewSupplierSentinel else {
            await MainActor.run {
                supplierAccountInvoices = []
                selectedOffsetInvoiceIds = []
                existingCreditOffsets = []
            }
            return
        }

        do {
            let invoices = try await SupplierService.fetchInvoicesForAccount(supplierId: supplierId)
            var offsets: [SupplierInvoiceCreditOffset] = []
            if case .edit(let invoice) = mode, invoice.isCreditNote {
                offsets = try await SupplierService.fetchCreditOffsets(creditInvoiceId: invoice.id)
            }
            await MainActor.run {
                supplierAccountInvoices = invoices
                selectedOffsetInvoiceIds = []
                existingCreditOffsets = offsets
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadInvoiceLines() async {
        guard case .edit(let invoice) = mode else { return }
        do {
            let loaded = try await SupplierService.fetchInvoiceLines(invoiceId: invoice.id)
            await MainActor.run {
                invoiceLines = loaded.map(EditableInvoiceLine.init(from:))
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func populateFields() {
        guard case .edit(let invoice) = mode else { return }
        selectedSupplierId = invoice.supplierId
        numarFactura = invoice.numarFactura.uppercased()
        dataFactura = invoice.dataFactura
        if let scadenta = invoice.dataScadenta {
            hasScadenta = true
            dataScadenta = scadenta
            lastAutoScadenta = nil
        }
        sumaTotala = SupplierFormatting.amountString(invoice.sumaTotala)
        moneda = invoice.moneda
        status = invoice.status
        observatii = invoice.observatii ?? ""
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("suppliers.select_company_error")
            return
        }
        guard let supplierId = selectedSupplierId,
              supplierId != Self.addNewSupplierSentinel,
              let supplier = suppliers.first(where: { $0.id == supplierId }),
              let parsedTotal = SupplierFormatting.parseAmount(
                sumaTotala,
                maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
              ) else { return }
        let total = SupplierFormatting.roundAmount(parsedTotal)
        let tva = sumaTvaForSave
        let normalizedNumber = SupplierInvoiceDuplicateCheck.normalizeInvoiceNumber(numarFactura)
        let currency = moneda.trimmingCharacters(in: .whitespaces).isEmpty ? "RON" : moneda
        let excludingInvoiceId: UUID? = {
            if case .edit(let invoice) = mode { return invoice.id }
            return nil
        }()

        isLoading = true
        errorMessage = nil
        do {
            let existingInvoices = try await SupplierService.fetchInvoiceDuplicateIndex()
            if SupplierInvoiceDuplicateCheck.isDuplicate(
                supplier: supplier,
                number: numarFactura,
                issueDate: dataFactura,
                totalAmount: total,
                existingInvoices: existingInvoices,
                suppliers: suppliers,
                excludingInvoiceId: excludingInvoiceId
            ) {
                errorMessage = SupplierInvoiceDuplicateCheck.duplicateMessage(
                    supplierName: supplier.denumire,
                    number: normalizedNumber,
                    issueDate: dataFactura,
                    totalAmount: total,
                    currency: currency
                )
                isLoading = false
                return
            }

            switch mode {
            case .create:
                if !receptionRequirements.isValid(receptionOptions) {
                    errorMessage = L10n.tr("invoices.reception_required")
                    isLoading = false
                    return
                }
                let createdInvoice = try await SupplierService.createInvoice(
                    companyId: companyId,
                    supplierId: supplierId,
                    numarFactura: normalizedNumber,
                    dataFactura: dataFactura,
                    dataScadenta: effectiveScadenta,
                    sumaTotala: total,
                    sumaTva: tva,
                    moneda: currency,
                    status: .neplatita,
                    observatii: observatii,
                    workLocationId: receptionOptions.workLocationId,
                    warehouseId: receptionOptions.warehouseId,
                    createdBy: session.currentProfile?.id
                )
                if total < 0, !selectedOffsetInvoiceIds.isEmpty {
                    try await SupplierService.replaceCreditNoteOffsets(
                        companyId: companyId,
                        creditInvoice: createdInvoice,
                        plan: creditOffsetPlan
                    )
                }
                if receptionOptions.createNIR, total >= 0,
                   let supplier = selectedSupplier {
                    let names = InvoiceReceptionSupport.receptionNames(
                        workLocationId: receptionOptions.workLocationId,
                        warehouseId: receptionOptions.warehouseId,
                        workLocations: workLocations,
                        warehouses: warehouses
                    )
                    await onSaved()
                    isLoading = false
                    nirEditorContext = NIREditorContext(
                        invoice: createdInvoice,
                        supplier: supplier,
                        workLocationId: receptionOptions.workLocationId,
                        warehouseId: receptionOptions.warehouseId,
                        workLocationName: names.workLocationName,
                        warehouseName: names.warehouseName
                    )
                    return
                }
            case .edit(let invoice):
                let updatedInvoice = try await SupplierService.updateInvoice(
                    id: invoice.id,
                    supplierId: supplierId,
                    numarFactura: normalizedNumber,
                    dataFactura: dataFactura,
                    dataScadenta: effectiveScadenta,
                    sumaTotala: total,
                    sumaTva: tva,
                    moneda: currency,
                    status: status,
                    observatii: observatii
                )
                if total < 0 {
                    let latestInvoice = try await SupplierService.fetchInvoice(id: updatedInvoice.id)
                    if !CreditNoteOffsetAllocation.isLocked(
                        availableCredit: latestInvoice.availableCreditAmount,
                        existingOffsetCount: existingCreditOffsets.count
                    ) {
                        try await SupplierService.replaceCreditNoteOffsets(
                            companyId: companyId,
                            creditInvoice: latestInvoice,
                            plan: creditOffsetPlan
                        )
                    }
                }
                if access.canEdit {
                    let invalidLines = invoiceLines.filter { line in
                        let trimmed = line.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
                        return !trimmed.isEmpty && !line.isValid
                    }
                    if !invalidLines.isEmpty {
                        errorMessage = L10n.tr("invoices.lines_invalid")
                        isLoading = false
                        return
                    }
                    try await InvoiceLinesPersistence.saveLines(
                        companyId: companyId,
                        invoiceId: invoice.id,
                        lines: invoiceLines
                    )
                }
            }
            await onSaved()
            if dismissAfterSave {
                presentationMode.wrappedValue.dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
