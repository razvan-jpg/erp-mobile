import SwiftUI

struct CreditNoteOffsetContext: Identifiable, Hashable {
    let invoice: SupplierInvoice
    let supplierName: String

    var id: UUID { invoice.id }
}

struct CreditNoteOffsetSelectionSection: View {
    let creditInvoiceNumber: String
    let creditAmount: Decimal
    let currency: String
    let targetInvoices: [SupplierInvoice]
    @Binding var selectedInvoiceIds: [UUID]

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
                CreditNoteOffsetSelectionSection(
                    creditInvoiceNumber: context.invoice.numarFactura,
                    creditAmount: creditAmount,
                    currency: context.invoice.moneda,
                    targetInvoices: CreditNoteOffsetAllocation.openTargetInvoices(
                        supplierInvoices,
                        excludingCreditInvoiceId: context.invoice.id
                    ),
                    selectedInvoiceIds: $selectedInvoiceIds
                )

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
                    Button(L10n.tr("credit_note.offset_skip")) {
                        onSkip()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("credit_note.offset_apply")) {
                        Task { await applyOffsets() }
                    }
                    .disabled(isLoading || selectedInvoiceIds.isEmpty)
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
            let selected = offsets.compactMap { offset in
                invoices.contains(where: { $0.id == offset.targetInvoiceId }) ? offset.targetInvoiceId : nil
            }
            await MainActor.run {
                supplierInvoices = invoices
                existingOffsets = offsets
                selectedInvoiceIds = selected
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
