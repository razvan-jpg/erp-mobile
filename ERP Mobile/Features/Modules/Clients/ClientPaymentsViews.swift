import SwiftUI

struct ClientPaymentsListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var payments: [ClientPaymentRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var paymentToEdit: ClientPaymentRow?
    @State private var paymentToDelete: ClientPaymentRow?
    @State private var showDeleteConfirm = false
    @State private var filterReferenceNumber = ""
    @State private var filterInvoiceNumber = ""
    @State private var filterClientName = ""
    @State private var filterDateIntervalEnabled = false
    @State private var filterDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var filterDateTo = Calendar.current.startOfDay(for: Date())

    private var hasActiveFilters: Bool {
        !filterReferenceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterClientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filterDateIntervalEnabled
    }

    private var filteredPayments: [ClientPaymentRow] {
        payments.filter { payment in
            let referenceQuery = filterReferenceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !referenceQuery.isEmpty {
                let matchesReference = payment.referinta?
                    .localizedCaseInsensitiveContains(referenceQuery) ?? false
                if !matchesReference { return false }
            }

            let invoiceQuery = filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !invoiceQuery.isEmpty {
                let matchesLinkedInvoice = payment.invoiceNumber?
                    .localizedCaseInsensitiveContains(invoiceQuery) ?? false
                let matchesReferenceInvoice = payment.referinta?
                    .localizedCaseInsensitiveContains(invoiceQuery) ?? false
                if !matchesLinkedInvoice && !matchesReferenceInvoice { return false }
            }

            let clientQuery = filterClientName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clientQuery.isEmpty,
               !payment.clientName.localizedCaseInsensitiveContains(clientQuery) {
                return false
            }

            if filterDateIntervalEnabled {
                let paymentDay = Calendar.current.startOfDay(for: payment.dataPlata)
                let fromDay = Calendar.current.startOfDay(for: filterDateFrom)
                let toDay = Calendar.current.startOfDay(for: filterDateTo)
                let rangeStart = min(fromDay, toDay)
                let rangeEnd = max(fromDay, toDay)
                if paymentDay < rangeStart || paymentDay > rangeEnd { return false }
            }

            return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    if hasActiveFilters {
                        Button(L10n.tr("client_collections.filter_reset")) {
                            resetFilters()
                        }
                        .font(.subheadline)
                    }
                }

                TextField(L10n.tr("client_collections.filter_reference_number"), text: $filterReferenceNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField(L10n.tr("client_collections.filter_invoice_number"), text: $filterInvoiceNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField(L10n.tr("clients.filter_name"), text: $filterClientName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Toggle(L10n.tr("client_collections.filter_date_interval"), isOn: $filterDateIntervalEnabled)
                    .font(.subheadline)

                if filterDateIntervalEnabled {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("client_collections.filter_date_from"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            AppDatePicker(selection: $filterDateFrom)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("client_collections.filter_date_to"))
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
                if filteredPayments.isEmpty && !isLoading {
                    AppEmptyStateView(
                        hasActiveFilters ? L10n.tr("client_collections.empty_filtered") : L10n.tr("client_collections.empty"),
                        systemImage: "banknote",
                        description: Text(
                            hasActiveFilters
                                ? L10n.tr("client_collections.empty_filtered_hint")
                                : (access.canCreate
                                    ? L10n.tr("client_collections.empty_create")
                                    : L10n.tr("client_collections.empty_readonly"))
                        )
                    )
                } else {
                    List {
                        ForEach(filteredPayments) { payment in
                            ClientPaymentRowView(
                                payment: payment,
                                canDelete: access.canDelete,
                                onEdit: {
                                    if access.canEdit { paymentToEdit = payment }
                                },
                                onDelete: { requestDelete(payment) }
                            )
                        }
                        .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                    }
                    .appScrollBottomPadding()
                }
            }
        }
        .floatingBottomTrailing {
            if access.canCreate {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
                }
            }
        }
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
        .appTask { await loadPayments() }
        .appRefreshable { await loadPayments() }
        .fullScreenCover(isPresented: $showCreate) {
            ClientPaymentFormView(mode: .create, access: access) {
                await loadPayments()
                await onChanged()
            }
        }
        .fullScreenCover(item: $paymentToEdit) { payment in
            ClientPaymentFormView(mode: .edit(payment), access: access) {
                await loadPayments()
                await onChanged()
            }
        }
        .alert(L10n.tr("client_collections.delete_title"), isPresented: $showDeleteConfirm, presenting: paymentToDelete) { payment in
            Button(L10n.tr("common.delete")) {
                Task { await deletePayment(payment) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { _ in
            Text(L10n.tr("client_collections.delete_confirm"))
        }
    }

    private func loadPayments() async {
        isLoading = true
        errorMessage = nil
        do {
            payments = try await ClientService.fetchPayments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resetFilters() {
        filterReferenceNumber = ""
        filterInvoiceNumber = ""
        filterClientName = ""
        filterDateIntervalEnabled = false
        filterDateFrom = Calendar.current.startOfDay(for: Date())
        filterDateTo = Calendar.current.startOfDay(for: Date())
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        requestDelete(filteredPayments[index])
    }

    private func requestDelete(_ payment: ClientPaymentRow) {
        paymentToDelete = payment
        showDeleteConfirm = true
    }

    private func deletePayment(_ payment: ClientPaymentRow) async {
        isLoading = true
        do {
            try await ClientService.deletePayment(id: payment.id)
            await loadPayments()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ClientPaymentRowView: View {
    let payment: ClientPaymentRow
    let canDelete: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onEdit) {
                rowContent
            }
            .buttonStyle(.plain)

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.tr("common.delete"))
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label(L10n.tr("common.edit"), systemImage: "pencil")
            }
            if canDelete {
                Button(action: onDelete) {
                    Label(L10n.tr("common.delete"), systemImage: "trash")
                }
            }
        }
        .appSwipeActions(edge: .trailing, allowsFullSwipe: false) {
            if canDelete {
                Button(action: onDelete) {
                    Label(L10n.tr("common.delete"), systemImage: "trash")
                }
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(SupplierFormatting.currency(payment.suma))
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                Spacer()
                Text(payment.metodaPlata.label)
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
            }
            Text(payment.clientName)
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
            if let invoiceNumber = payment.invoiceNumber {
                Text(L10n.tr("client_collections.invoice_label", invoiceNumber))
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
            }
            Text(SupplierFormatting.date(payment.dataPlata))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            if let referinta = payment.referinta, !referinta.isEmpty {
                Text(L10n.tr("client_collections.ref_label", referinta))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ClientPaymentFormMode: Identifiable {
    case create
    case edit(ClientPaymentRow)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let payment): return payment.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("client_collections.create_title")
        case .edit: return L10n.tr("client_collections.edit_title")
        }
    }
}

struct ClientPaymentFormView: View {
    let mode: ClientPaymentFormMode
    let access: ModuleAccessRights
    var preselectedClientId: UUID? = nil
    var preselectedClientName: String? = nil
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var clients: [Client] = []
    @State private var invoices: [ClientInvoice] = []
    @State private var selectedClientId: UUID?
    @State private var selectedInvoiceIds: [UUID] = []
    @State private var linkToInvoice = false
    @State private var sumaManuallyEdited = false
    @State private var isApplyingAutoSuma = false
    @State private var dataPlata = Date()
    @State private var suma = ""
    @State private var metodaPlata: PaymentMethod = .transfer
    @State private var referinta = ""
    @State private var observatii = ""
    @State private var clientSoldRestant: Decimal = 0
    @State private var clientMoneda = "RON"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    private var openInvoices: [ClientInvoice] {
        ClientPaymentAllocation.sortedOpenInvoices(invoices)
    }

    private var openInvoiceRows: [PaymentFormOpenInvoiceRow] {
        openInvoices.map(\.paymentFormOpenInvoiceRow)
    }

    private var plannedPaymentPlan: ClientPaymentAllocationPlan {
        guard case .create = mode,
              let amount = SupplierFormatting.parseAmount(suma),
              amount > 0 else { return .empty }

        let rawPlan: ClientPaymentAllocationPlan
        if linkToInvoice, !selectedInvoiceIds.isEmpty {
            rawPlan = ClientPaymentAllocation.planForSelectedInvoices(
                invoices: invoices,
                selectedInvoiceIds: selectedInvoiceIds,
                totalAmount: amount
            )
        } else if !linkToInvoice {
            rawPlan = ClientPaymentAllocation.planByDueDate(invoices: invoices, totalAmount: amount)
        } else {
            return .empty
        }
        return ClientPaymentAllocation.sanitizedPlan(rawPlan)
    }

    private var allocationHint: String {
        linkToInvoice
            ? L10n.tr("client_collections.allocation_hint_multi")
            : L10n.tr("client_collections.allocation_hint_due_date")
    }

    private var isAdvancePayment: Bool {
        guard case .create = mode else { return false }
        return plannedPaymentPlan.isFullAdvance
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("clients.section_client"))) {
                    if let preselectedClientId,
                       case .create = mode {
                        let clientName = clients.first(where: { $0.id == preselectedClientId })?.denumire
                            ?? preselectedClientName
                            ?? "—"
                        AppLabeledContent(L10n.tr("clients.field_client_required"), value: clientName)
                    } else {
                        Picker(L10n.tr("clients.field_client_required"), selection: $selectedClientId) {
                            Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                            ForEach(clients) { client in
                                Text(client.denumire).tag(Optional(client.id))
                            }
                        }
                        .onChange(of: selectedClientId) { newValue in
                            selectedInvoiceIds = []
                            sumaManuallyEdited = false
                            if let newValue {
                                Task { await loadInvoices(for: newValue) }
                            } else {
                                invoices = []
                                clientSoldRestant = 0
                                clientMoneda = "RON"
                            }
                        }
                    }
                }

                Section(header: Text(L10n.tr("client_collections.section_invoice_optional"))) {
                    Toggle(L10n.tr("client_collections.link_invoice"), isOn: $linkToInvoice)
                        .onChange(of: linkToInvoice) { enabled in
                            if !enabled {
                                selectedInvoiceIds = []
                                sumaManuallyEdited = false
                            }
                            refreshAutoReference()
                        }
                    if linkToInvoice {
                        PaymentFormMultiInvoiceSelectionSection(
                            emptyMessageKey: "client_collections.no_open_invoices",
                            selectHintKey: "client_collections.select_invoices_hint",
                            selectedTotalKey: "client_collections.selected_invoices_total",
                            resetAmountKey: "client_collections.reset_amount_to_selected",
                            invoiceRestFormatKey: "client_collections.invoice_rest",
                            openInvoices: openInvoiceRows,
                            selectedInvoiceIds: $selectedInvoiceIds,
                            suma: $suma,
                            sumaManuallyEdited: $sumaManuallyEdited,
                            isApplyingAutoSuma: $isApplyingAutoSuma,
                            onSelectionChanged: refreshAutoReference
                        )
                        .onChange(of: selectedInvoiceIds) { _ in
                            refreshAutoReference()
                        }
                    }
                }

                if case .create = mode, isAdvancePayment {
                    Section(header: Text(L10n.tr("client_collections.section_advance"))) {
                        Text(L10n.tr("client_collections.advance_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        if let amount = SupplierFormatting.parseAmount(suma), amount > 0 {
                            Text(L10n.tr("client_collections.advance_line", SupplierFormatting.currency(amount)))
                                .font(.subheadline)
                        }
                    }
                } else if case .create = mode, plannedPaymentPlan.hasInvoiceAllocations {
                    Section(header: Text(L10n.tr("client_collections.section_allocation"))) {
                        Text(allocationHint)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        ForEach(plannedPaymentPlan.invoiceLines) { line in
                            allocationLineView(line)
                        }
                        if plannedPaymentPlan.hasAdvance {
                            Text(L10n.tr("client_collections.advance_line", SupplierFormatting.currency(plannedPaymentPlan.advanceAmount)))
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }

                Section(header: Text(L10n.tr("client_collections.section_details"))) {
                    DateInputField(title: L10n.tr("client_collections.field_collection_date"), date: $dataPlata, isRequired: true)
                    FormTextField(
                        title: L10n.tr("client_collections.field_amount"),
                        text: $suma,
                        isRequired: true,
                        keyboardType: .decimalPad,
                        placeholder: SupplierFormatting.amountPlaceholder
                    )
                    .onChange(of: suma) { _ in
                        if !isApplyingAutoSuma {
                            sumaManuallyEdited = true
                        }
                        refreshAutoReference()
                    }
                    Text(SupplierFormatting.amountHint)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Picker(L10n.tr("client_collections.field_method"), selection: $metodaPlata) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.label).tag(method)
                        }
                    }
                    FormTextField(title: L10n.tr("client_collections.field_reference"), text: referintaBinding)
                }

                Section(header: Text(L10n.tr("client_collections.section_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("common.field_notes"), text: $observatii)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }

                if case .edit = mode, access.canDelete {
                    Section {
                        Button(L10n.tr("common.delete")) {
                            showDeleteConfirm = true
                        }
                        .disabled(isLoading)
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
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text(L10n.tr("client_collections.delete_title")),
                    message: Text(L10n.tr("client_collections.delete_confirm")),
                    primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                        Task { await deleteCurrentPayment() }
                    },
                    secondaryButton: .cancel()
                )
            }
            .appTask {
                await loadClients()
                populateFields()
            }
        }
    }

    private var referintaBinding: Binding<String> {
        Binding(
            get: { referinta },
            set: { referinta = $0.uppercased() }
        )
    }

    private var isFormValid: Bool {
        guard selectedClientId != nil, SupplierFormatting.parseAmount(suma) != nil else { return false }
        if case .create = mode,
           linkToInvoice,
           selectedInvoiceIds.isEmpty,
           ClientPaymentAllocation.hasAllocatableOpenInvoices(invoices) {
            return false
        }
        return true
    }

    private func refreshAutoReference() {
        guard case .create = mode else { return }
        let plan = plannedPaymentPlan
        guard plan.hasInvoiceAllocations || plan.hasAdvance else { return }

        if !linkToInvoice, let paymentAmount = SupplierFormatting.parseAmount(suma), paymentAmount > 0 {
            let projected = ClientPaymentAllocation.projectedBalance(
                currentSoldRestant: clientSoldRestant,
                paymentAmount: paymentAmount
            )
            referinta = ClientPaymentAllocation.referenceString(
                from: plan,
                projectedBalance: projected,
                currencyCode: clientMoneda
            ).uppercased()
        } else {
            referinta = ClientPaymentAllocation.referenceString(from: plan).uppercased()
        }
    }

    private func loadClients() async {
        do {
            clients = try await ClientService.fetchClients(activeOnly: true)
            if case .create = mode, let preselectedClientId {
                selectedClientId = preselectedClientId
            } else if selectedClientId == nil {
                selectedClientId = clients.first?.id
            }
            if let clientId = selectedClientId {
                await loadInvoices(for: clientId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadInvoices(for clientId: UUID) async {
        do {
            async let invoicesTask = ClientService.fetchInvoices(forClient: clientId)
            async let paymentsTask = ClientService.fetchPayments(forClient: clientId)
            let (loadedInvoices, payments) = try await (invoicesTask, paymentsTask)
            let balance = ClientService.balanceSummary(from: loadedInvoices, payments: payments)
            await MainActor.run {
                invoices = loadedInvoices
                clientSoldRestant = balance.soldRestant
                clientMoneda = balance.moneda
                refreshAutoReference()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populateFields() {
        guard case .edit(let payment) = mode else { return }
        selectedClientId = payment.clientId
        if let invoiceId = payment.invoiceId {
            linkToInvoice = true
            selectedInvoiceIds = [invoiceId]
        }
        dataPlata = payment.dataPlata
        suma = SupplierFormatting.amountString(payment.suma)
        metodaPlata = payment.metodaPlata
        referinta = (payment.referinta ?? "").uppercased()
        observatii = payment.observatii ?? ""
    }

    private func save() async {
        guard !isLoading else { return }
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("clients.select_company_error")
            return
        }
        guard let clientId = selectedClientId,
              let amount = SupplierFormatting.parseAmount(suma),
              amount > 0 else { return }

        let invoiceId = linkToInvoice ? selectedInvoiceIds.first : nil
        let plan = plannedPaymentPlan
        let trimmedReference = referinta.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference: String
        if trimmedReference.isEmpty,
           plan.hasInvoiceAllocations || plan.hasAdvance {
            if !linkToInvoice {
                let projected = ClientPaymentAllocation.projectedBalance(
                    currentSoldRestant: clientSoldRestant,
                    paymentAmount: amount
                )
                reference = ClientPaymentAllocation.referenceString(
                    from: plan,
                    projectedBalance: projected,
                    currencyCode: clientMoneda
                ).uppercased()
            } else {
                reference = ClientPaymentAllocation.referenceString(from: plan).uppercased()
            }
        } else {
            reference = referinta
        }

        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                if plan.hasInvoiceAllocations || plan.hasAdvance {
                    _ = try await ClientService.createPaymentsFromPlan(
                        companyId: companyId,
                        clientId: clientId,
                        plan: plan,
                        dataPlata: dataPlata,
                        metodaPlata: metodaPlata,
                        referinta: reference,
                        observatii: observatii,
                        createdBy: session.currentProfile?.id
                    )
                } else {
                    _ = try await ClientService.createPayment(
                        companyId: companyId,
                        clientId: clientId,
                        invoiceId: invoiceId,
                        dataPlata: dataPlata,
                        suma: amount,
                        metodaPlata: metodaPlata,
                        referinta: reference,
                        observatii: observatii,
                        createdBy: session.currentProfile?.id
                    )
                }
            case .edit(let payment):
                _ = try await ClientService.updatePayment(
                    id: payment.id,
                    clientId: clientId,
                    invoiceId: invoiceId,
                    dataPlata: dataPlata,
                    suma: amount,
                    metodaPlata: metodaPlata,
                    referinta: referinta,
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

    private func deleteCurrentPayment() async {
        guard case .edit(let payment) = mode else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await ClientService.deletePayment(id: payment.id)
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func allocationLineView(_ line: ClientPaymentAllocationLine) -> some View {
        let invoice = invoices.first(where: { $0.id == line.invoiceId })
        let isPartial = invoice.map { ClientPaymentAllocation.isPartialAllocation(invoice: $0, allocatedAmount: line.amount) } ?? false
        HStack {
            Text(L10n.tr("client_collections.allocation_line", line.numarFactura, SupplierFormatting.currency(line.amount)))
                .font(.subheadline)
            if isPartial {
                Text(L10n.tr("client_collections.allocation_partial"))
                    .font(.caption2.bold())
                    .foregroundColor(.orange)
            }
        }
    }
}
