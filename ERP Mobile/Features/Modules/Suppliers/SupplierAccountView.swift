import SwiftUI
import UIKit

struct SupplierAccountContext: Identifiable, Hashable {
    let row: SupplierListRow
    var dueDateCategoryTitle: String? = nil

    var id: UUID { row.supplier.id }
}

struct SupplierAccountView: View {
    let context: SupplierAccountContext
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var supplier: Supplier
    @State private var listedAt = Date()
    @State private var ledgerEntries: [SupplierAccountLedgerEntry] = []
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
    @State private var invoiceToEdit: SupplierInvoiceRow?
    @State private var paymentToEdit: SupplierPaymentRow?
    @State private var partnerRole: PartnerRole = .supplierOnly
    @State private var periodFilter: AccountLedgerPeriodFilter = .all
    @State private var openOnlyFilter = true
    @State private var customDateFrom = Calendar.current.startOfDay(for: Date())
    @State private var customDateTo = Calendar.current.startOfDay(for: Date())

    init(context: SupplierAccountContext, access: ModuleAccessRights, onChanged: @escaping () async -> Void) {
        self.context = context
        self.access = access
        self.onChanged = onChanged
        _supplier = State(initialValue: context.row.supplier)
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
                    supplierDetailsCard
                    accountTableCard
                    colorLegendCard

                    if let observatii = supplier.observatii, !observatii.isEmpty {
                        infoCard(title: L10n.tr("suppliers.observations_supplier"), lines: [observatii])
                    }

                    Color.clear.frame(height: 280)
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
                SupplierFormView(mode: .edit(supplier), access: access, dismissAfterSave: false) {
                    showEditForm = false
                    await loadAccount()
                }
            }
            .fullScreenCover(isPresented: $showCreatePayment) {
                PaymentFormView(
                    mode: .create,
                    access: access,
                    preselectedSupplierId: supplier.id,
                    preselectedSupplierName: supplier.denumire,
                    dismissAfterSave: false
                ) {
                    showCreatePayment = false
                    listedAt = Date()
                    await loadAccount()
                }
            }
            .fullScreenCover(item: $invoiceToEdit, onDismiss: { invoiceToEdit = nil }) { invoice in
                InvoiceFormView(mode: .edit(invoice), access: access, dismissAfterSave: false) {
                    invoiceToEdit = nil
                    await loadAccount()
                }
            }
            .fullScreenCover(item: $paymentToEdit, onDismiss: { paymentToEdit = nil }) { payment in
                PaymentFormView(mode: .edit(payment), access: access, dismissAfterSave: false) {
                    paymentToEdit = nil
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
                        jobName: L10n.tr("account.print_job", supplier.denumire),
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
                    label: L10n.tr("account.add_payment"),
                    isProminent: true
                ) {
                    showCreatePayment = true
                }
            }

            if access.canEdit {
                FloatingIconActionButton(
                    systemImage: "pencil",
                    label: L10n.tr("account.edit_supplier")
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
                label: L10n.tr("account.back_to_list")
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
            Text(supplier.denumire)
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
            if !supplier.isActive {
                Text(L10n.tr("account.inactive_supplier"))
                    .font(.caption.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var supplierDetailsCard: some View {
        infoCard(title: L10n.tr("account.supplier_data"), lines: [
            detailLine(L10n.tr("account.partner_role_label"), partnerRole.displayLabel),
            detailLine(L10n.tr("common.cui"), supplier.cui),
            detailLine(L10n.tr("common.field_nr_reg_com"), supplier.nrRegCom),
            detailLine(L10n.tr("common.field_address"), supplier.adresa),
            detailLine(L10n.tr("common.field_iban"), supplier.iban),
            detailLine(L10n.tr("common.field_email"), supplier.email),
            detailLine(L10n.tr("common.field_phone"), supplier.telefon),
            supplier.nrZileScadenta > 0
                ? L10n.tr("suppliers.payment_term_line", supplier.nrZileScadenta)
                : L10n.tr("suppliers.payment_term_line_zero")
        ].compactMap(\.self))
    }

    private var displayedLedgerEntries: [SupplierAccountLedgerEntry] {
        SupplierAccountLedgerEntry.prepareForDisplay(
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
                SupplierAccountTableView(
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
                    detail: L10n.tr("suppliers.no_due_date"),
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
        L10n.tr("account.share_message", supplier.denumire)
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
            let account = try await SupplierService.fetchSupplierAccount(supplierId: supplier.id)
            supplier = account.supplier
            ledgerEntries = account.ledgerEntries
            soldRestant = account.soldRestant
            primaScadenta = account.primaScadenta
            moneda = account.moneda
            partnerRole = account.partnerRole
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
                invoiceToEdit = try await SupplierService.fetchInvoiceRow(id: invoiceId)
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
                paymentToEdit = try await SupplierService.fetchPaymentRow(id: paymentId)
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

    private func makeSnapshot() -> SupplierAccountSnapshot {
        SupplierAccountSnapshot(
            company: companyManager.currentCompany,
            supplier: supplier,
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
                let url = try SupplierAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
#if targetEnvironment(macCatalyst)
                try DocumentExportSupport.printPDF(
                    url: url,
                    jobName: L10n.tr("account.print_job", supplier.denumire)
                )
#else
                pdfAttachmentURL = url
                showPrintSheet = true
#endif
            case .exportPDF:
                let url = try SupplierAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .exportXLS:
                let url = try SupplierAccountXLSBuilder.writeTemporaryXLS(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .sendEmailOrWhatsApp:
                let url = try SupplierAccountPDFBuilder.writeTemporaryPDF(from: snapshot)
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
