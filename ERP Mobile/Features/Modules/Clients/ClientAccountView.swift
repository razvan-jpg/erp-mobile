import SwiftUI
import UIKit

struct ClientAccountContext: Identifiable, Hashable {
    let row: ClientListRow
    var dueDateCategoryTitle: String? = nil

    var id: UUID { row.client.id }
}

struct ClientAccountView: View {
    let context: ClientAccountContext
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var client: Client
    @State private var listedAt = Date()
    @State private var ledgerEntries: [ClientAccountLedgerEntry] = []
    @State private var soldRestant: Decimal
    @State private var primaScadenta: Date?
    @State private var moneda: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditForm = false
    @State private var showCreatePayment = false
    @State private var showPrintSheet = false
    @State private var showExportShare = false
    @State private var exportShareItems: [Any] = []
    @State private var exportExcludedActivities: [UIActivity.ActivityType]?
    @State private var pdfAttachmentURL: URL?
    @State private var exportErrorMessage: String?
    @State private var invoiceToEdit: ClientInvoiceRow?
    @State private var paymentToEdit: ClientPaymentRow?
    @State private var partnerRole: PartnerRole = .clientOnly
    @State private var openTickets: [CRMTicket] = []
    @State private var showCreateTicket = false
    @State private var selectedTicket: CRMTicket?
    @State private var periodFilter: AccountLedgerPeriodFilter = .all
    @State private var openOnlyFilter = true
    @State private var customDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var customDateTo = Calendar.current.startOfDay(for: Date())

    init(context: ClientAccountContext, access: ModuleAccessRights, onChanged: @escaping () async -> Void) {
        self.context = context
        self.access = access
        self.onChanged = onChanged
        _client = State(initialValue: context.row.client)
        _soldRestant = State(initialValue: context.row.soldRestant)
        _primaScadenta = State(initialValue: context.row.primaScadenta)
        _moneda = State(initialValue: context.row.moneda)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    accountHeaderBar

                    summaryCard
                    clientTicketsCard
                    clientDetailsCard
                    accountTableCard
                    colorLegendCard

                    if let observatii = client.observatii, !observatii.isEmpty {
                        infoCard(title: L10n.tr("clients.observations_client"), lines: [observatii])
                    }

                    Color.clear.frame(height: 320)
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .appScrollBottomPadding()
            .floatingBottomTrailing {
                accountActionsBar
            }
            .navigationTitle(L10n.tr("account.title"))
            .navigationBarTitleDisplayMode(.inline)
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appSafeAreaInsetBottom {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .appBarBackground()
                } else if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .appBarBackground()
                }
            }
            .appTask { await loadAccount() }
            .appRefreshable { await loadAccount() }
            .fullScreenCover(isPresented: $showEditForm) {
                ClientFormView(mode: .edit(client), access: access, dismissAfterSave: false) {
                    showEditForm = false
                    await loadAccount()
                }
            }
            .fullScreenCover(isPresented: $showCreatePayment) {
                ClientPaymentFormView(
                    mode: .create,
                    access: access,
                    preselectedClientId: client.id,
                    preselectedClientName: client.denumire,
                    dismissAfterSave: false
                ) {
                    showCreatePayment = false
                    listedAt = Date()
                    await loadAccount()
                }
            }
            .fullScreenCover(item: $invoiceToEdit, onDismiss: { invoiceToEdit = nil }) { invoice in
                ClientInvoiceFormView(mode: .edit(invoice), access: access, dismissAfterSave: false) {
                    invoiceToEdit = nil
                    await loadAccount()
                }
            }
            .fullScreenCover(item: $paymentToEdit, onDismiss: { paymentToEdit = nil }) { payment in
                ClientPaymentFormView(mode: .edit(payment), access: access, dismissAfterSave: false) {
                    paymentToEdit = nil
                    await loadAccount()
                }
            }
            .fullScreenCover(isPresented: $showCreateTicket) {
                CRMTicketFormView(
                    access: access,
                    preselectedClientId: client.id,
                    preselectedClientName: client.denumire
                ) {
                    await loadAccount()
                }
            }
            .fullScreenCover(item: $selectedTicket) { ticket in
                CRMTicketDetailView(ticket: ticket, access: access, clientName: client.denumire) {
                    await loadAccount()
                }
            }
            .sheet(isPresented: $showExportShare) {
                ActivityShareSheet(
                    items: exportShareItems,
                    excludedActivityTypes: exportExcludedActivities,
                    onFinish: { showExportShare = false }
                )
            }
            .sheet(isPresented: $showPrintSheet) {
                if let pdfAttachmentURL,
                   let data = try? Data(contentsOf: pdfAttachmentURL) {
                    PrintDocumentView(
                        pdfData: data,
                        jobName: L10n.tr("account.print_job", client.denumire),
                        onFinish: { showPrintSheet = false }
                    )
                }
            }
        }
    }

    private var accountHeaderBar: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let company = companyManager.currentCompany {
                    Text(company.denumire)
                        .font(.headline)
                    ForEach(companyHeaderLines(company), id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                } else {
                    Text(L10n.tr("common.unknown_company"))
                        .font(.headline)
                        .foregroundColor(AppColors.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(L10n.tr("account.listing_date"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                Text(SupplierFormatting.date(listedAt))
                    .font(.subheadline.bold())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var accountActionsBar: some View {
        FloatingIconActionsBar {
            if access.canCreate {
                FloatingIconActionButton(
                    systemImage: "banknote.fill",
                    label: L10n.tr("account.add_collection"),
                    isProminent: true
                ) {
                    showCreatePayment = true
                }

                FloatingIconActionButton(
                    systemImage: "ticket.fill",
                    label: L10n.tr("crm.open_ticket_for_client")
                ) {
                    showCreateTicket = true
                }
            }

            if access.canEdit {
                FloatingIconActionButton(
                    systemImage: "pencil",
                    label: L10n.tr("account.edit_client")
                ) {
                    showEditForm = true
                }
            }

            if access.canCreate || access.canEdit {
                FloatingIconActionDivider()
            }

            FloatingIconActionButton(
                systemImage: "printer.fill",
                label: L10n.tr("account.print")
            ) {
                Task { await performExport(.print) }
            }
            FloatingIconActionButton(
                systemImage: "doc.fill",
                label: L10n.tr("account.export_pdf")
            ) {
                Task { await performExport(.exportPDF) }
            }
            FloatingIconActionButton(
                systemImage: "tablecells.fill",
                label: L10n.tr("account.export_xls")
            ) {
                Task { await performExport(.exportXLS) }
            }
            FloatingIconActionButton(
                systemImage: "paperplane.fill",
                label: L10n.tr("account.send")
            ) {
                Task { await performExport(.sendEmailOrWhatsApp) }
            }

            FloatingIconActionDivider()

            FloatingIconActionButton(
                systemImage: "arrow.uturn.backward",
                label: L10n.tr("account.back_to_clients_list")
            ) {
                Task {
                    await onChanged()
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .accessibilityLabel(L10n.tr("account.actions_menu"))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(client.denumire)
                .font(.title2.bold())
            PartnerRoleBadge(role: partnerRole)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("account.outstanding_balance"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(SupplierFormatting.currency(soldRestant, code: moneda))
                        .font(.title3.bold())
                        .foregroundColor(soldRestant > 0 ? .orange : .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.tr("account.first_due_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(SupplierFormatting.date(primaScadenta))
                        .font(.subheadline.bold())
                        .foregroundColor(isOverdue(primaScadenta) ? .red : .primary)
                }
            }
            if !client.isActive {
                Text(L10n.tr("account.inactive_client"))
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var clientTicketsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("crm.client_open_tickets"))
                    .font(.headline)
                Spacer()
                if access.canCreate {
                    Button(L10n.tr("crm.open_ticket_for_client")) {
                        showCreateTicket = true
                    }
                    .font(.caption.bold())
                }
            }

            if openTickets.isEmpty {
                Text(L10n.tr("crm.client_no_open_tickets"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            } else {
                ForEach(openTickets.prefix(5)) { ticket in
                    Button {
                        selectedTicket = ticket
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ticket.ticketNumber)
                                    .font(.caption.bold())
                                    .foregroundColor(AppColors.secondary)
                                Text(ticket.subject)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColors.primary)
                            }
                            Spacer()
                            Text(ticket.status.label)
                                .font(.caption2.bold())
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var clientDetailsCard: some View {
        infoCard(title: L10n.tr("account.client_data"), lines: [
            detailLine(L10n.tr("account.partner_role_label"), partnerRole.displayLabel),
            detailLine(L10n.tr("common.cui"), client.cui),
            detailLine(L10n.tr("common.field_nr_reg_com"), client.nrRegCom),
            detailLine(L10n.tr("common.field_address"), client.adresa),
            detailLine(L10n.tr("common.field_iban"), client.iban),
            detailLine(L10n.tr("common.field_email"), client.email),
            detailLine(L10n.tr("common.field_phone"), client.telefon),
            client.nrZileScadenta > 0
                ? L10n.tr("clients.payment_term_line", client.nrZileScadenta)
                : L10n.tr("clients.payment_term_line_zero")
        ].compactMap(\.self))
    }

    private var displayedLedgerEntries: [ClientAccountLedgerEntry] {
        ClientAccountLedgerEntry.prepareForDisplay(
            from: ledgerEntries,
            periodFilter: periodFilter,
            customFrom: customDateFrom,
            customTo: customDateTo,
            openOnly: openOnlyFilter
        )
    }

    private var accountTableCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("account.ledger_title"))
                .font(.headline)
            if let categoryTitle = context.dueDateCategoryTitle {
                Text(L10n.tr("account.due_category_filter", categoryTitle))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            Text(L10n.tr("account.ledger_hint"))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            AccountLedgerPeriodFilterBar(
                periodFilter: $periodFilter,
                openOnlyFilter: $openOnlyFilter,
                customDateFrom: $customDateFrom,
                customDateTo: $customDateTo
            )
            if displayedLedgerEntries.isEmpty {
                Text(L10n.tr("account.ledger_empty_open"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ClientAccountTableView(
                    entries: displayedLedgerEntries,
                    moneda: moneda,
                    onInvoiceTap: access.canEdit ? { openInvoiceEdit(invoiceId: $0) } : nil,
                    onPaymentTap: access.canEdit ? { openPaymentEdit(paymentId: $0) } : nil
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var colorLegendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("account.color_legend"))
                .font(.headline)

            legendRow(
                color: .orange,
                title: L10n.tr("account.outstanding_balance"),
                detail: SupplierFormatting.currency(soldRestant, code: moneda),
                detailColor: soldRestant > 0 ? .orange : .secondary
            )

            if let scadenta = primaScadenta {
                legendRow(
                    color: isOverdue(scadenta) ? .red : .secondary,
                    title: L10n.tr("account.first_due_date"),
                    detail: SupplierFormatting.date(scadenta),
                    detailColor: isOverdue(scadenta) ? .red : .secondary
                )
            } else if soldRestant > 0 {
                legendRow(
                    color: .secondary,
                    title: L10n.tr("account.first_due_date"),
                    detail: L10n.tr("clients.no_due_date"),
                    detailColor: .secondary
                )
            } else {
                legendRow(
                    color: .secondary,
                    title: L10n.tr("account.first_due_date"),
                    detail: "—",
                    detailColor: .secondary
                )
            }

            Divider()

            Text(L10n.tr("account.legend_overdue"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Text(L10n.tr("account.legend_outstanding"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Text(L10n.tr("account.legend_future"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func legendRow(
        color: Color,
        title: String,
        detail: String,
        detailColor: Color
    ) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 14, height: 14)

            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)

            Spacer(minLength: 8)

            Text(detail)
                .font(.subheadline.bold())
                .foregroundColor(detailColor)
        }
    }

    private func infoCard(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var shareMessageText: String {
        L10n.tr("account.client_share_message", client.denumire)
    }

    private enum ExportAction {
        case print
        case exportPDF
        case exportXLS
        case sendEmailOrWhatsApp
    }

    private func loadAccount() async {
        isLoading = true
        errorMessage = nil
        do {
            let account = try await ClientService.fetchClientAccount(clientId: client.id)
            client = account.client
            ledgerEntries = account.ledgerEntries
            soldRestant = account.soldRestant
            primaScadenta = account.primaScadenta
            moneda = account.moneda
            partnerRole = account.partnerRole
            openTickets = (try? await CRMService.fetchTickets(clientId: client.id, openOnly: true)) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openInvoiceEdit(invoiceId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                invoiceToEdit = try await ClientService.fetchInvoiceRow(id: invoiceId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func openPaymentEdit(paymentId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                paymentToEdit = try await ClientService.fetchPaymentRow(id: paymentId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func companyHeaderLines(_ company: Company) -> [String] {
        [
            detailLine(L10n.tr("common.cui"), company.cui),
            detailLine(L10n.tr("common.field_nr_reg_com"), company.nrRegCom),
            detailLine(L10n.tr("common.field_address"), company.adresa),
            detailLine(L10n.tr("common.field_iban"), company.iban),
            detailLine(L10n.tr("common.field_email"), company.email),
            detailLine(L10n.tr("common.field_phone"), company.telefon)
        ].compactMap(\.self)
    }

    private func makeSnapshot() -> ClientAccountSnapshot {
        ClientAccountSnapshot(
            company: companyManager.currentCompany,
            client: client,
            ledgerEntries: displayedLedgerEntries,
            soldRestant: soldRestant,
            primaScadenta: primaScadenta,
            moneda: moneda,
            generatedAt: listedAt,
            partnerRole: partnerRole
        )
    }

    private func performExport(_ action: ExportAction) async {
        exportErrorMessage = nil
        let snapshot = makeSnapshot()
        do {
            switch action {
            case .print:
                pdfAttachmentURL = try ClientAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
                showPrintSheet = true
            case .exportPDF:
                let url = try ClientAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .exportXLS:
                let url = try ClientAccountXLSBuilder.writeTemporaryXLS(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .sendEmailOrWhatsApp:
                let url = try ClientAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
                exportShareItems = [shareMessageText, url]
                exportExcludedActivities = [.print, .addToReadingList, .assignToContact, .copyToPasteboard]
                showExportShare = true
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }

    private func detailLine(_ label: String, _ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return L10n.tr("common.detail_line", label, value)
    }

    private func isOverdue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}
