import SwiftUI

struct CRMTicketsListView: View {
    let access: ModuleAccessRights
    var clientIdFilter: UUID? = nil
    var clientNameFilter: String? = nil

    @State private var tickets: [CRMTicket] = []
    @State private var clientNames: [UUID: String] = [:]
    @State private var selectedStatus: CRMTicketStatus?
    @State private var showOpenOnly = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var selectedTicket: CRMTicket?
    @State private var ticketToDelete: CRMTicket?
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var filteredTickets: [CRMTicket] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return tickets.filter { ticket in
            if showOpenOnly && (ticket.status.isClosed) {
                return false
            }
            if let selectedStatus, ticket.status != selectedStatus {
                return false
            }
            guard !query.isEmpty else { return true }
            let clientName = clientNames[ticket.clientId] ?? ""
            return ticket.ticketNumber.localizedCaseInsensitiveContains(query)
                || ticket.subject.localizedCaseInsensitiveContains(query)
                || clientName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if clientIdFilter == nil {
                filterBar
            }

            Group {
                if filteredTickets.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("crm.no_tickets"),
                        systemImage: "ticket",
                        description: Text(access.canCreate ? L10n.tr("crm.no_tickets_create") : L10n.tr("crm.no_tickets_readonly"))
                    )
                } else {
                    List {
                        ForEach(filteredTickets) { ticket in
                            Button {
                                selectedTicket = ticket
                            } label: {
                                CRMTicketRowView(ticket: ticket, clientName: clientNames[ticket.clientId])
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                    }
                    .appSearchable(text: $searchText, prompt: L10n.tr("crm.search_tickets"))
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
        .crmErrorFooter(errorMessage)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .fullScreenCover(isPresented: $showCreate) {
            CRMTicketFormView(
                access: access,
                preselectedClientId: clientIdFilter,
                preselectedClientName: clientNameFilter
            ) {
                await reload()
            }
        }
        .fullScreenCover(item: $selectedTicket) { ticket in
            CRMTicketDetailView(ticket: ticket, access: access, clientName: clientNames[ticket.clientId]) {
                await reload()
            }
        }
        .alert(L10n.tr("crm.delete_ticket_title"), isPresented: $showDeleteConfirm, presenting: ticketToDelete) { ticket in
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { await deleteTicket(ticket) }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: { ticket in
            Text(L10n.tr("crm.delete_ticket_confirm", ticket.ticketNumber))
        }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Toggle(L10n.tr("crm.show_open_only"), isOn: $showOpenOnly)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(title: L10n.tr("common.all"), status: nil)
                    ForEach(CRMTicketStatus.allCases) { status in
                        statusChip(title: status.label, status: status)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    private func statusChip(title: String, status: CRMTicketStatus?) -> some View {
        Button {
            selectedStatus = status
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedStatus == status ? Color.accentColor.opacity(0.18) : Color(UIColor.secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            tickets = try await CRMService.fetchTickets(clientId: clientIdFilter)
            let clients = try await ClientService.fetchClients()
            clientNames = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.denumire) })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        ticketToDelete = filteredTickets[index]
        showDeleteConfirm = true
    }

    private func deleteTicket(_ ticket: CRMTicket) async {
        isLoading = true
        errorMessage = nil
        do {
            try await CRMService.deleteTicket(id: ticket.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CRMTicketRowView: View {
    let ticket: CRMTicket
    let clientName: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ticket.ticketNumber)
                    .font(.caption.bold())
                    .foregroundColor(AppColors.secondary)
                Text(ticket.subject)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                if let clientName, !clientName.isEmpty {
                    Text(clientName)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                HStack(spacing: 8) {
                    statusBadge
                    Text(ticket.priority.label)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
            }
            Spacer(minLength: 8)
            if let updatedAt = ticket.updatedAt {
                Text(SupplierFormatting.compactDate(updatedAt))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(ticket.status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundColor(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch ticket.status {
        case .open: return .blue
        case .inProgress: return .orange
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

struct CRMTicketFormView: View {
    let access: ModuleAccessRights
    var preselectedClientId: UUID? = nil
    var preselectedClientName: String? = nil
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var clients: [Client] = []
    @State private var selectedClientId: UUID?
    @State private var subject = ""
    @State private var description = ""
    @State private var priority: CRMTicketPriority = .normal
    @State private var category: CRMTicketCategory = .other
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("crm.section_ticket"))) {
                    if let preselectedClientId, let preselectedClientName {
                        HStack {
                            Text(L10n.tr("clients.field_client_required"))
                            Spacer()
                            Text(preselectedClientName)
                                .foregroundColor(AppColors.secondary)
                        }
                        .onAppear { selectedClientId = preselectedClientId }
                    } else {
                        Picker(L10n.tr("clients.field_client_required"), selection: $selectedClientId) {
                            Text(L10n.tr("common.select")).tag(UUID?.none)
                            ForEach(clients.filter(\.isActive)) { client in
                                Text(client.denumire).tag(Optional(client.id))
                            }
                        }
                    }
                    FormTextField(title: L10n.tr("crm.field_subject"), text: $subject, isRequired: true)
                    Picker(L10n.tr("crm.field_priority"), selection: $priority) {
                        ForEach(CRMTicketPriority.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Picker(L10n.tr("crm.field_category"), selection: $category) {
                        ForEach(CRMTicketCategory.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                }

                Section(header: Text(L10n.tr("crm.field_description"))) {
                    MultilineTextField(placeholder: L10n.tr("crm.field_description"), text: $description)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("crm.ticket_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(!access.canCreate || selectedClientId == nil || subject.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .appTask {
                if preselectedClientId == nil {
                    do {
                        clients = try await ClientService.fetchClients(activeOnly: true)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } else {
                    selectedClientId = preselectedClientId
                }
            }
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id,
              let clientId = selectedClientId else { return }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await CRMService.createTicket(
                companyId: companyId,
                clientId: clientId,
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.nilIfBlank,
                priority: priority,
                category: category,
                openedBy: session.currentProfile?.id
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct CRMTicketDetailView: View {
    let ticket: CRMTicket
    let access: ModuleAccessRights
    let clientName: String?
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var currentTicket: CRMTicket
    @State private var messages: [CRMTicketMessage] = []
    @State private var replyText = ""
    @State private var resolutionNotes = ""
    @State private var showResolveSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(ticket: CRMTicket, access: ModuleAccessRights, clientName: String?, onChanged: @escaping () async -> Void) {
        self.ticket = ticket
        self.access = access
        self.clientName = clientName
        self.onChanged = onChanged
        _currentTicket = State(initialValue: ticket)
        _resolutionNotes = State(initialValue: ticket.resolutionNotes ?? "")
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(L10n.tr("crm.section_ticket"))) {
                    detailRow(L10n.tr("crm.field_ticket_number"), currentTicket.ticketNumber)
                    detailRow(L10n.tr("clients.field_client_required"), clientName ?? "—")
                    detailRow(L10n.tr("crm.field_status"), currentTicket.status.label)
                    detailRow(L10n.tr("crm.field_priority"), currentTicket.priority.label)
                    detailRow(L10n.tr("crm.field_category"), currentTicket.category.label)
                    if let description = currentTicket.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr("crm.field_description"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            Text(description)
                        }
                        .padding(.vertical, 2)
                    }
                    if let resolvedAt = currentTicket.resolvedAt {
                        detailRow(L10n.tr("crm.field_resolved_at"), SupplierFormatting.date(resolvedAt))
                    }
                    if let closedAt = currentTicket.closedAt {
                        detailRow(L10n.tr("crm.field_closed_at"), SupplierFormatting.date(closedAt))
                    }
                    if let notes = currentTicket.resolutionNotes, !notes.isEmpty {
                        detailRow(L10n.tr("crm.field_resolution_notes"), notes)
                    }
                }

                if access.canEdit {
                    Section(header: Text(L10n.tr("crm.section_actions"))) {
                        statusActions
                    }
                }

                Section(header: Text(L10n.tr("crm.section_messages"))) {
                    if messages.isEmpty {
                        Text(L10n.tr("crm.no_messages"))
                            .foregroundColor(AppColors.secondary)
                    } else {
                        ForEach(messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                if let createdAt = message.createdAt {
                                    Text(SupplierFormatting.date(createdAt))
                                        .font(.caption2)
                                        .foregroundColor(AppColors.tertiary)
                                }
                                Text(message.body)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if access.canCreate {
                        MultilineTextField(placeholder: L10n.tr("crm.field_reply"), text: $replyText)
                        Button(L10n.tr("crm.send_reply")) {
                            Task { await sendReply() }
                        }
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(currentTicket.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.done")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .appTask { await reload() }
            .sheet(isPresented: $showResolveSheet) {
                resolveSheet
            }
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        switch currentTicket.status {
        case .open:
            actionButton(L10n.tr("crm.action_take"), systemImage: "play.fill", color: .orange) {
                await changeStatus(to: .inProgress)
            }
            actionButton(L10n.tr("crm.action_resolve"), systemImage: "checkmark.circle", color: .green) {
                showResolveSheet = true
            }
        case .inProgress:
            actionButton(L10n.tr("crm.action_resolve"), systemImage: "checkmark.circle", color: .green) {
                showResolveSheet = true
            }
        case .resolved:
            actionButton(L10n.tr("crm.action_close"), systemImage: "lock.fill", color: .gray) {
                await changeStatus(to: .closed)
            }
            actionButton(L10n.tr("crm.action_reopen"), systemImage: "arrow.uturn.backward", color: .blue) {
                await changeStatus(to: .open)
            }
        case .closed:
            actionButton(L10n.tr("crm.action_reopen"), systemImage: "arrow.uturn.backward", color: .blue) {
                await changeStatus(to: .open)
            }
        }
    }

    private func actionButton(_ title: String, systemImage: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundColor(color)
        }
        .disabled(isLoading)
    }

    private var resolveSheet: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("crm.field_resolution_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("crm.field_resolution_notes"), text: $resolutionNotes)
                }
            }
            .navigationTitle(L10n.tr("crm.action_resolve"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel")) { showResolveSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.save")) {
                        Task {
                            await changeStatus(to: .resolved, notes: resolutionNotes.nilIfBlank)
                            showResolveSheet = false
                        }
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(AppColors.secondary)
            Text(value)
        }
        .padding(.vertical, 2)
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            if let refreshed = try await CRMService.fetchTicket(id: ticket.id) {
                currentTicket = refreshed
                resolutionNotes = refreshed.resolutionNotes ?? ""
            }
            messages = try await CRMService.fetchMessages(ticketId: ticket.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func changeStatus(to status: CRMTicketStatus, notes: String? = nil) async {
        guard access.canEdit else { return }
        isLoading = true
        errorMessage = nil
        do {
            currentTicket = try await CRMService.setTicketStatus(currentTicket, to: status, resolutionNotes: notes)
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func sendReply() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await CRMService.addMessage(
                companyId: companyId,
                ticketId: currentTicket.id,
                body: body,
                createdBy: session.currentProfile?.id
            )
            replyText = ""
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
