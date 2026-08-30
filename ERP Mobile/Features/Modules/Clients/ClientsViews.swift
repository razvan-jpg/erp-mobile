import SwiftUI

struct ClientsListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @State private var clientRows: [ClientListRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var selectedAccount: ClientAccountContext?
    @State private var clientToDelete: Client?
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var filteredClientRows: [ClientListRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: [ClientListRow]
        if query.isEmpty {
            rows = clientRows
        } else {
            rows = clientRows.filter {
                $0.client.denumire.localizedCaseInsensitiveContains(query)
                    || ($0.client.cui?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return rows.sorted {
            $0.client.denumire.localizedStandardCompare($1.client.denumire) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if filteredClientRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("clients.empty"),
                    systemImage: "building.2",
                    description: Text(access.canCreate
                        ? L10n.tr("clients.empty_create")
                        : L10n.tr("clients.empty_readonly"))
                )
            } else {
                List {
                    ForEach(filteredClientRows) { row in
                        ClientRowView(row: row) {
                            selectedAccount = ClientAccountContext(row: row)
                        }
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("clients.search_prompt"))
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
        .appTask { await loadClients() }
        .appRefreshable { await loadClients() }
        .fullScreenCover(isPresented: $showCreate) {
            ClientFormView(mode: .create, access: access) {
                await loadClients()
                await onChanged()
            }
        }
        .fullScreenCover(item: $selectedAccount) { account in
            ClientAccountView(context: account, access: access) {
                await loadClients()
                await onChanged()
            }
        }
        .alert(L10n.tr("clients.delete_title"), isPresented: $showDeleteConfirm, presenting: clientToDelete) { client in
            Button(L10n.tr("common.delete")) {
                Task { await deleteClient(client) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { client in
            Text(L10n.tr("clients.delete_confirm", client.denumire))
        }
    }

    private func loadClients() async {
        isLoading = true
        errorMessage = nil
        do {
            clientRows = try await ClientService.fetchClientListRows()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let client = filteredClientRows[index].client
        Task {
            do {
                if try await ClientService.clientHasInvoices(clientId: client.id) {
                    errorMessage = L10n.tr("clients.delete_blocked_invoices")
                    return
                }
                clientToDelete = client
                showDeleteConfirm = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteClient(_ client: Client) async {
        isLoading = true
        errorMessage = nil
        do {
            if try await ClientService.clientHasInvoices(clientId: client.id) {
                errorMessage = L10n.tr("clients.delete_blocked_invoices")
                isLoading = false
                return
            }
            try await ClientService.deleteClient(id: client.id)
            await loadClients()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ClientRowView: View {
    let row: ClientListRow
    let onEdit: () -> Void

    private var client: Client { row.client }

    var body: some View {
        Button(action: onEdit) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(client.denumire)
                            .font(.headline)
                            .foregroundColor(AppColors.primary)
                        if !client.isActive {
                            Text(L10n.tr("common.inactive"))
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    if let cui = client.cui, !cui.isEmpty {
                        Text(L10n.tr("common.cui_label", cui))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    if let telefon = client.telefon, !telefon.isEmpty {
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
                        Text(L10n.tr("clients.no_due_date"))
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

enum ClientFormMode: Identifiable {
    case create
    case edit(Client)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let client): return client.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("clients.create_title")
        case .edit: return L10n.tr("clients.edit_title")
        }
    }
}

struct ClientFormView: View {
    let mode: ClientFormMode
    let access: ModuleAccessRights
    var dismissAfterSave: Bool = true
    let onSaved: () async -> Void
    var onCreated: ((Client) async -> Void)? = nil

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
                Section(header: Text(L10n.tr("clients.section_data"))) {
                    FormTextField(title: L10n.tr("clients.field_name"), text: $denumire, isRequired: true)
                    cuiFieldWithAnafButton
                    FormTextField(title: L10n.tr("common.field_nr_reg_com"), text: $nrRegCom)
                    FormTextField(title: L10n.tr("common.field_address"), text: $adresa)
                    FormTextField(title: L10n.tr("common.field_iban"), text: $iban, autocapitalization: .characters)
                    FormTextField(title: L10n.tr("common.field_email"), text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                    FormTextField(title: L10n.tr("common.field_phone"), text: $telefon, keyboardType: .phonePad)
                    FormTextField(
                        title: L10n.tr("clients.field_payment_term_days"),
                        text: $nrZileScadenta,
                        keyboardType: .numberPad
                    )
                    Text(L10n.tr("clients.payment_term_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Toggle(L10n.tr("clients.field_active"), isOn: $isActive)
                }

                Section(header: Text(L10n.tr("clients.section_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("clients.field_notes"), text: $observatii)
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
            anafSuccessMessage = L10n.tr("clients.anaf_success")
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
        guard case .edit(let client) = mode else { return }
        denumire = client.denumire
        cui = client.cui ?? ""
        nrRegCom = client.nrRegCom ?? ""
        adresa = client.adresa ?? ""
        iban = client.iban ?? ""
        email = client.email ?? ""
        telefon = client.telefon ?? ""
        observatii = client.observatii ?? ""
        nrZileScadenta = String(client.nrZileScadenta)
        isActive = client.isActive
    }

    private func parsedPaymentTermDays() -> Int? {
        let trimmed = nrZileScadenta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("clients.select_company_error")
            return
        }
        guard let paymentTermDays = parsedPaymentTermDays() else {
            errorMessage = L10n.tr("clients.invalid_payment_term")
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                let client = try await ClientService.createClient(
                    companyId: companyId,
                    denumire: denumire.trimmingCharacters(in: .whitespaces),
                    cui: cui, nrRegCom: nrRegCom, adresa: adresa, iban: iban,
                    email: email, telefon: telefon, observatii: observatii,
                    nrZileScadenta: paymentTermDays, isActive: isActive
                )
                if let onCreated {
                    await onCreated(client)
                }
            case .edit(let client):
                _ = try await ClientService.updateClient(
                    id: client.id,
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
