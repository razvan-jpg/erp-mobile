import SwiftUI

struct PaymentsListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var payments: [SupplierPaymentRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var paymentToEdit: SupplierPaymentRow?
    @State private var paymentToDelete: SupplierPaymentRow?
    @State private var showDeleteConfirm = false
    @State private var filterReferenceNumber = ""
    @State private var filterInvoiceNumber = ""
    @State private var filterSupplierName = ""
    @State private var filterDateIntervalEnabled = false
    @State private var filterDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var filterDateTo = Calendar.current.startOfDay(for: Date())

    private var hasActiveFilters: Bool {
        !filterReferenceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterInvoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || filterDateIntervalEnabled
    }

    private var filteredPayments: [SupplierPaymentRow] {
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

            let supplierQuery = filterSupplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !supplierQuery.isEmpty,
               !payment.supplierName.localizedCaseInsensitiveContains(supplierQuery) {
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
                        Button(L10n.tr("payments.filter_reset")) {
                            resetFilters()
                        }
                        .font(.subheadline)
                    }
                }

                TextField(L10n.tr("payments.filter_reference_number"), text: $filterReferenceNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField(L10n.tr("payments.filter_invoice_number"), text: $filterInvoiceNumber)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()

                TextField(L10n.tr("payments.filter_supplier_name"), text: $filterSupplierName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                Toggle(L10n.tr("payments.filter_date_interval"), isOn: $filterDateIntervalEnabled)
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

            Group {
                if filteredPayments.isEmpty && !isLoading {
                    AppEmptyStateView(
                        hasActiveFilters ? L10n.tr("payments.empty_filtered") : L10n.tr("payments.empty"),
                        systemImage: "banknote",
                        description: Text(
                            hasActiveFilters
                                ? L10n.tr("payments.empty_filtered_hint")
                                : (access.canCreate
                                    ? L10n.tr("payments.empty_create")
                                    : L10n.tr("payments.empty_readonly"))
                        )
                    )
                } else {
                    List {
                        ForEach(filteredPayments) { payment in
                            PaymentRowView(
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
            PaymentFormView(mode: .create, access: access) {
                await loadPayments()
                await onChanged()
            }
        }
        .fullScreenCover(item: $paymentToEdit) { payment in
            PaymentFormView(mode: .edit(payment), access: access) {
                await loadPayments()
                await onChanged()
            }
        }
        .alert(L10n.tr("payments.delete_title"), isPresented: $showDeleteConfirm, presenting: paymentToDelete) { payment in
            Button(L10n.tr("common.delete")) {
                Task { await deletePayment(payment) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { _ in
            Text(L10n.tr("payments.delete_confirm"))
        }
    }

    private func loadPayments() async {
        isLoading = true
        errorMessage = nil
        do {
            payments = try await SupplierService.fetchPayments()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resetFilters() {
        filterReferenceNumber = ""
        filterInvoiceNumber = ""
        filterSupplierName = ""
        filterDateIntervalEnabled = false
        filterDateFrom = Calendar.current.startOfDay(for: Date())
        filterDateTo = Calendar.current.startOfDay(for: Date())
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        requestDelete(filteredPayments[index])
    }

    private func requestDelete(_ payment: SupplierPaymentRow) {
        paymentToDelete = payment
        showDeleteConfirm = true
    }

    private func deletePayment(_ payment: SupplierPaymentRow) async {
        isLoading = true
        do {
            try await SupplierService.deletePayment(id: payment.id)
            await loadPayments()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct PaymentRowView: View {
    let payment: SupplierPaymentRow
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
            Text(payment.supplierName)
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
            if let invoiceNumber = payment.invoiceNumber {
                Text(L10n.tr("payments.invoice_label", invoiceNumber))
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
            }
            Text(SupplierFormatting.date(payment.dataPlata))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            if let referinta = payment.referinta, !referinta.isEmpty {
                Text(L10n.tr("payments.ref_label", referinta))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum PaymentFormMode: Identifiable {
    case create
    case edit(SupplierPaymentRow)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let payment): return payment.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("payments.create_title")
        case .edit: return L10n.tr("payments.edit_title")
        }
    }
}

struct PaymentFormView: View {
    let mode: PaymentFormMode
    let access: ModuleAccessRights
    var preselectedSupplierId: UUID? = nil
    var preselectedSupplierName: String? = nil
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var suppliers: [Supplier] = []
    @State private var invoices: [SupplierInvoice] = []
    @State private var selectedSupplierId: UUID?
    @State private var selectedInvoiceIds: [UUID] = []
    @State private var linkToInvoice = false
    @State private var sumaManuallyEdited = false
    @State private var isApplyingAutoSuma = false
    @State private var dataPlata = Date()
    @State private var suma = ""
    @State private var metodaPlata: PaymentMethod = .transfer
    @State private var referinta = ""
    @State private var observatii = ""
    @State private var supplierSoldRestant: Decimal = 0
    @State private var supplierMoneda = "RON"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    private var openInvoices: [SupplierInvoice] {
        PaymentAllocation.sortedOpenInvoices(invoices)
    }

    private var openInvoiceRows: [PaymentFormOpenInvoiceRow] {
        openInvoices.map(\.paymentFormOpenInvoiceRow)
    }

    private var plannedPaymentPlan: PaymentAllocationPlan {
        guard case .create = mode,
              let amount = SupplierFormatting.parseAmount(suma),
              amount > 0 else { return .empty }

        let rawPlan: PaymentAllocationPlan
        if linkToInvoice, !selectedInvoiceIds.isEmpty {
            rawPlan = PaymentAllocation.planForSelectedInvoices(
                invoices: invoices,
                selectedInvoiceIds: selectedInvoiceIds,
                totalAmount: amount
            )
        } else if !linkToInvoice {
            rawPlan = PaymentAllocation.planByDueDate(invoices: invoices, totalAmount: amount)
        } else {
            return .empty
        }
        return PaymentAllocation.sanitizedPlan(rawPlan)
    }

    private var allocationHint: String {
        linkToInvoice
            ? L10n.tr("payments.allocation_hint_multi")
            : L10n.tr("payments.allocation_hint_due_date")
    }

    private var isAdvancePayment: Bool {
        guard case .create = mode else { return false }
        return plannedPaymentPlan.isFullAdvance
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("payments.section_supplier"))) {
                    if let preselectedSupplierId,
                       case .create = mode {
                        let supplierName = suppliers.first(where: { $0.id == preselectedSupplierId })?.denumire
                            ?? preselectedSupplierName
                            ?? "—"
                        AppLabeledContent(L10n.tr("invoices.field_supplier_required"), value: supplierName)
                    } else {
                        Picker(L10n.tr("invoices.field_supplier_required"), selection: $selectedSupplierId) {
                            Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                            ForEach(suppliers) { supplier in
                                Text(supplier.denumire).tag(Optional(supplier.id))
                            }
                        }
                        .onChange(of: selectedSupplierId) { newValue in
                            selectedInvoiceIds = []
                            sumaManuallyEdited = false
                            if let newValue {
                                Task { await loadInvoices(for: newValue) }
                            } else {
                                invoices = []
                                supplierSoldRestant = 0
                                supplierMoneda = "RON"
                            }
                        }
                    }
                }

                Section(header: Text(L10n.tr("payments.section_invoice_optional"))) {
                    Toggle(L10n.tr("payments.link_invoice"), isOn: $linkToInvoice)
                        .onChange(of: linkToInvoice) { enabled in
                            if !enabled {
                                selectedInvoiceIds = []
                                sumaManuallyEdited = false
                            }
                            refreshAutoReference()
                        }
                    if linkToInvoice {
                        PaymentFormMultiInvoiceSelectionSection(
                            emptyMessageKey: "payments.no_open_invoices",
                            selectHintKey: "payments.select_invoices_hint",
                            selectedTotalKey: "payments.selected_invoices_total",
                            resetAmountKey: "payments.reset_amount_to_selected",
                            invoiceRestFormatKey: "payments.invoice_rest",
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
                    Section(header: Text(L10n.tr("payments.section_advance"))) {
                        Text(L10n.tr("payments.advance_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        if let amount = SupplierFormatting.parseAmount(suma), amount > 0 {
                            Text(L10n.tr("payments.advance_line", SupplierFormatting.currency(amount)))
                                .font(.subheadline)
                        }
                    }
                } else if case .create = mode, plannedPaymentPlan.hasInvoiceAllocations {
                    Section(header: Text(L10n.tr("payments.section_allocation"))) {
                        Text(allocationHint)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        ForEach(plannedPaymentPlan.invoiceLines) { line in
                            allocationLineView(line)
                        }
                        if plannedPaymentPlan.hasAdvance {
                            Text(L10n.tr("payments.advance_line", SupplierFormatting.currency(plannedPaymentPlan.advanceAmount)))
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }

                Section(header: Text(L10n.tr("payments.section_details"))) {
                    DateInputField(title: L10n.tr("payments.field_payment_date"), date: $dataPlata, isRequired: true)
                    FormTextField(
                        title: L10n.tr("payments.field_amount"),
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
                    Picker(L10n.tr("payments.field_method"), selection: $metodaPlata) {
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.label).tag(method)
                        }
                    }
                    FormTextField(title: L10n.tr("payments.field_reference"), text: referintaBinding)
                }

                Section(header: Text(L10n.tr("payments.section_notes"))) {
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
            .alert(L10n.tr("payments.delete_title"), isPresented: $showDeleteConfirm) {
                Button(L10n.tr("common.delete")) {
                    Task { await deleteCurrentPayment() }
                }
                Button(L10n.tr("common.cancel")) {}
            } message: {
                Text(L10n.tr("payments.delete_confirm"))
            }
            .appTask {
                await loadSuppliers()
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
        guard selectedSupplierId != nil, SupplierFormatting.parseAmount(suma) != nil else { return false }
        if case .create = mode,
           linkToInvoice,
           selectedInvoiceIds.isEmpty,
           PaymentAllocation.hasAllocatableOpenInvoices(invoices) {
            return false
        }
        return true
    }

    private func refreshAutoReference() {
        guard case .create = mode else { return }
        let plan = plannedPaymentPlan
        guard plan.hasInvoiceAllocations || plan.hasAdvance else { return }

        if !linkToInvoice, let paymentAmount = SupplierFormatting.parseAmount(suma), paymentAmount > 0 {
            let projected = PaymentAllocation.projectedBalance(
                currentSoldRestant: supplierSoldRestant,
                paymentAmount: paymentAmount
            )
            referinta = PaymentAllocation.referenceString(
                from: plan,
                projectedBalance: projected,
                currencyCode: supplierMoneda
            ).uppercased()
        } else {
            referinta = PaymentAllocation.referenceString(from: plan).uppercased()
        }
    }

    private func loadSuppliers() async {
        do {
            suppliers = try await SupplierService.fetchSuppliers(activeOnly: true)
            if case .create = mode, let preselectedSupplierId {
                selectedSupplierId = preselectedSupplierId
            } else if selectedSupplierId == nil {
                selectedSupplierId = suppliers.first?.id
            }
            if let supplierId = selectedSupplierId {
                await loadInvoices(for: supplierId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadInvoices(for supplierId: UUID) async {
        do {
            async let invoicesTask = SupplierService.fetchInvoices(forSupplier: supplierId)
            async let paymentsTask = SupplierService.fetchPayments(forSupplier: supplierId)
            let (loadedInvoices, payments) = try await (invoicesTask, paymentsTask)
            let balance = SupplierService.balanceSummary(from: loadedInvoices, payments: payments)
            await MainActor.run {
                invoices = loadedInvoices
                supplierSoldRestant = balance.soldRestant
                supplierMoneda = balance.moneda
                refreshAutoReference()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func populateFields() {
        guard case .edit(let payment) = mode else { return }
        selectedSupplierId = payment.supplierId
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
            errorMessage = L10n.tr("suppliers.select_company_error")
            return
        }
        guard let supplierId = selectedSupplierId,
              let amount = SupplierFormatting.parseAmount(suma),
              amount > 0 else { return }

        let invoiceId = linkToInvoice ? selectedInvoiceIds.first : nil
        let plan = plannedPaymentPlan
        let trimmedReference = referinta.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference: String
        if trimmedReference.isEmpty,
           plan.hasInvoiceAllocations || plan.hasAdvance {
            if !linkToInvoice {
                let projected = PaymentAllocation.projectedBalance(
                    currentSoldRestant: supplierSoldRestant,
                    paymentAmount: amount
                )
                reference = PaymentAllocation.referenceString(
                    from: plan,
                    projectedBalance: projected,
                    currencyCode: supplierMoneda
                ).uppercased()
            } else {
                reference = PaymentAllocation.referenceString(from: plan).uppercased()
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
                    _ = try await SupplierService.createPaymentsFromPlan(
                        companyId: companyId,
                        supplierId: supplierId,
                        plan: plan,
                        dataPlata: dataPlata,
                        metodaPlata: metodaPlata,
                        referinta: reference,
                        observatii: observatii,
                        createdBy: session.currentProfile?.id
                    )
                } else {
                    _ = try await SupplierService.createPayment(
                        companyId: companyId,
                        supplierId: supplierId,
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
                _ = try await SupplierService.updatePayment(
                    id: payment.id,
                    supplierId: supplierId,
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
            try await SupplierService.deletePayment(id: payment.id)
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func allocationLineView(_ line: PaymentAllocationLine) -> some View {
        let invoice = invoices.first(where: { $0.id == line.invoiceId })
        let isPartial = invoice.map { PaymentAllocation.isPartialAllocation(invoice: $0, allocatedAmount: line.amount) } ?? false
        HStack {
            Text(L10n.tr("payments.allocation_line", line.numarFactura, SupplierFormatting.currency(line.amount)))
                .font(.subheadline)
            if isPartial {
                Text(L10n.tr("payments.allocation_partial"))
                    .font(.caption2.bold())
                    .foregroundColor(.orange)
            }
        }
    }
}
