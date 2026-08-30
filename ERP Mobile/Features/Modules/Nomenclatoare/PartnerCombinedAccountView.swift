import SwiftUI

struct PartnerCombinedAccountView: View {
    let partner: PartnerListRow
    let supplierAccess: ModuleAccessRights
    let clientAccess: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var listedAt = Date()
    @State private var supplierAccount: SupplierAccountSnapshot?
    @State private var clientAccount: ClientAccountSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var supplierInvoiceToEdit: SupplierInvoiceRow?
    @State private var supplierPaymentToEdit: SupplierPaymentRow?
    @State private var clientInvoiceToEdit: ClientInvoiceRow?
    @State private var clientPaymentToEdit: ClientPaymentRow?
    @State private var periodFilter: AccountLedgerPeriodFilter = .all
    @State private var openOnlyFilter = true
    @State private var customDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var customDateTo = Calendar.current.startOfDay(for: Date())

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    accountHeaderBar

                    partnerSummaryCard

                    if supplierAccount != nil || clientAccount != nil {
                        sharedLedgerFilterCard
                    }

                    if let supplierAccount {
                        supplierSection(snapshot: supplierAccount)
                    }

                    if let clientAccount {
                        clientSection(snapshot: clientAccount)
                    }

                    if supplierAccount != nil, clientAccount != nil {
                        cumulativeSummaryCard
                    }

                    Color.clear.frame(height: 24)
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(L10n.tr("partners.open_combined_account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("partners.back_to_list")) {
                        Task {
                            await onChanged()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
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
            .appTask { await loadAccounts() }
            .appRefreshable { await loadAccounts() }
            .fullScreenCover(item: $supplierInvoiceToEdit, onDismiss: { supplierInvoiceToEdit = nil }) { invoice in
                InvoiceFormView(mode: .edit(invoice), access: supplierAccess, dismissAfterSave: false) {
                    supplierInvoiceToEdit = nil
                    await loadAccounts()
                }
            }
            .fullScreenCover(item: $supplierPaymentToEdit, onDismiss: { supplierPaymentToEdit = nil }) { payment in
                PaymentFormView(mode: .edit(payment), access: supplierAccess, dismissAfterSave: false) {
                    supplierPaymentToEdit = nil
                    await loadAccounts()
                }
            }
            .fullScreenCover(item: $clientInvoiceToEdit, onDismiss: { clientInvoiceToEdit = nil }) { invoice in
                ClientInvoiceFormView(mode: .edit(invoice), access: clientAccess, dismissAfterSave: false) {
                    clientInvoiceToEdit = nil
                    await loadAccounts()
                }
            }
            .fullScreenCover(item: $clientPaymentToEdit, onDismiss: { clientPaymentToEdit = nil }) { payment in
                ClientPaymentFormView(mode: .edit(payment), access: clientAccess, dismissAfterSave: false) {
                    clientPaymentToEdit = nil
                    await loadAccounts()
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

    private var partnerSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(partner.denumire)
                .font(.title2.bold())
            PartnerRoleBadge(role: .both)
            if let cui = partner.cui, !cui.isEmpty {
                Text(L10n.tr("common.cui_label", cui))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var sharedLedgerFilterCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("account.ledger_hint"))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            AccountLedgerPeriodFilterBar(
                periodFilter: $periodFilter,
                openOnlyFilter: $openOnlyFilter,
                customDateFrom: $customDateFrom,
                customDateTo: $customDateTo
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func filteredSupplierEntries(_ snapshot: SupplierAccountSnapshot) -> [SupplierAccountLedgerEntry] {
        SupplierAccountLedgerEntry.prepareForDisplay(
            from: snapshot.ledgerEntries,
            periodFilter: periodFilter,
            customFrom: customDateFrom,
            customTo: customDateTo,
            openOnly: openOnlyFilter
        )
    }

    private func filteredClientEntries(_ snapshot: ClientAccountSnapshot) -> [ClientAccountLedgerEntry] {
        ClientAccountLedgerEntry.prepareForDisplay(
            from: snapshot.ledgerEntries,
            periodFilter: periodFilter,
            customFrom: customDateFrom,
            customTo: customDateTo,
            openOnly: openOnlyFilter
        )
    }

    private func supplierSection(snapshot: SupplierAccountSnapshot) -> some View {
        let displayedEntries = filteredSupplierEntries(snapshot)

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("partners.supplier_section_title"))
                .font(.title3.bold())

            balanceSummaryCard(
                sold: snapshot.soldRestant,
                scadenta: snapshot.primaScadenta,
                moneda: snapshot.moneda,
                inactiveLabel: snapshot.supplier.isActive ? nil : L10n.tr("account.inactive_supplier")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("account.ledger_title"))
                    .font(.headline)
                if displayedEntries.isEmpty {
                    Text(L10n.tr("account.ledger_empty_open"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    SupplierAccountTableView(
                        entries: displayedEntries,
                        moneda: snapshot.moneda,
                        onInvoiceTap: supplierAccess.canEdit ? { openSupplierInvoiceEdit(invoiceId: $0) } : nil,
                        onPaymentTap: supplierAccess.canEdit ? { openSupplierPaymentEdit(paymentId: $0) } : nil
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
        }
    }

    private func clientSection(snapshot: ClientAccountSnapshot) -> some View {
        let displayedEntries = filteredClientEntries(snapshot)

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("partners.client_section_title"))
                .font(.title3.bold())

            balanceSummaryCard(
                sold: snapshot.soldRestant,
                scadenta: snapshot.primaScadenta,
                moneda: snapshot.moneda,
                inactiveLabel: snapshot.client.isActive ? nil : L10n.tr("account.inactive_client")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("account.ledger_title"))
                    .font(.headline)
                if displayedEntries.isEmpty {
                    Text(L10n.tr("account.ledger_empty_open"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ClientAccountTableView(
                        entries: displayedEntries,
                        moneda: snapshot.moneda,
                        onInvoiceTap: clientAccess.canEdit ? { openClientInvoiceEdit(invoiceId: $0) } : nil,
                        onPaymentTap: clientAccess.canEdit ? { openClientPaymentEdit(paymentId: $0) } : nil
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
        }
    }

    private var cumulativeSummaryCard: some View {
        let supplierSold = supplierAccount?.soldRestant ?? 0
        let clientSold = clientAccount?.soldRestant ?? 0
        let netSold = supplierSold - clientSold
        let moneda = supplierAccount?.moneda ?? clientAccount?.moneda ?? "RON"

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("partners.summary_section_title"))
                .font(.title3.bold())

            summaryRow(
                title: L10n.tr("partners.summary_supplier_balance"),
                value: SupplierFormatting.currency(supplierSold, code: moneda),
                color: supplierSold > 0 ? .orange : .secondary
            )
            summaryRow(
                title: L10n.tr("partners.summary_client_balance"),
                value: SupplierFormatting.currency(clientSold, code: moneda),
                color: clientSold > 0 ? .orange : .secondary
            )

            Divider()

            summaryRow(
                title: L10n.tr("partners.summary_net_balance"),
                value: SupplierFormatting.currency(netSold, code: moneda),
                color: netSold != 0 ? .orange : .secondary,
                emphasized: true
            )

            Text(L10n.tr("partners.summary_no_compensation_note"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func balanceSummaryCard(
        sold: Decimal,
        scadenta: Date?,
        moneda: String,
        inactiveLabel: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("account.outstanding_balance"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(SupplierFormatting.currency(sold, code: moneda))
                        .font(.title3.bold())
                        .foregroundColor(sold > 0 ? .orange : .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.tr("account.first_due_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(SupplierFormatting.date(scadenta))
                        .font(.subheadline.bold())
                        .foregroundColor(isOverdue(scadenta) ? .red : .primary)
                }
            }
            if let inactiveLabel {
                Text(inactiveLabel)
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private func summaryRow(
        title: String,
        value: String,
        color: Color,
        emphasized: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(emphasized ? .subheadline.bold() : .subheadline)
                .foregroundColor(AppColors.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(emphasized ? .headline : .subheadline.bold())
                .foregroundColor(color)
        }
    }

    private func loadAccounts() async {
        isLoading = true
        errorMessage = nil
        do {
            async let supplierTask: SupplierAccountSnapshot? = {
                guard let supplierRow = partner.supplierRow else { return nil }
                return try await SupplierService.fetchSupplierAccount(supplierId: supplierRow.supplier.id)
            }()
            async let clientTask: ClientAccountSnapshot? = {
                guard let clientRow = partner.clientRow else { return nil }
                return try await ClientService.fetchClientAccount(clientId: clientRow.client.id)
            }()
            supplierAccount = try await supplierTask
            clientAccount = try await clientTask
            listedAt = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openSupplierInvoiceEdit(invoiceId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                supplierInvoiceToEdit = try await SupplierService.fetchInvoiceRow(id: invoiceId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func openSupplierPaymentEdit(paymentId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                supplierPaymentToEdit = try await SupplierService.fetchPaymentRow(id: paymentId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func openClientInvoiceEdit(invoiceId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                clientInvoiceToEdit = try await ClientService.fetchInvoiceRow(id: invoiceId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func openClientPaymentEdit(paymentId: UUID) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                clientPaymentToEdit = try await ClientService.fetchPaymentRow(id: paymentId)
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

    private func detailLine(_ label: String, _ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return L10n.tr("common.detail_line", label, value)
    }

    private func isOverdue(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}
