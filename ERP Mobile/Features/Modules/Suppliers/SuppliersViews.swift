import SwiftUI

struct SuppliersListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var supplierRows: [SupplierListRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var selectedAccount: SupplierAccountContext?
    @State private var supplierToDelete: Supplier?
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var filteredSupplierRows: [SupplierListRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: [SupplierListRow]
        if query.isEmpty {
            rows = supplierRows
        } else {
            rows = supplierRows.filter {
                $0.supplier.denumire.localizedCaseInsensitiveContains(query)
                    || ($0.supplier.cui?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return rows.sorted {
            $0.supplier.denumire.localizedStandardCompare($1.supplier.denumire) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if filteredSupplierRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("suppliers.empty"),
                    systemImage: "building.2",
                    description: Text(access.canCreate
                        ? L10n.tr("suppliers.empty_create")
                        : L10n.tr("suppliers.empty_readonly"))
                )
            } else {
                List {
                    ForEach(filteredSupplierRows) { row in
                        SupplierRowView(row: row) {
                            selectedAccount = SupplierAccountContext(row: row)
                        }
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("suppliers.search_prompt"))
                .appScrollBottomPadding()
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
        .appTask { await loadSuppliers() }
        .appRefreshable { await loadSuppliers() }
        .fullScreenCover(isPresented: $showCreate) {
            SupplierFormView(mode: .create, access: access) {
                await loadSuppliers()
                await onChanged()
            }
        }
        .fullScreenCover(item: $selectedAccount) { account in
            SupplierAccountView(context: account, access: access) {
                await loadSuppliers()
                await onChanged()
            }
        }
        .alert(L10n.tr("suppliers.delete_title"), isPresented: $showDeleteConfirm, presenting: supplierToDelete) { supplier in
            Button(L10n.tr("common.delete")) {
                Task { await deleteSupplier(supplier) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { supplier in
            Text(L10n.tr("suppliers.delete_confirm", supplier.denumire))
        }
    }

    private func loadSuppliers() async {
        isLoading = true
        errorMessage = nil
        do {
            supplierRows = try await SupplierService.fetchSupplierListRows()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let supplier = filteredSupplierRows[index].supplier
        Task {
            do {
                if try await SupplierService.supplierHasInvoices(supplierId: supplier.id) {
                    errorMessage = L10n.tr("suppliers.delete_blocked_invoices")
                    return
                }
                supplierToDelete = supplier
                showDeleteConfirm = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteSupplier(_ supplier: Supplier) async {
        isLoading = true
        errorMessage = nil
        do {
            if try await SupplierService.supplierHasInvoices(supplierId: supplier.id) {
                errorMessage = L10n.tr("suppliers.delete_blocked_invoices")
                isLoading = false
                return
            }
            try await SupplierService.deleteSupplier(id: supplier.id)
            await loadSuppliers()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct SupplierRowView: View {
    let row: SupplierListRow
    let onEdit: () -> Void

    private var supplier: Supplier { row.supplier }

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(supplier.denumire)
                            .font(.headline)
                            .foregroundColor(AppColors.primary)
                        if !supplier.isActive {
                            Text(L10n.tr("common.inactive"))
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    if let cui = supplier.cui, !cui.isEmpty {
                        Text(L10n.tr("common.cui_label", cui))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    if let telefon = supplier.telefon, !telefon.isEmpty {
                        Text(L10n.tr("common.phone_label", telefon))
                            .font(.caption)
                            .foregroundColor(AppColors.tertiary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(SupplierFormatting.currency(row.soldRestant, code: row.moneda))
                        .font(.subheadline.bold())
                        .foregroundColor(row.soldRestant > 0 ? Color.orange : Color.secondary)

                    if let scadenta = row.primaScadenta {
                        Text(SupplierFormatting.date(scadenta))
                            .font(.caption)
                            .foregroundColor(isOverdue(scadenta) ? Color.red : Color.secondary)
                    } else if row.soldRestant > 0 {
                        Text(L10n.tr("suppliers.no_due_date"))
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func isOverdue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

enum SupplierFormMode: Identifiable {
    case create
    case edit(Supplier)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let supplier): return supplier.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("suppliers.create_title")
        case .edit: return L10n.tr("suppliers.edit_title")
        }
    }
}

struct SupplierFormView: View {
    let mode: SupplierFormMode
    let access: ModuleAccessRights
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void
    var onCreated: ((Supplier) async -> Void)? = nil

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var denumire = ""
    @State private var cui = ""
    @State private var nrRegCom = ""
    @State private var adresa = ""
    @State private var iban = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var observatii = ""
    @State private var nrZileScadenta = "0"
    @State private var isActive = true
    @State private var isLoading = false
    @State private var isFetchingAnaf = false
    @State private var errorMessage: String?
    @State private var anafSuccessMessage: String?

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("suppliers.section_data"))) {
                    FormTextField(title: L10n.tr("suppliers.field_name"), text: $denumire, isRequired: true)
                    cuiFieldWithAnafButton
                    FormTextField(title: L10n.tr("common.field_nr_reg_com"), text: $nrRegCom)
                    FormTextField(title: L10n.tr("common.field_address"), text: $adresa)
                    FormTextField(title: L10n.tr("common.field_iban"), text: $iban, autocapitalization: .characters)
                    FormTextField(title: L10n.tr("common.field_email"), text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                    FormTextField(title: L10n.tr("common.field_phone"), text: $telefon, keyboardType: .phonePad)
                    FormTextField(
                        title: L10n.tr("suppliers.field_payment_term_days"),
                        text: $nrZileScadenta,
                        keyboardType: .numberPad
                    )
                    Text(L10n.tr("suppliers.payment_term_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Toggle(L10n.tr("suppliers.field_active"), isOn: $isActive)
                }

                Section(header: Text(L10n.tr("suppliers.section_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("suppliers.field_notes"), text: $observatii)
                }

                if let anafSuccessMessage {
                    Section {
                        Text(anafSuccessMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
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
                        .disabled(!canSave || denumire.trimmingCharacters(in: .whitespaces).isEmpty || isLoading || isFetchingAnaf)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .onAppear { populateFields() }
            .onChange(of: cui) { _ in
                anafSuccessMessage = nil
            }
        }
    }

    private var cuiFieldWithAnafButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("common.cui"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            HStack(alignment: .center, spacing: 8) {
                TextField(L10n.tr("common.cui"), text: $cui)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .keyboardType(.numbersAndPunctuation)
                    .disabled(isFetchingAnaf)

                Button {
                    Task { await fetchFromAnaf() }
                } label: {
                    if isFetchingAnaf {
                        ProgressView()
                            .appControlSize(.small)
                            .frame(width: 44)
                    } else {
                        Label(L10n.tr("common.anaf"), systemImage: "building.columns")
                            .appLabelStyleTitleAndIcon()
                    }
                }
                .buttonStyle(AppButtonStyles.bordered)
                .appControlSize(.small)
                .disabled(isFetchingAnaf || Validators.normalizedCUI(cui) == nil)
            }
            Text(L10n.tr("company.anaf_hint"))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
        }
    }

    private func fetchFromAnaf() async {
        isFetchingAnaf = true
        errorMessage = nil
        anafSuccessMessage = nil
        do {
            let data = try await AnafService.fetchCompany(cui: cui)
            guard data.hasAnyData else {
                throw AnafServiceError.notFound
            }
            applyAnafData(data)
            anafSuccessMessage = L10n.tr("suppliers.anaf_success")
        } catch {
            errorMessage = error.localizedDescription
        }
        isFetchingAnaf = false
    }

    private func applyAnafData(_ data: AnafCompanyLookup) {
        cui = data.cui
        denumire = data.denumire
        if let nrRegCom = data.nrRegCom { self.nrRegCom = nrRegCom }
        if let adresa = data.adresa { self.adresa = adresa }
        if let telefon = data.telefon { self.telefon = telefon }
        if let iban = data.iban { self.iban = iban }
        if let observatiiAnaf = data.observatii {
            if observatii.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                observatii = observatiiAnaf
            } else if !observatii.contains(observatiiAnaf) {
                observatii += "\n\(observatiiAnaf)"
            }
        }
    }

    private func populateFields() {
        guard case .edit(let supplier) = mode else { return }
        denumire = supplier.denumire
        cui = supplier.cui ?? ""
        nrRegCom = supplier.nrRegCom ?? ""
        adresa = supplier.adresa ?? ""
        iban = supplier.iban ?? ""
        email = supplier.email ?? ""
        telefon = supplier.telefon ?? ""
        observatii = supplier.observatii ?? ""
        nrZileScadenta = String(supplier.nrZileScadenta)
        isActive = supplier.isActive
    }

    private func parsedPaymentTermDays() -> Int? {
        let trimmed = nrZileScadenta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("suppliers.select_company_error")
            return
        }
        guard let paymentTermDays = parsedPaymentTermDays() else {
            errorMessage = L10n.tr("suppliers.invalid_payment_term")
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                let supplier = try await SupplierService.createSupplier(
                    companyId: companyId,
                    denumire: denumire.trimmingCharacters(in: .whitespaces),
                    cui: cui, nrRegCom: nrRegCom, adresa: adresa, iban: iban,
                    email: email, telefon: telefon, observatii: observatii,
                    nrZileScadenta: paymentTermDays, isActive: isActive
                )
                if let onCreated {
                    await onCreated(supplier)
                }
            case .edit(let supplier):
                _ = try await SupplierService.updateSupplier(
                    id: supplier.id,
                    denumire: denumire.trimmingCharacters(in: .whitespaces),
                    cui: cui, nrRegCom: nrRegCom, adresa: adresa, iban: iban,
                    email: email, telefon: telefon, observatii: observatii,
                    nrZileScadenta: paymentTermDays, isActive: isActive
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
