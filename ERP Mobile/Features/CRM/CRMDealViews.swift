import SwiftUI

struct CRMDealListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var session: SessionManager

    @State private var leads: [CRMLead] = []
    @State private var selectedStage: CRMLeadStage?
    @State private var showOpenOnly = true
    @State private var showMyOnly = false
    @State private var selectedSource: CRMLeadSource?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var selectedLead: CRMLead?
    @State private var searchText = ""

    private var filteredLeads: [CRMLead] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return leads.filter { lead in
            if showOpenOnly && lead.stage.isClosed { return false }
            if showMyOnly, let uid = session.currentProfile?.id, lead.assignedTo != uid { return false }
            if let selectedSource, lead.source != selectedSource { return false }
            if let selectedStage, lead.stage != selectedStage { return false }
            guard !query.isEmpty else { return true }
            return lead.title.localizedCaseInsensitiveContains(query)
                || (lead.organizationName ?? "").localizedCaseInsensitiveContains(query)
        }
        .sorted { $0.updatedAt ?? .distantPast > $1.updatedAt ?? .distantPast }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Group {
                if filteredLeads.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("crm.no_deals"),
                        systemImage: "list.bullet.rectangle",
                        description: Text(access.canCreate ? L10n.tr("crm.no_deals_create") : L10n.tr("crm.no_deals_readonly"))
                    )
                } else {
                    List {
                        ForEach(filteredLeads) { lead in
                            Button {
                                selectedLead = lead
                            } label: {
                                CRMDealRowView(lead: lead)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                    }
                    .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_deals"))
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
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .fullScreenCover(isPresented: $showCreate) {
            CRMDealFormView(access: access, presetStage: .new) { await reload() }
        }
        .fullScreenCover(item: $selectedLead) { lead in
            CRMDealDetailView(lead: lead, access: access) { await reload() }
        }
        .crmErrorFooter(errorMessage)
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Toggle(L10n.tr("crm.show_open_deals_only"), isOn: $showOpenOnly)
                .padding(.horizontal)
            Toggle(L10n.tr("crm.show_my_items_only"), isOn: $showMyOnly)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    stageChip(title: L10n.tr("common.all"), stage: nil)
                    ForEach(CRMLeadStage.kanbanOrder) { stage in
                        stageChip(title: stage.label, stage: stage)
                    }
                }
                .padding(.horizontal)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    sourceChip(title: L10n.tr("common.all"), source: nil)
                    ForEach(CRMLeadSource.allCases) { source in
                        sourceChip(title: source.label, source: source)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func sourceChip(title: String, source: CRMLeadSource?) -> some View {
        Button { selectedSource = source } label: {
            Text(title)
                .font(.caption.weight(selectedSource == source ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedSource == source ? AppColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func stageChip(title: String, stage: CRMLeadStage?) -> some View {
        Button {
            selectedStage = stage
        } label: {
            Text(title)
                .font(.caption.weight(selectedStage == stage ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(selectedStage == stage ? AppColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            leads = try await CRMLeadService.fetchLeads(pipelineType: .deal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let ids = offsets.map { filteredLeads[$0].id }
        Task {
            do {
                for id in ids {
                    try await CRMLeadService.deleteLead(id: id)
                }
                NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CRMDealRowView: View {
    let lead: CRMLead

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lead.title)
                    .font(.subheadline.weight(.semibold))
                if !lead.displaySubtitle.isEmpty {
                    Text(lead.displaySubtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(SupplierFormatting.currency(lead.estimatedValue, code: lead.currency))
                    .font(.caption.bold())
                Text(lead.stage.label)
                    .font(.caption2.bold())
                    .foregroundColor(CRMDealStageColors.foreground(for: lead.stage))
            }
        }
        .padding(.vertical, 4)
    }
}

struct CRMDealDetailView: View {
    let lead: CRMLead
    let access: ModuleAccessRights
    var allowsConvert = false
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var currentLead: CRMLead
    @State private var activities: [CRMActivity] = []
    @State private var clientName: String?
    @State private var assigneeName: String?
    @State private var assignableUsers: [UserProfile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEdit = false
    @State private var showAddActivity = false
    @State private var showCreateQuote = false

    init(lead: CRMLead, access: ModuleAccessRights, allowsConvert: Bool = false, onChanged: @escaping () async -> Void) {
        self.lead = lead
        self.access = access
        self.allowsConvert = allowsConvert
        self.onChanged = onChanged
        _currentLead = State(initialValue: lead)
    }

    var body: some View {
        NavigationView {
            List {
                Section(L10n.tr("crm.section_deal")) {
                    detailRow(L10n.tr("crm.field_deal_title"), currentLead.title)
                    detailRow(L10n.tr("crm.field_stage"), currentLead.stage.label)
                    detailRow(L10n.tr("crm.field_amount"), SupplierFormatting.currency(currentLead.estimatedValue, code: currentLead.currency))
                    detailRow(L10n.tr("crm.field_probability"), "\(currentLead.probability)%")
                    if let date = currentLead.expectedCloseDate {
                        detailRow(L10n.tr("crm.field_expected_close"), SupplierFormatting.date(date))
                    }
                    detailRow(L10n.tr("crm.field_source"), currentLead.source.label)
                    if let org = currentLead.organizationName, !org.isEmpty {
                        detailRow(L10n.tr("crm.field_organization"), org)
                    }
                    if let contact = currentLead.contactName, !contact.isEmpty {
                        detailRow(L10n.tr("crm.field_contact"), contact)
                    }
                    if let clientName {
                        detailRow(L10n.tr("crm.field_client"), clientName)
                    }
                    if let assigneeName {
                        detailRow(L10n.tr("crm.field_assigned_to"), assigneeName)
                    }
                    if let notes = currentLead.notes, !notes.isEmpty {
                        detailRow(L10n.tr("crm.field_notes"), notes)
                    }
                }

                if currentLead.isDeal {
                    CRMDealProductsSection(access: access, lead: currentLead) { await reload() }
                }

                if access.canEdit {
                    Section(L10n.tr("crm.section_actions")) {
                        if allowsConvert && currentLead.isLead {
                            Button(L10n.tr("crm.action_convert_to_deal")) {
                                Task { await convertToDeal() }
                            }
                        }
                        if currentLead.isDeal {
                            Button(L10n.tr("crm.action_create_quote")) { showCreateQuote = true }
                        }
                        Menu(L10n.tr("crm.action_move_stage")) {
                            ForEach(CRMLeadStage.kanbanOrder) { stage in
                                if stage != currentLead.stage {
                                    Button(stage.label) {
                                        Task { await moveTo(stage) }
                                    }
                                }
                            }
                        }
                        if access.canEdit {
                            Button(L10n.tr("crm.action_edit_deal")) { showEdit = true }
                        }
                    }
                }

                Section(L10n.tr("crm.section_activities")) {
                    if activities.isEmpty {
                        Text(L10n.tr("crm.no_activities"))
                            .foregroundColor(AppColors.secondary)
                    } else {
                        ForEach(activities) { activity in
                            CRMActivityRowView(
                                activity: activity,
                                canComplete: access.canEdit && !activity.isCompleted,
                                onComplete: { Task { await completeActivity(activity) } }
                            )
                        }
                    }
                    if access.canCreate {
                        Button(L10n.tr("crm.add_activity")) { showAddActivity = true }
                    }
                }
            }
            .navigationTitle(currentLead.isLead ? L10n.tr("crm.lead_detail_title") : L10n.tr("crm.deal_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { dismiss() }
                }
            }
            .appTask { await reload() }
            .fullScreenCover(isPresented: $showEdit) {
                CRMDealFormView(access: access, existing: currentLead) {
                    await reload()
                    await onChanged()
                }
            }
            .sheet(isPresented: $showAddActivity) {
                CRMActivityFormView(access: access, lead: currentLead) {
                    await reload()
                }
            }
            .sheet(isPresented: $showCreateQuote) {
                CRMQuoteFormView(access: access, presetLead: currentLead) {
                    await onChanged()
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .crmErrorFooter(errorMessage)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(AppColors.secondary)
            Text(value).font(.body)
        }
        .padding(.vertical, 2)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let fresh = try await CRMLeadService.fetchLead(id: lead.id) {
                currentLead = fresh
            }
            activities = try await CRMLeadService.fetchActivities(leadId: lead.id)
            assignableUsers = await CRMUserDirectory.fetchAssignableUsers(
                companyId: companyManager.currentCompany?.id,
                currentProfile: session.currentProfile
            )
            assigneeName = CRMUserDirectory.displayName(for: currentLead.assignedTo, in: assignableUsers)
            if let clientId = currentLead.clientId {
                let clients = try await ClientService.fetchClients()
                clientName = clients.first(where: { $0.id == clientId })?.denumire
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeActivity(_ activity: CRMActivity) async {
        do {
            try await CRMLeadService.completeActivity(activity)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func convertToDeal() async {
        do {
            currentLead = try await CRMLeadService.convertLeadToDeal(currentLead)
            NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveTo(_ stage: CRMLeadStage) async {
        do {
            currentLead = try await CRMLeadService.updateLeadStage(id: currentLead.id, to: stage)
            NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CRMDealFormView: View {
    let access: ModuleAccessRights
    var existing: CRMLead?
    var presetStage: CRMLeadStage = .new
    var pipelineType: CRMPipelineType = .deal
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var title = ""
    @State private var organizationName = ""
    @State private var contactName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var stage: CRMLeadStage = .new
    @State private var source: CRMLeadSource = .other
    @State private var amountText = ""
    @State private var probability = 10
    @State private var expectedCloseDate = Date()
    @State private var hasExpectedClose = false
    @State private var notes = ""
    @State private var clients: [Client] = []
    @State private var crmCompanies: [CRMCompany] = []
    @State private var crmContacts: [CRMContact] = []
    @State private var assignableUsers: [UserProfile] = []
    @State private var selectedClientId: UUID?
    @State private var selectedCRMCompanyId: UUID?
    @State private var selectedCRMContactId: UUID?
    @State private var selectedAssigneeId: UUID?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(L10n.tr("crm.section_deal")) {
                    TextField(L10n.tr("crm.field_deal_title"), text: $title)
                    Picker(L10n.tr("crm.field_stage"), selection: $stage) {
                        ForEach(CRMLeadStage.kanbanOrder) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    Picker(L10n.tr("crm.field_source"), selection: $source) {
                        ForEach(CRMLeadSource.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    TextField(L10n.tr("crm.field_amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                    Stepper(L10n.tr("crm.field_probability") + ": \(probability)%", value: $probability, in: 0...100, step: 5)
                    Toggle(L10n.tr("crm.field_expected_close"), isOn: $hasExpectedClose)
                    if hasExpectedClose {
                        AppDatePicker(selection: $expectedCloseDate)
                    }
                }
                Section(L10n.tr("crm.section_contact")) {
                    Picker(L10n.tr("crm.field_crm_company"), selection: $selectedCRMCompanyId) {
                        Text("—").tag(UUID?.none)
                        ForEach(crmCompanies) { c in Text(c.name).tag(Optional(c.id)) }
                    }
                    Picker(L10n.tr("crm.field_crm_contact"), selection: $selectedCRMContactId) {
                        Text("—").tag(UUID?.none)
                        ForEach(crmContacts) { c in Text(CRMContactDisplay.localizedName(c)).tag(Optional(c.id)) }
                    }
                    TextField(L10n.tr("crm.field_organization"), text: $organizationName)
                    TextField(L10n.tr("crm.field_contact"), text: $contactName)
                    TextField(L10n.tr("crm.field_email"), text: $email)
                        .keyboardType(.emailAddress)
                    TextField(L10n.tr("crm.field_phone"), text: $phone)
                        .keyboardType(.phonePad)
                    Picker(L10n.tr("crm.field_client"), selection: $selectedClientId) {
                        Text("—").tag(UUID?.none)
                        ForEach(clients) { client in
                            Text(client.denumire).tag(Optional(client.id))
                        }
                    }
                    CRMAssigneePicker(selectedUserId: $selectedAssigneeId, users: assignableUsers)
                }
                Section(L10n.tr("crm.field_notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(existing == nil
                ? (pipelineType == .lead ? L10n.tr("crm.lead_create_title") : L10n.tr("crm.deal_create_title"))
                : L10n.tr("crm.action_edit_deal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear { populate() }
            .appTask { await loadReferenceData() }
            .onChange(of: selectedCRMCompanyId) { companyId in
                guard let companyId, let company = crmCompanies.first(where: { $0.id == companyId }) else { return }
                organizationName = company.name
                if selectedClientId == nil { selectedClientId = company.clientId }
            }
            .onChange(of: selectedCRMContactId) { contactId in
                guard let contactId, let contact = crmContacts.first(where: { $0.id == contactId }) else { return }
                contactName = CRMContactDisplay.localizedName(contact)
                email = contact.email ?? ""
                phone = contact.phone ?? ""
                selectedCRMCompanyId = contact.crmCompanyId
                if selectedClientId == nil { selectedClientId = contact.clientId }
            }
            .crmErrorFooter(errorMessage)
        }
    }

    private func populate() {
        stage = presetStage
        guard let existing else { return }
        title = existing.title
        organizationName = existing.organizationName ?? ""
        contactName = existing.contactName ?? ""
        email = existing.email ?? ""
        phone = existing.phone ?? ""
        stage = existing.stage
        source = existing.source
        amountText = SupplierFormatting.amountString(existing.estimatedValue)
        probability = existing.probability
        if let close = existing.expectedCloseDate {
            hasExpectedClose = true
            expectedCloseDate = close
        }
        notes = existing.notes ?? ""
        selectedClientId = existing.clientId
        selectedCRMCompanyId = existing.crmCompanyId
        selectedCRMContactId = existing.crmContactId
        selectedAssigneeId = existing.assignedTo
    }

    private func loadReferenceData() async {
        errorMessage = nil
        do {
            async let clientsTask = ClientService.fetchClients()
            async let companiesTask = CRMExtendedService.fetchCRMCompaniesFromERP(
                companyId: companyManager.currentCompany?.id
            )
            async let contactsTask = CRMExtendedService.fetchCRMContactsFromERP(
                companyId: companyManager.currentCompany?.id
            )
            clients = try await clientsTask
            crmCompanies = try await companiesTask
            crmContacts = try await contactsTask
            assignableUsers = await CRMUserDirectory.fetchAssignableUsers(
                companyId: companyManager.currentCompany?.id,
                currentProfile: session.currentProfile
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let amount = SupplierFormatting.parseAmount(amountText) ?? 0
        do {
            if let base = existing {
                var updated = base
                updated.title = title
                updated.organizationName = organizationName
                updated.contactName = contactName
                updated.email = email
                updated.phone = phone
                updated.stage = stage
                updated.source = source
                updated.estimatedValue = amount
                updated.probability = probability
                updated.expectedCloseDate = hasExpectedClose ? expectedCloseDate : nil
                updated.notes = notes
                updated.clientId = selectedClientId
                updated.crmCompanyId = selectedCRMCompanyId
                updated.crmContactId = selectedCRMContactId
                updated.assignedTo = selectedAssigneeId
                try await CRMLeadService.updateLead(updated)
            } else {
                _ = try await CRMLeadService.createLead(
                    companyId: companyId,
                    title: title,
                    pipelineType: pipelineType,
                    stage: stage,
                    organizationName: organizationName,
                    contactName: contactName,
                    email: email,
                    phone: phone,
                    source: source,
                    estimatedValue: amount,
                    probability: probability,
                    expectedCloseDate: hasExpectedClose ? expectedCloseDate : nil,
                    clientId: selectedClientId,
                    crmCompanyId: selectedCRMCompanyId,
                    crmContactId: selectedCRMContactId,
                    notes: notes,
                    assignedTo: selectedAssigneeId,
                    createdBy: session.currentProfile?.id
                )
            }
            NotificationCenter.default.post(name: .crmLeadsDidChange, object: nil)
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CRMActivitiesListView: View {
    let access: ModuleAccessRights

    @State private var activities: [CRMActivity] = []
    @State private var leadsById: [UUID: CRMLead] = [:]
    @State private var showOpenOnly = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var filtered: [CRMActivity] {
        showOpenOnly ? activities.filter { !$0.isCompleted } : activities
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle(L10n.tr("crm.show_open_activities_only"), isOn: $showOpenOnly)
                .padding()
            if filtered.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("crm.no_activities"),
                    systemImage: "calendar",
                    description: Text(L10n.tr("crm.no_activities_hint"))
                )
            } else {
                List {
                    ForEach(filtered) { activity in
                        CRMActivityRowView(
                            activity: activity,
                            dealTitle: activity.leadId.flatMap { leadsById[$0]?.title },
                            canComplete: access.canEdit && !activity.isCompleted,
                            onComplete: { Task { await complete(activity) } }
                        )
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .crmErrorFooter(errorMessage)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            activities = try await CRMLeadService.fetchActivities()
            let leads = try await CRMLeadService.fetchLeads()
            leadsById = Dictionary(uniqueKeysWithValues: leads.map { ($0.id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func complete(_ activity: CRMActivity) async {
        do {
            try await CRMLeadService.completeActivity(activity)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CRMActivityRowView: View {
    let activity: CRMActivity
    var dealTitle: String?
    var canComplete = false
    var onComplete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.activityType.systemImage)
                .foregroundColor(activity.isCompleted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.subject)
                    .font(.subheadline.weight(.semibold))
                Text(activity.activityType.label)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                if let dealTitle {
                    Text(dealTitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
                if let due = activity.dueAt {
                    Text(SupplierFormatting.dateTime(due))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
            }
            Spacer()
            if activity.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if canComplete {
                Button(action: { onComplete?() }) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CRMActivityFormView: View {
    let access: ModuleAccessRights
    let lead: CRMLead
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var activityType: CRMActivityType = .call
    @State private var subject = ""
    @State private var description = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Picker(L10n.tr("crm.field_activity_type"), selection: $activityType) {
                    ForEach(CRMActivityType.allCases) { type in
                        Label(type.label, systemImage: type.systemImage).tag(type)
                    }
                }
                TextField(L10n.tr("crm.field_subject"), text: $subject)
                MultilineTextField(placeholder: L10n.tr("crm.field_description"), text: $description, minHeight: 88)
                Toggle(L10n.tr("crm.field_due_date"), isOn: $hasDueDate)
                if hasDueDate {
                    AppDatePicker(selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.tr("crm.add_activity"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil
        do {
            _ = try await CRMLeadService.createActivity(
                companyId: companyId,
                leadId: lead.id,
                clientId: lead.clientId,
                activityType: activityType,
                subject: subject,
                description: description,
                dueAt: hasDueDate ? dueDate : nil,
                createdBy: session.currentProfile?.id
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
