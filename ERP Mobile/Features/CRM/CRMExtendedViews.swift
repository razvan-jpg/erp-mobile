import SwiftUI

// MARK: - Lead-uri

struct CRMLeadsListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var session: SessionManager
    @State private var leads: [CRMLead] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var selectedLead: CRMLead?
    @State private var searchText = ""
    @State private var showOpenOnly = true
    @State private var errorMessage: String?

    private var filtered: [CRMLead] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return leads.filter { lead in
            if showOpenOnly && lead.stage.isClosed { return false }
            guard !q.isEmpty else { return true }
            return lead.title.localizedCaseInsensitiveContains(q)
                || (lead.contactName ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(L10n.tr("crm.show_open_leads_only"), isOn: $showOpenOnly).padding()
            if filtered.isEmpty && !isLoading {
                AppEmptyStateView(L10n.tr("crm.no_leads"), systemImage: "person.crop.circle.badge.plus",
                                  description: Text(L10n.tr("crm.no_leads_create")))
            } else {
                List {
                    ForEach(filtered) { lead in
                        Button { selectedLead = lead } label: {
                            CRMDealRowView(lead: lead)
                        }.buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_leads"))
            }
        }
        .floatingBottomTrailing {
            if access.canCreate {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 44)).appSymbolRenderingMode(.hierarchical)
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .fullScreenCover(isPresented: $showCreate) {
            CRMDealFormView(access: access, presetStage: .new, pipelineType: .lead) { await reload() }
        }
        .fullScreenCover(item: $selectedLead) { lead in
            CRMDealDetailView(lead: lead, access: access, allowsConvert: true) { await reload() }
        }
        .crmErrorFooter(errorMessage)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            leads = try await CRMLeadService.fetchLeads(pipelineType: .lead)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        Task {
            do {
                for i in offsets {
                    try await CRMLeadService.deleteLead(id: filtered[i].id)
                }
                NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Companii CRM

struct CRMCompaniesListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var items: [CRMCompany] = []
    @State private var isLoading = false
    @State private var selected: CRMCompany?
    @State private var showCreate = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filtered: [CRMCompany] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(q) || ($0.cui ?? "").contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            CRMInfoBanner(text: L10n.tr("crm.companies_erp_banner"), color: .blue, icon: "arrow.triangle.2.circlepath")
                .padding()

            Group {
                if filtered.isEmpty && !isLoading {
                    AppEmptyStateView(L10n.tr("crm.no_companies"), systemImage: "building.2",
                                      description: Text(L10n.tr("crm.no_companies_erp_hint")))
                } else {
                    List {
                        ForEach(filtered) { item in
                            Button { selected = item } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name).font(.subheadline.weight(.semibold))
                                        if let cui = item.cui, !cui.isEmpty {
                                            Text(cui).font(.caption).foregroundColor(AppColors.secondary)
                                        }
                                        if item.isFromERP {
                                            Text(L10n.tr("crm.badge_from_erp"))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.blue)
                                        } else {
                                            Text(L10n.tr("crm.badge_manual"))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.teal)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.tertiary)
                                }
                                .padding(.vertical, 4)
                            }.buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if access.canDelete, !item.isFromERP {
                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await CRMExtendedService.deleteCRMCompany(id: item.id)
                                                await reload()
                                            } catch {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    } label: {
                                        Label(L10n.tr("common.delete"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_companies"))
                }
            }
        }
        .floatingBottomTrailing {
            if access.canCreate, companyManager.currentCompany != nil {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 44)).appSymbolRenderingMode(.hierarchical)
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: companyManager.currentCompany?.id) { await reload() }
        .appRefreshable { await reload() }
        .sheet(isPresented: $showCreate) {
            CRMCompanyFormView(access: access) { await reload() }
        }
        .sheet(item: $selected) { item in
            CRMCompanyDetailView(company: item, access: access) { await reload() }
        }
        .crmErrorFooter(errorMessage)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let companyId = companyManager.currentCompany?.id else {
            items = []
            return
        }
        do {
            items = try await CRMExtendedService.fetchCRMCompaniesFromERP(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

struct CRMCompanyDetailView: View {
    let company: CRMCompany
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    init(company: CRMCompany, access: ModuleAccessRights, onChanged: @escaping () async -> Void = {}) {
        self.company = company
        self.access = access
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationView {
            List {
                if company.isFromERP {
                    Section {
                        Text(L10n.tr("crm.company_erp_readonly"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                Section(L10n.tr("crm.section_company")) {
                    detailRow(L10n.tr("crm.field_company_name"), company.name)
                    if let cui = company.cui, !cui.isEmpty { detailRow(L10n.tr("crm.field_cui"), cui) }
                    if let email = company.email, !email.isEmpty { detailRow(L10n.tr("crm.field_email"), email) }
                    if let phone = company.phone, !phone.isEmpty { detailRow(L10n.tr("crm.field_phone"), phone) }
                    if let website = company.website, !website.isEmpty { detailRow(L10n.tr("crm.field_website"), website) }
                    if let address = company.address, !address.isEmpty { detailRow(L10n.tr("crm.field_address"), address) }
                    if let industry = company.industry, !industry.isEmpty { detailRow(L10n.tr("crm.field_industry"), industry) }
                    if let notes = company.notes, !notes.isEmpty { detailRow(L10n.tr("crm.field_notes"), notes) }
                }
            }
            .navigationTitle(company.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("crm.action_edit_company")) { showEdit = true }
                        .opacity(canEditCompany ? 1 : 0)
                        .disabled(!canEditCompany)
                        .allowsHitTesting(canEditCompany)
                }
            }
            .sheet(isPresented: $showEdit) {
                CRMCompanyFormView(access: access, existing: company) {
                    await onChanged()
                    dismiss()
                }
            }
        }
    }

    private var canEditCompany: Bool {
        access.canEdit && !company.isFromERP
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(AppColors.secondary)
            Text(value)
        }
        .padding(.vertical, 2)
    }
}

struct CRMCompanyFormView: View {
    let access: ModuleAccessRights
    var existing: CRMCompany?
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var name = ""
    @State private var cui = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var website = ""
    @State private var address = ""
    @State private var industry = ""
    @State private var notes = ""
    @State private var assignableUsers: [UserProfile] = []
    @State private var assignedTo: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                if let erpCompany = companyManager.currentCompany {
                    Section {
                        Text(L10n.tr("crm.manual_scope_company", erpCompany.denumire))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                Section(L10n.tr("crm.section_company")) {
                    TextField(L10n.tr("crm.field_company_name"), text: $name)
                    TextField(L10n.tr("crm.field_cui"), text: $cui)
                    TextField(L10n.tr("crm.field_email"), text: $email).keyboardType(.emailAddress)
                    TextField(L10n.tr("crm.field_phone"), text: $phone).keyboardType(.phonePad)
                    TextField(L10n.tr("crm.field_website"), text: $website).keyboardType(.URL)
                    TextField(L10n.tr("crm.field_address"), text: $address)
                    TextField(L10n.tr("crm.field_industry"), text: $industry)
                }
                Section(L10n.tr("crm.field_notes")) {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                if !assignableUsers.isEmpty {
                    Section(L10n.tr("crm.section_contact")) {
                        CRMAssigneePicker(selectedUserId: $assignedTo, users: assignableUsers)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle(existing == nil ? L10n.tr("crm.company_create_title") : L10n.tr("crm.action_edit_company"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { populate() }
            .appTask { await loadUsers() }
        }
    }

    private func populate() {
        guard let existing else { return }
        name = existing.name
        cui = existing.cui ?? ""
        email = existing.email ?? ""
        phone = existing.phone ?? ""
        website = existing.website ?? ""
        address = existing.address ?? ""
        industry = existing.industry ?? ""
        notes = existing.notes ?? ""
        assignedTo = existing.assignedTo
    }

    private func loadUsers() async {
        assignableUsers = await CRMUserDirectory.fetchAssignableUsers(
            companyId: companyManager.currentCompany?.id,
            currentProfile: session.currentProfile
        )
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            if var item = existing {
                item.name = name
                item.cui = trimmedOptional(cui)
                item.email = trimmedOptional(email)
                item.phone = trimmedOptional(phone)
                item.website = trimmedOptional(website)
                item.address = trimmedOptional(address)
                item.industry = trimmedOptional(industry)
                item.notes = trimmedOptional(notes)
                item.assignedTo = assignedTo
                try await CRMExtendedService.updateCRMCompany(item)
            } else {
                _ = try await CRMExtendedService.createCRMCompany(
                    companyId: companyId,
                    name: name,
                    cui: trimmedOptional(cui),
                    email: trimmedOptional(email),
                    phone: trimmedOptional(phone),
                    website: trimmedOptional(website),
                    address: trimmedOptional(address),
                    industry: trimmedOptional(industry),
                    notes: trimmedOptional(notes),
                    assignedTo: assignedTo,
                    createdBy: session.currentProfile?.id
                )
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmedOptional(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Contacte

struct CRMContactsListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var items: [CRMContact] = []
    @State private var companiesById: [UUID: CRMCompany] = [:]
    @State private var isLoading = false
    @State private var selected: CRMContact?
    @State private var showCreate = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filtered: [CRMContact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter {
            $0.displayName.localizedCaseInsensitiveContains(q)
                || ($0.email ?? "").localizedCaseInsensitiveContains(q)
                || ($0.phone ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CRMInfoBanner(text: L10n.tr("crm.contacts_erp_banner"), color: .purple, icon: "arrow.triangle.2.circlepath")
                .padding()

            Group {
                if filtered.isEmpty && !isLoading {
                    AppEmptyStateView(L10n.tr("crm.no_contacts"), systemImage: "person.2",
                                      description: Text(L10n.tr("crm.no_contacts_erp_hint")))
                } else {
                    List {
                        ForEach(filtered) { item in
                            Button { selected = item } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(CRMContactDisplay.localizedName(item)).font(.subheadline.weight(.semibold))
                                        if let companyId = item.crmCompanyId, let company = companiesById[companyId] {
                                            Text(company.name).font(.caption).foregroundColor(AppColors.secondary)
                                        }
                                        if let email = item.email, !email.isEmpty {
                                            Text(email).font(.caption2).foregroundColor(AppColors.tertiary)
                                        }
                                        if item.isFromERP {
                                            Text(L10n.tr("crm.badge_from_erp"))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.purple)
                                        } else {
                                            Text(L10n.tr("crm.badge_manual"))
                                                .font(.caption2.weight(.semibold))
                                                .foregroundColor(.teal)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(AppColors.tertiary)
                                }
                                .padding(.vertical, 4)
                            }.buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if access.canDelete, !item.isFromERP {
                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await CRMExtendedService.deleteCRMContact(id: item.id)
                                                await reload()
                                            } catch {
                                                errorMessage = error.localizedDescription
                                            }
                                        }
                                    } label: {
                                        Label(L10n.tr("common.delete"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_contacts"))
                }
            }
        }
        .floatingBottomTrailing {
            if access.canCreate, companyManager.currentCompany != nil {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 44)).appSymbolRenderingMode(.hierarchical)
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: companyManager.currentCompany?.id) { await reload() }
        .appRefreshable { await reload() }
        .sheet(isPresented: $showCreate) {
            CRMContactFormView(access: access) { await reload() }
        }
        .sheet(item: $selected) { item in
            CRMContactDetailView(
                contact: item,
                companyName: item.crmCompanyId.flatMap { companiesById[$0]?.name },
                access: access
            ) { await reload() }
        }
        .crmErrorFooter(errorMessage)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let companyId = companyManager.currentCompany?.id else {
            items = []
            companiesById = [:]
            return
        }
        do {
            async let contactsTask = CRMExtendedService.fetchCRMContactsFromERP(companyId: companyId)
            async let companiesTask = CRMExtendedService.fetchCRMCompaniesFromERP(companyId: companyId)
            items = try await contactsTask
            let companies = try await companiesTask
            companiesById = Dictionary(uniqueKeysWithValues: companies.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

struct CRMContactDetailView: View {
    let contact: CRMContact
    var companyName: String?
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false

    init(
        contact: CRMContact,
        companyName: String? = nil,
        access: ModuleAccessRights,
        onChanged: @escaping () async -> Void = {}
    ) {
        self.contact = contact
        self.companyName = companyName
        self.access = access
        self.onChanged = onChanged
    }

    var body: some View {
        NavigationView {
            List {
                if contact.isFromERP {
                    Section {
                        Text(L10n.tr("crm.contact_erp_readonly"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                Section(L10n.tr("crm.section_contact")) {
                    detailRow(L10n.tr("crm.field_contact"), CRMContactDisplay.localizedName(contact))
                    if let companyName, !companyName.isEmpty {
                        detailRow(L10n.tr("crm.field_crm_company"), companyName)
                    }
                    if let position = contact.position, !position.isEmpty {
                        detailRow(L10n.tr("crm.field_position"), localizedPosition(position))
                    }
                    if let email = contact.email, !email.isEmpty {
                        detailRow(L10n.tr("crm.field_email"), email)
                    }
                    if let phone = contact.phone, !phone.isEmpty {
                        detailRow(L10n.tr("crm.field_phone"), phone)
                    }
                    if let notes = contact.notes, !notes.isEmpty {
                        detailRow(L10n.tr("crm.field_notes"), notes)
                    }
                }
            }
            .navigationTitle(CRMContactDisplay.localizedName(contact))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("crm.action_edit_contact")) { showEdit = true }
                        .opacity(canEditContact ? 1 : 0)
                        .disabled(!canEditContact)
                        .allowsHitTesting(canEditContact)
                }
            }
            .sheet(isPresented: $showEdit) {
                CRMContactFormView(access: access, existing: contact) {
                    await onChanged()
                    dismiss()
                }
            }
        }
    }

    private var canEditContact: Bool {
        access.canEdit && !contact.isFromERP
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(AppColors.secondary)
            Text(value)
        }
        .padding(.vertical, 2)
    }

    private func localizedPosition(_ position: String) -> String {
        if position == "Contact principal" {
            return L10n.tr("crm.contact_position_primary")
        }
        return position
    }
}

struct CRMContactFormView: View {
    let access: ModuleAccessRights
    var existing: CRMContact?
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var position = ""
    @State private var notes = ""
    @State private var crmCompanies: [CRMCompany] = []
    @State private var selectedCRMCompanyId: UUID?
    @State private var assignableUsers: [UserProfile] = []
    @State private var assignedTo: UUID?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                if let erpCompany = companyManager.currentCompany {
                    Section {
                        Text(L10n.tr("crm.manual_scope_company", erpCompany.denumire))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                Section(L10n.tr("crm.section_contact")) {
                    TextField(L10n.tr("crm.field_first_name"), text: $firstName)
                    TextField(L10n.tr("crm.field_last_name"), text: $lastName)
                    Picker(L10n.tr("crm.field_crm_company"), selection: $selectedCRMCompanyId) {
                        Text("—").tag(UUID?.none)
                        ForEach(crmCompanies) { company in
                            Text(company.name).tag(Optional(company.id))
                        }
                    }
                    TextField(L10n.tr("crm.field_position"), text: $position)
                    TextField(L10n.tr("crm.field_email"), text: $email).keyboardType(.emailAddress)
                    TextField(L10n.tr("crm.field_phone"), text: $phone).keyboardType(.phonePad)
                }
                Section(L10n.tr("crm.field_notes")) {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                if !assignableUsers.isEmpty {
                    Section {
                        CRMAssigneePicker(selectedUserId: $assignedTo, users: assignableUsers)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle(existing == nil ? L10n.tr("crm.contact_create_title") : L10n.tr("crm.action_edit_contact"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            && firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { populate() }
            .appTask { await loadReferenceData() }
        }
    }

    private func populate() {
        guard let existing else { return }
        firstName = existing.firstName
        lastName = existing.lastName
        email = existing.email ?? ""
        phone = existing.phone ?? ""
        position = existing.position ?? ""
        notes = existing.notes ?? ""
        selectedCRMCompanyId = existing.crmCompanyId
        assignedTo = existing.assignedTo
    }

    private func loadReferenceData() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            crmCompanies = try await CRMExtendedService.fetchCRMCompanies(companyId: companyId)
            assignableUsers = await CRMUserDirectory.fetchAssignableUsers(
                companyId: companyId,
                currentProfile: session.currentProfile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            if var item = existing {
                item.firstName = firstName
                item.lastName = lastName
                item.crmCompanyId = selectedCRMCompanyId
                item.email = trimmedOptional(email)
                item.phone = trimmedOptional(phone)
                item.position = trimmedOptional(position)
                item.notes = trimmedOptional(notes)
                item.assignedTo = assignedTo
                try await CRMExtendedService.updateCRMContact(item)
            } else {
                _ = try await CRMExtendedService.createCRMContact(
                    companyId: companyId,
                    firstName: firstName,
                    lastName: lastName,
                    crmCompanyId: selectedCRMCompanyId,
                    email: trimmedOptional(email),
                    phone: trimmedOptional(phone),
                    position: trimmedOptional(position),
                    notes: trimmedOptional(notes),
                    assignedTo: assignedTo,
                    createdBy: session.currentProfile?.id
                )
            }
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmedOptional(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Oferte

struct CRMQuotesListView: View {
    let access: ModuleAccessRights

    @State private var quotes: [CRMQuote] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var selected: CRMQuote?
    @State private var showOpenOnly = true
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var filtered: [CRMQuote] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return quotes.filter { quote in
            if showOpenOnly && !quote.status.isOpen { return false }
            guard !q.isEmpty else { return true }
            return quote.title.localizedCaseInsensitiveContains(q) || quote.quoteNumber.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(L10n.tr("crm.show_open_quotes_only"), isOn: $showOpenOnly).padding()
            if filtered.isEmpty && !isLoading {
                AppEmptyStateView(L10n.tr("crm.no_quotes"), systemImage: "doc.text",
                                  description: Text(L10n.tr("crm.no_quotes_create")))
            } else {
                List {
                    ForEach(filtered) { quote in
                        Button { selected = quote } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quote.quoteNumber).font(.caption.bold()).foregroundColor(AppColors.secondary)
                                    Text(quote.title).font(.subheadline.weight(.semibold))
                                    Text(quote.status.label).font(.caption).foregroundColor(.blue)
                                }
                                Spacer()
                                Text(SupplierFormatting.currency(quote.totalAmount, code: quote.currency))
                                    .font(.caption.bold())
                            }.padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_quotes"))
            }
        }
        .floatingBottomTrailing {
            if access.canCreate {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill").font(.system(size: 44)).appSymbolRenderingMode(.hierarchical)
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .sheet(isPresented: $showCreate) { CRMQuoteFormView(access: access) { await reload() } }
        .fullScreenCover(item: $selected) { quote in
            CRMQuoteDetailView(quote: quote, access: access) { await reload() }
        }
        .crmErrorFooter(errorMessage)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            quotes = try await CRMExtendedService.fetchQuotes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        Task {
            do {
                for i in offsets {
                    try await CRMExtendedService.deleteQuote(id: filtered[i].id)
                }
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CRMQuoteFormView: View {
    let access: ModuleAccessRights
    var presetLead: CRMLead?
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var title = ""
    @State private var status: CRMQuoteStatus = .draft
    @State private var hasValidUntil = false
    @State private var validUntil = Date()
    @State private var notes = ""
    @State private var errorMessage: String?

    init(access: ModuleAccessRights, presetLead: CRMLead? = nil, onSaved: @escaping () async -> Void) {
        self.access = access
        self.presetLead = presetLead
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationView {
            Form {
                TextField(L10n.tr("crm.field_quote_title"), text: $title)
                Picker(L10n.tr("crm.field_status"), selection: $status) {
                    ForEach(CRMQuoteStatus.allCases) { s in Text(s.label).tag(s) }
                }
                Toggle(L10n.tr("crm.field_valid_until"), isOn: $hasValidUntil)
                if hasValidUntil { AppDatePicker(selection: $validUntil) }
                Section(L10n.tr("crm.field_notes")) { TextEditor(text: $notes).frame(minHeight: 80) }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle(L10n.tr("crm.quote_create_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let presetLead { title = presetLead.title }
            }
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            _ = try await CRMExtendedService.createQuote(
                companyId: companyId, title: title,
                leadId: presetLead?.id, crmCompanyId: presetLead?.crmCompanyId,
                crmContactId: presetLead?.crmContactId, status: status,
                validUntil: hasValidUntil ? validUntil : nil, notes: notes,
                createdBy: session.currentProfile?.id
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CRMQuoteDetailView: View {
    let quote: CRMQuote
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var currentQuote: CRMQuote
    @State private var lines: [CRMQuoteLine] = []
    @State private var showAddLine = false
    @State private var lineDescription = ""
    @State private var lineQty = "1"
    @State private var linePrice = ""
    @State private var errorMessage: String?

    init(quote: CRMQuote, access: ModuleAccessRights, onChanged: @escaping () async -> Void) {
        self.quote = quote; self.access = access; self.onChanged = onChanged
        _currentQuote = State(initialValue: quote)
    }

    var body: some View {
        NavigationView {
            List {
                Section(L10n.tr("crm.section_quote")) {
                    detail(L10n.tr("crm.field_quote_number"), currentQuote.quoteNumber)
                    detail(L10n.tr("crm.field_quote_title"), currentQuote.title)
                    detail(L10n.tr("crm.field_status"), currentQuote.status.label)
                    detail(L10n.tr("crm.field_amount"), SupplierFormatting.currency(currentQuote.totalAmount, code: currentQuote.currency))
                }
                Section(L10n.tr("crm.section_quote_lines")) {
                    if lines.isEmpty {
                        Text(L10n.tr("crm.no_quote_lines")).foregroundColor(AppColors.secondary)
                    } else {
                        ForEach(lines) { line in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(line.lineDescription).font(.subheadline)
                                    Text(SupplierFormatting.currency(line.lineTotal)).font(.caption.bold())
                                }
                                Spacer()
                            }
                        }
                        .onDelete(perform: access.canEdit ? deleteLines : { _ in })
                    }
                    if access.canCreate {
                        Button(L10n.tr("crm.add_quote_line")) { showAddLine = true }
                    }
                }
                if access.canEdit {
                    Section(L10n.tr("crm.section_actions")) {
                        ForEach(CRMQuoteStatus.allCases) { status in
                            if status != currentQuote.status {
                                Button(status.label) { Task { await updateStatus(status) } }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("crm.quote_detail_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.back")) { dismiss() } }
            }
            .appTask { await reload() }
            .sheet(isPresented: $showAddLine) {
                NavigationView {
                    Form {
                        TextField(L10n.tr("crm.field_description"), text: $lineDescription)
                        TextField(L10n.tr("crm.field_quantity"), text: $lineQty).keyboardType(.decimalPad)
                        TextField(L10n.tr("crm.field_unit_price"), text: $linePrice).keyboardType(.decimalPad)
                        if let errorMessage {
                            Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                        }
                    }
                    .navigationTitle(L10n.tr("crm.add_quote_line"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("common.cancel")) { showAddLine = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.tr("common.save")) { Task { await addLine() } }
                                .disabled(lineDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .crmErrorFooter(errorMessage)
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(AppColors.secondary)
            Text(value)
        }
    }

    private func reload() async {
        errorMessage = nil
        do {
            lines = try await CRMExtendedService.fetchQuoteLines(quoteId: quote.id)
            let rows = try await CRMExtendedService.fetchQuotes()
            if let fresh = rows.first(where: { $0.id == quote.id }) {
                currentQuote = fresh
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addLine() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        let qty = SupplierFormatting.parseAmount(lineQty) ?? 1
        let price = SupplierFormatting.parseAmount(linePrice) ?? 0
        errorMessage = nil
        do {
            _ = try await CRMExtendedService.addQuoteLine(
                companyId: companyId, quoteId: quote.id, description: lineDescription,
                quantity: qty, unitPrice: price, sortOrder: lines.count
            )
            try await CRMExtendedService.recalculateQuoteTotal(quoteId: quote.id, companyId: companyId)
            lineDescription = ""; lineQty = "1"; linePrice = ""
            showAddLine = false
            await reload(); await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteLines(at offsets: IndexSet) {
        guard let companyId = companyManager.currentCompany?.id else { return }
        Task {
            do {
                for i in offsets { try await CRMExtendedService.deleteQuoteLine(id: lines[i].id) }
                try await CRMExtendedService.recalculateQuoteTotal(quoteId: quote.id, companyId: companyId)
                await reload(); await onChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updateStatus(_ status: CRMQuoteStatus) async {
        currentQuote.status = status
        do {
            try await CRMExtendedService.updateQuote(currentQuote)
            await reload(); await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Analiză

struct CRMAnalyticsView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var analytics = CRMAnalyticsSummary()
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metric(L10n.tr("crm.metric.pipeline_value"), SupplierFormatting.currency(analytics.dealSummary.pipelineValue), .blue)
                    metric(L10n.tr("crm.metric.weighted_pipeline"), SupplierFormatting.currency(analytics.weightedPipeline), .indigo)
                    metric(L10n.tr("crm.metric.win_rate"), "\(analytics.winRatePercent)%", .green)
                    metric(L10n.tr("crm.metric.open_leads"), "\(analytics.openLeadsCount)", .orange)
                    metric(L10n.tr("crm.metric.contacts"), "\(analytics.contactsCount)", .purple)
                    metric(L10n.tr("crm.metric.crm_companies"), "\(analytics.companiesCount)", .teal)
                    metric(L10n.tr("crm.metric.open_quotes"), "\(analytics.openQuotesCount)", .cyan)
                    metric(L10n.tr("crm.metric.active_tickets_label"), "\(analytics.ticketSummary.activeCount)", .pink)
                }

                Text(L10n.tr("crm.funnel_title")).font(.headline)
                ForEach(analytics.funnel.filter { $0.stage != .lost }) { stage in
                    HStack {
                        Text(stage.stage.label).font(.caption).frame(width: 110, alignment: .leading)
                        GeometryReader { geo in
                            let maxCount = max(analytics.funnel.map(\.count).max() ?? 1, 1)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(CRMDealStageColors.background(for: stage.stage))
                                .frame(width: geo.size.width * CGFloat(stage.count) / CGFloat(maxCount), height: 18)
                        }.frame(height: 18)
                        Text("\(stage.count)").font(.caption.bold()).frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding()
        }
        .appScrollBottomPadding()
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: companyManager.currentCompany?.id) { await reload() }
        .appRefreshable { await reload() }
        .crmErrorFooter(errorMessage)
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(AppColors.secondary)
            Text(value).font(.title3.bold()).foregroundColor(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let companyId = companyManager.currentCompany?.id else {
            analytics = CRMAnalyticsSummary()
            return
        }
        do {
            async let leads = CRMLeadService.fetchLeads()
            async let tickets = CRMService.fetchTickets()
            async let quotes = CRMExtendedService.fetchQuotes()
            async let contacts = CRMExtendedService.fetchCRMContacts(companyId: companyId)
            async let companies = CRMExtendedService.fetchCRMCompanies(companyId: companyId)
            analytics = CRMExtendedService.buildAnalytics(
                leads: try await leads, tickets: try await tickets, quotes: try await quotes,
                contacts: try await contacts, crmCompanies: try await companies
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Produse pe tranzacție

struct CRMDealProductsSection: View {
    let access: ModuleAccessRights
    let lead: CRMLead
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager

    @State private var products: [CRMDealProduct] = []
    @State private var catalog: [Product] = []
    @State private var showAdd = false
    @State private var description = ""
    @State private var quantity = "1"
    @State private var unitPrice = ""
    @State private var selectedProductId: UUID?
    @State private var errorMessage: String?

    var body: some View {
        Section(L10n.tr("crm.section_products")) {
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundColor(.red)
            }
            if products.isEmpty {
                Text(L10n.tr("crm.no_products")).foregroundColor(AppColors.secondary)
            } else {
                ForEach(products) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.lineDescription).font(.subheadline)
                            Text(SupplierFormatting.currency(item.lineTotal)).font(.caption.bold())
                        }
                        Spacer()
                    }
                }
                .onDelete(perform: access.canDelete ? deleteItems : { _ in })
            }
            if !products.isEmpty {
                HStack {
                    Text(L10n.tr("crm.field_total")).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(SupplierFormatting.currency(CRMExtendedService.dealProductsTotal(products))).font(.subheadline.bold())
                }
            }
            if access.canCreate {
                Button(L10n.tr("crm.add_product")) { showAdd = true }
            }
        }
        .appTask {
            await loadProducts()
        }
        .sheet(isPresented: $showAdd) {
            NavigationView {
                Form {
                    Picker(L10n.tr("crm.field_product"), selection: $selectedProductId) {
                        Text("—").tag(UUID?.none)
                        ForEach(catalog) { p in Text(p.denumire).tag(Optional(p.id)) }
                    }
                    .onChange(of: selectedProductId) { id in
                        guard let id, let product = catalog.first(where: { $0.id == id }) else { return }
                        description = product.denumire
                        unitPrice = SupplierFormatting.amountString(product.pretVanzare)
                    }
                    TextField(L10n.tr("crm.field_description"), text: $description)
                    TextField(L10n.tr("crm.field_quantity"), text: $quantity).keyboardType(.decimalPad)
                    TextField(L10n.tr("crm.field_unit_price"), text: $unitPrice).keyboardType(.decimalPad)
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundColor(.red).font(.caption) }
                    }
                }
                .navigationTitle(L10n.tr("crm.add_product"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("common.cancel")) { showAdd = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("common.save")) { Task { await addProduct() } }
                            .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func loadProducts() async {
        errorMessage = nil
        do {
            products = try await CRMExtendedService.fetchDealProducts(leadId: lead.id)
            if let companyId = companyManager.currentCompany?.id {
                catalog = try await ProductService.fetchProducts(companyId: companyId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addProduct() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            _ = try await CRMExtendedService.createDealProduct(
                companyId: companyId, leadId: lead.id, description: description,
                productId: selectedProductId,
                quantity: SupplierFormatting.parseAmount(quantity) ?? 1,
                unitPrice: SupplierFormatting.parseAmount(unitPrice) ?? 0
            )
            products = try await CRMExtendedService.fetchDealProducts(leadId: lead.id)
            showAdd = false
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        Task {
            do {
                for i in offsets { try await CRMExtendedService.deleteDealProduct(id: products[i].id) }
                products = try await CRMExtendedService.fetchDealProducts(leadId: lead.id)
                await onChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CRMAssigneePicker: View {
    @Binding var selectedUserId: UUID?
    let users: [UserProfile]

    var body: some View {
        Picker(L10n.tr("crm.field_assigned_to"), selection: $selectedUserId) {
            Text("—").tag(UUID?.none)
            ForEach(users) { user in
                Text(user.fullName).tag(Optional(user.id))
            }
        }
    }
}
