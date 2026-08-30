import SwiftUI

private enum InvoiceEntryPeriodFilter: CaseIterable, Identifiable {
    case today
    case last5Days
    case thisMonth
    case all

    var id: Self { self }

    var label: String {
        switch self {
        case .today: return L10n.tr("invoices.period_today")
        case .last5Days: return L10n.tr("invoices.period_last_5_days")
        case .thisMonth: return L10n.tr("invoices.period_this_month")
        case .all: return L10n.tr("invoices.period_all")
        }
    }

    func includes(entryDate: Date, calendar: Calendar = .current) -> Bool {
        let entryDay = calendar.startOfDay(for: entryDate)
        let today = calendar.startOfDay(for: Date())

        switch self {
        case .today:
            return calendar.isDate(entryDay, inSameDayAs: today)
        case .last5Days:
            guard let start = calendar.date(byAdding: .day, value: -4, to: today) else { return false }
            return entryDay >= start && entryDay <= today
        case .thisMonth:
            return calendar.isDate(entryDay, equalTo: today, toGranularity: .month)
        case .all:
            return true
        }
    }
}

struct ClientInvoicesListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var invoices: [ClientInvoiceRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var invoiceToEdit: ClientInvoiceRow?
    @State private var invoiceToDelete: ClientInvoiceRow?
    @State private var showDeleteConfirm = false
    @State private var isSelectionMode = false
    @State private var selectedInvoiceIds = Set<UUID>()
    @State private var showBulkDeleteConfirm = false
    @State private var statusFilter: InvoiceStatus?
    @State private var entryPeriodFilter: InvoiceEntryPeriodFilter = .today
    @State private var filterInvoiceNumber = ""
    @State private var filterClientName = ""
    @State private var filterDateIntervalEnabled = false
    @State private var filterDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var filterDateTo = Calendar.current.startOfDay(for: Date())

    private var hasActiveFilters: Bool {
        entryPeriodFilter != .today
            || statusFilter != nil
            || !filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterClientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filterDateIntervalEnabled
    }

    private func entryDate(for invoice: ClientInvoiceRow) -> Date {
        invoice.createdAt ?? invoice.dataFactura
    }

    private var filteredInvoices: [ClientInvoiceRow] {
        invoices.filter { invoice in
            if !entryPeriodFilter.includes(entryDate: entryDate(for: invoice)) {
                return false
            }

            if let statusFilter, invoice.status != statusFilter { return false }

            let numberQuery = filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !numberQuery.isEmpty,
               !invoice.numarFactura.localizedCaseInsensitiveContains(numberQuery) {
                return false
            }

            let clientQuery = filterClientName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clientQuery.isEmpty,
               !invoice.clientName.localizedCaseInsensitiveContains(clientQuery) {
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

    private var displayedInvoices: [ClientInvoiceRow] {
        guard entryPeriodFilter != .all else { return filteredInvoices }
        return filteredInvoices.sorted { lhs, rhs in
            entryDate(for: lhs) > entryDate(for: rhs)
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
                        ForEach(InvoiceEntryPeriodFilter.allCases) { period in
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

                TextField(L10n.tr("invoices.filter_client_name"), text: $filterClientName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Toggle(L10n.tr("invoices.filter_date_interval"), isOn: $filterDateIntervalEnabled)
                    .font(.subheadline)

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
                        ForEach(displayedInvoices) { invoice in
                            ClientInvoiceRowView(
                                invoice: invoice,
                                canDelete: access.canDelete,
                                isSelectionMode: isSelectionMode && access.canDelete,
                                isSelected: selectedInvoiceIds.contains(invoice.id),
                                onToggleSelection: { toggleInvoiceSelection(invoice.id) },
                                onEdit: {
                                    if access.canEdit { invoiceToEdit = invoice }
                                },
                                onDelete: { requestDelete(invoice) }
                            )
                        }
                        .onDelete(perform: access.canDelete && !isSelectionMode ? deleteItems : { _ in })
                    }
                    .appScrollBottomPadding()
                }
            }
        }
        .floatingBottomTrailing {
            if access.canCreate && !isSelectionMode {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
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
        .onChange(of: displayedInvoices.map(\.id)) { _ in
            pruneInvoiceSelection()
        }
        .fullScreenCover(isPresented: $showCreate) {
            ClientInvoiceFormView(mode: .create, access: access) {
                await loadInvoices()
                await onChanged()
            }
        }
        .fullScreenCover(item: $invoiceToEdit) { invoice in
            ClientInvoiceFormView(mode: .edit(invoice), access: access) {
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
            Text(L10n.tr("invoices.client_delete_confirm", invoice.numarFactura))
        }
        .alert(L10n.tr("invoices.bulk_delete_title"), isPresented: $showBulkDeleteConfirm) {
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { @MainActor in
                    await deleteSelectedInvoices()
                }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("invoices.client_bulk_delete_confirm", selectedInvoiceIds.count))
        }
    }

    private func loadInvoices() async {
        isLoading = true
        errorMessage = nil
        do {
            invoices = try await ClientService.fetchInvoices()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resetFilters() {
        entryPeriodFilter = .today
        statusFilter = nil
        filterInvoiceNumber = ""
        filterClientName = ""
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

    private func requestDelete(_ invoice: ClientInvoiceRow) {
        Task { @MainActor in
            do {
                if try await ClientService.invoiceHasPayments(invoiceId: invoice.id) {
                    errorMessage = L10n.tr("invoices.client_delete_blocked_collections")
                    return
                }
                invoiceToDelete = invoice
                showDeleteConfirm = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteInvoice(_ invoice: ClientInvoiceRow) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            invoiceToDelete = nil
            showDeleteConfirm = false
        }
        do {
            try await ClientService.deleteInvoice(id: invoice.id)
            await loadInvoices()
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
                try await ClientService.deleteInvoice(id: id)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }

        exitSelectionMode()
        await loadInvoices()
        await onChanged()

        if failedCount > 0 {
            errorMessage = L10n.tr("invoices.bulk_delete_summary", deletedCount, failedCount)
        }
    }
}

private struct ClientInvoiceRowView: View {
    let invoice: ClientInvoiceRow
    let canDelete: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    let onEdit: () -> Void
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
                    rowContent
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
            if !isSelectionMode {
                Button(action: onEdit) {
                    Label(L10n.tr("common.edit"), systemImage: "pencil")
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
            Text(invoice.clientName)
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
        .padding(.vertical, 2)
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

enum ClientInvoiceFormMode: Identifiable {
    case create
    case edit(ClientInvoiceRow)

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

struct ClientInvoiceFormView: View {
    let mode: ClientInvoiceFormMode
    let access: ModuleAccessRights
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void

    private static let addNewClientSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var clients: [Client] = []
    @State private var selectedClientId: UUID?
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
    @State private var showCreateClient = false

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("clients.section_client"))) {
                    clientPickerContent
                }

                Section(header: Text(L10n.tr("invoices.section_data"))) {
                    FormTextField(
                        title: L10n.tr("invoices.field_invoice_number"),
                        text: numarFacturaBinding,
                        isRequired: true,
                        autocapitalization: .characters
                    )
                    DateInputField(title: L10n.tr("invoices.field_invoice_date"), date: $dataFactura, isRequired: true)
                    if selectedClient != nil {
                        DateInputField(title: L10n.tr("invoices.field_due_date"), date: $dataScadenta)
                        Text(
                            selectedClientPaymentTermDays > 0
                                ? L10n.tr("invoices.due_auto_hint", selectedClientPaymentTermDays)
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
            .fullScreenCover(isPresented: $showCreateClient) {
                ClientFormView(mode: .create, access: access, onSaved: {}, onCreated: { client in
                    await loadClients(selecting: client.id)
                    recalculateScadenta(force: true)
                })
            }
            .appTask {
                await loadClients()
                populateFields()
                recalculateScadenta(force: true)
            }
            .onChangeCompat(of: selectedClientId) { previous, newValue in
                guard newValue != Self.addNewClientSentinel else {
                    selectedClientId = previous
                    showCreateClient = true
                    return
                }
                lastAutoScadenta = nil
                recalculateScadenta(force: true)
            }
            .onChange(of: dataFactura) { _ in
                recalculateScadenta(force: false)
            }
            .onChange(of: dataScadenta) { newValue in
                if let lastAutoScadenta, Calendar.current.isDate(newValue, inSameDayAs: lastAutoScadenta) {
                    return
                }
                if lastAutoScadenta != nil {
                    lastAutoScadenta = nil
                }
            }
        }
    }

    @ViewBuilder
    private var clientPickerContent: some View {
        if case .create = mode, access.canCreate {
            Picker(L10n.tr("clients.field_client_required"), selection: $selectedClientId) {
                Text(L10n.tr("clients.add_new_client"))
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .tag(Optional(Self.addNewClientSentinel))
                ForEach(clients) { client in
                    Text(client.denumire).tag(Optional(client.id))
                }
            }
            if clients.isEmpty {
                Text(L10n.tr("invoices.no_clients"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        } else if clients.isEmpty {
            Text(L10n.tr("invoices.no_clients"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        } else {
            Picker(L10n.tr("clients.field_client_required"), selection: $selectedClientId) {
                Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                ForEach(clients) { client in
                    Text(client.denumire).tag(Optional(client.id))
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

    private var selectedClient: Client? {
        guard let selectedClientId, selectedClientId != Self.addNewClientSentinel else { return nil }
        return clients.first { $0.id == selectedClientId }
    }

    private var selectedClientPaymentTermDays: Int {
        selectedClient?.nrZileScadenta ?? 0
    }

    private func recalculateScadenta(force: Bool) {
        guard let calculated = SupplierFormatting.dueDate(
            from: dataFactura,
            paymentTermDays: selectedClientPaymentTermDays
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
        if selectedClient != nil {
            return dataScadenta
        }
        return hasScadenta ? dataScadenta : nil
    }

    private var isFormValid: Bool {
        selectedClient != nil
            && !numarFactura.trimmingCharacters(in: .whitespaces).isEmpty
            && SupplierFormatting.parseAmount(
                sumaTotala,
                maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
            ) != nil
    }

    private func loadClients(selecting clientId: UUID? = nil) async {
        do {
            let loaded = try await ClientService.fetchClients(activeOnly: true)
            await MainActor.run {
                clients = loaded
                if let clientId {
                    selectedClientId = clientId
                } else if selectedClientId == nil || selectedClientId == Self.addNewClientSentinel {
                    selectedClientId = loaded.first?.id
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func populateFields() {
        guard case .edit(let invoice) = mode else { return }
        selectedClientId = invoice.clientId
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
            errorMessage = L10n.tr("clients.select_company_error")
            return
        }
        guard let clientId = selectedClientId,
              clientId != Self.addNewClientSentinel,
              let client = clients.first(where: { $0.id == clientId }),
              let parsedTotal = SupplierFormatting.parseAmount(
                sumaTotala,
                maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
              ) else { return }
        let total = SupplierFormatting.roundAmount(parsedTotal)
        let tva = sumaTvaForSave
        let normalizedNumber = ClientInvoiceDuplicateCheck.normalizeInvoiceNumber(numarFactura)
        let currency = moneda.trimmingCharacters(in: .whitespaces).isEmpty ? "RON" : moneda
        let excludingInvoiceId: UUID? = {
            if case .edit(let invoice) = mode { return invoice.id }
            return nil
        }()

        isLoading = true
        errorMessage = nil
        do {
            let existingInvoices = try await ClientService.fetchInvoices()
            if ClientInvoiceDuplicateCheck.isDuplicate(
                client: client,
                number: numarFactura,
                issueDate: dataFactura,
                totalAmount: total,
                existingInvoices: existingInvoices,
                clients: clients,
                excludingInvoiceId: excludingInvoiceId
            ) {
                errorMessage = ClientInvoiceDuplicateCheck.duplicateMessage(
                    clientName: client.denumire,
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
                _ = try await ClientService.createInvoice(
                    companyId: companyId,
                    clientId: clientId,
                    numarFactura: normalizedNumber,
                    dataFactura: dataFactura,
                    dataScadenta: effectiveScadenta,
                    sumaTotala: total,
                    sumaTva: tva,
                    moneda: currency,
                    status: .neplatita,
                    observatii: observatii,
                    createdBy: session.currentProfile?.id
                )
            case .edit(let invoice):
                _ = try await ClientService.updateInvoice(
                    id: invoice.id,
                    clientId: clientId,
                    numarFactura: normalizedNumber,
                    dataFactura: dataFactura,
                    dataScadenta: effectiveScadenta,
                    sumaTotala: total,
                    sumaTva: tva,
                    moneda: currency,
                    status: status,
                    observatii: observatii
                )
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
