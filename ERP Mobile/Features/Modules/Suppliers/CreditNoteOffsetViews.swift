import SwiftUI

struct CreditNoteOffsetContext: Identifiable, Hashable {
    let invoice: SupplierInvoice
    let supplierName: String

    var id: UUID { invoice.id }
}

struct CreditNoteOffsetDisplayLine: Identifiable, Hashable {
    let id: UUID
    let invoiceNumber: String
    let amount: Decimal
}

struct CreditNoteOffsetLockedSection: View {
    let creditInvoiceNumber: String
    let currency: String
    let lines: [CreditNoteOffsetDisplayLine]

    var body: some View {
        Section {
            Text(L10n.tr("credit_note.offset_locked_intro", creditInvoiceNumber))
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)

            ForEach(lines) { line in
                AppLabeledContent(line.invoiceNumber.uppercased()) {
                    Text(SupplierFormatting.currency(line.amount, code: currency))
                        .foregroundColor(.red)
                }
            }

            Text(L10n.tr("credit_note.offset_locked_fully_allocated"))
                .font(.caption)
                .foregroundColor(.green)
        } header: {
            Text(L10n.tr("credit_note.offset_section_title"))
        } footer: {
            Text(L10n.tr("credit_note.offset_locked_footer"))
                .font(.caption)
        }
    }
}

struct CreditNoteOffsetSelectionSection: View {
    let creditInvoiceNumber: String
    let creditAmount: Decimal
    let currency: String
    let targetInvoices: [SupplierInvoice]
    @Binding var selectedInvoiceIds: [UUID]
    var existingLines: [CreditNoteOffsetDisplayLine] = []

    private var openInvoiceRows: [PaymentFormOpenInvoiceRow] {
        targetInvoices.map {
            PaymentFormOpenInvoiceRow(
                id: $0.id,
                numarFactura: $0.numarFactura,
                restDePlata: $0.restDePlata,
                dataFactura: $0.dataFactura,
                dataScadenta: $0.dataScadenta
            )
        }
    }

    private var plan: PaymentAllocationPlan {
        CreditNoteOffsetAllocation.plan(
            invoices: targetInvoices,
            selectedInvoiceIds: selectedInvoiceIds,
            creditAmount: creditAmount
        )
    }

    private var remainingCredit: Decimal {
        CreditNoteOffsetAllocation.remainingCreditAfterPlan(creditAmount: creditAmount, plan: plan)
    }

    var body: some View {
        Section {
            Text(L10n.tr("credit_note.offset_intro", creditInvoiceNumber, SupplierFormatting.currency(creditAmount, code: currency)))
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)

            if !existingLines.isEmpty {
                ForEach(existingLines) { line in
                    AppLabeledContent(line.invoiceNumber.uppercased()) {
                        Text(SupplierFormatting.currency(line.amount, code: currency))
                            .foregroundColor(.red)
                    }
                }
                Text(L10n.tr("credit_note.offset_existing_locked"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }

            PaymentFormMultiInvoiceSelectionSection(
                emptyMessageKey: "credit_note.offset_no_open_invoices",
                selectHintKey: "credit_note.offset_select_hint",
                selectedTotalKey: "credit_note.offset_selected_total",
                resetAmountKey: "credit_note.offset_reset_hint",
                invoiceRestFormatKey: "credit_note.offset_invoice_rest",
                openInvoices: openInvoiceRows,
                selectedInvoiceIds: $selectedInvoiceIds,
                suma: .constant(""),
                sumaManuallyEdited: .constant(false),
                isApplyingAutoSuma: .constant(false),
                onSelectionChanged: {}
            )

            if !selectedInvoiceIds.isEmpty {
                ForEach(plan.invoiceLines) { line in
                    AppLabeledContent(line.numarFactura.uppercased()) {
                        Text(SupplierFormatting.currency(line.amount, code: currency))
                            .foregroundColor(.red)
                    }
                }

                if remainingCredit > 0 {
                    AppLabeledContent(L10n.tr("credit_note.offset_remaining_credit")) {
                        Text(SupplierFormatting.currency(remainingCredit, code: currency))
                            .foregroundColor(.orange)
                    }
                } else {
                    Text(L10n.tr("credit_note.offset_fully_allocated"))
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text(L10n.tr("credit_note.offset_section_title"))
        } footer: {
            Text(L10n.tr("credit_note.offset_section_footer"))
                .font(.caption)
        }
    }
}

struct CreditNoteOffsetSheet: View {
    let context: CreditNoteOffsetContext
    let onComplete: () async -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var companyManager: CompanyManager

    @State private var supplierInvoices: [SupplierInvoice] = []
    @State private var selectedInvoiceIds: [UUID] = []
    @State private var existingOffsets: [SupplierInvoiceCreditOffset] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var creditAmount: Decimal {
        context.invoice.availableCreditAmount
    }

    private var isLocked: Bool {
        CreditNoteOffsetAllocation.isLocked(
            availableCredit: creditAmount,
            existingOffsetCount: existingOffsets.count
        )
    }

    private var existingLines: [CreditNoteOffsetDisplayLine] {
        let invoicesById = Dictionary(uniqueKeysWithValues: supplierInvoices.map { ($0.id, $0) })
        return existingOffsets.map { offset in
            CreditNoteOffsetDisplayLine(
                id: offset.id,
                invoiceNumber: invoicesById[offset.targetInvoiceId]?.numarFactura ?? "—",
                amount: offset.amount
            )
        }
    }

    private var plan: PaymentAllocationPlan {
        CreditNoteOffsetAllocation.plan(
            invoices: supplierInvoices,
            selectedInvoiceIds: selectedInvoiceIds,
            creditAmount: creditAmount
        )
    }

    var body: some View {
        NavigationView {
            Form {
                if isLocked {
                    CreditNoteOffsetLockedSection(
                        creditInvoiceNumber: context.invoice.numarFactura,
                        currency: context.invoice.moneda,
                        lines: existingLines
                    )
                } else {
                    CreditNoteOffsetSelectionSection(
                        creditInvoiceNumber: context.invoice.numarFactura,
                        creditAmount: creditAmount,
                        currency: context.invoice.moneda,
                        targetInvoices: CreditNoteOffsetAllocation.openTargetInvoices(
                            supplierInvoices,
                            excludingCreditInvoiceId: context.invoice.id
                        )
                        .filter { invoice in
                            !existingOffsets.contains(where: { $0.targetInvoiceId == invoice.id })
                        },
                        selectedInvoiceIds: $selectedInvoiceIds,
                        existingLines: existingLines
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("credit_note.offset_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(isLocked ? "common.done" : "credit_note.offset_skip")) {
                        onSkip()
                    }
                }
                if !isLocked {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.tr("credit_note.offset_apply")) {
                            Task { await applyOffsets() }
                        }
                        .disabled(isLoading || selectedInvoiceIds.isEmpty)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let invoices = try await SupplierService.fetchInvoicesForAccount(supplierId: context.invoice.supplierId)
            let offsets = try await SupplierService.fetchCreditOffsets(creditInvoiceId: context.invoice.id)
            await MainActor.run {
                supplierInvoices = invoices
                existingOffsets = offsets
                selectedInvoiceIds = []
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyOffsets() async {
        guard let companyId = companyManager.currentCompany?.id else {
            errorMessage = L10n.tr("module.suppliers.no_company_selected")
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let latestInvoice = try await SupplierService.fetchInvoice(id: context.invoice.id)
            try await SupplierService.replaceCreditNoteOffsets(
                companyId: companyId,
                creditInvoice: latestInvoice,
                plan: plan
            )
            isLoading = false
            await onComplete()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

enum CreditNoteOffsetSupport {
    static func openInvoiceRows(
        from invoices: [SupplierInvoice],
        excludingCreditInvoiceId: UUID? = nil
    ) -> [PaymentFormOpenInvoiceRow] {
        CreditNoteOffsetAllocation.openTargetInvoices(
            invoices,
            excludingCreditInvoiceId: excludingCreditInvoiceId
        ).map {
            PaymentFormOpenInvoiceRow(
                id: $0.id,
                numarFactura: $0.numarFactura,
                restDePlata: $0.restDePlata,
                dataFactura: $0.dataFactura,
                dataScadenta: $0.dataScadenta
            )
        }
    }
}

struct CreditNoteOffsetQueueView: View {
    @Binding var contexts: [CreditNoteOffsetContext]
    let onFinish: () -> Void

    @State private var currentIndex = 0

    var body: some View {
        if contexts.indices.contains(currentIndex) {
            CreditNoteOffsetSheet(
                context: contexts[currentIndex],
                onComplete: {
                    await advanceQueue()
                },
                onSkip: {
                    advanceQueueSync()
                }
            )
        }
    }

    @MainActor
    private func advanceQueue() async {
        if currentIndex + 1 < contexts.count {
            currentIndex += 1
        } else {
            onFinish()
        }
    }

    private func advanceQueueSync() {
        Task { @MainActor in
            if currentIndex + 1 < contexts.count {
                currentIndex += 1
            } else {
                onFinish()
            }
        }
    }
}
