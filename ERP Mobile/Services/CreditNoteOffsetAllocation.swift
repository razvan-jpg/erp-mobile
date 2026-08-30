import Foundation

enum CreditNoteOffsetAllocation {
    static func openTargetInvoices(
        _ invoices: [SupplierInvoice],
        excludingCreditInvoiceId: UUID? = nil
    ) -> [SupplierInvoice] {
        invoices.filter { invoice in
            if let excludingCreditInvoiceId, invoice.id == excludingCreditInvoiceId { return false }
            guard !invoice.isCreditNote else { return false }
            guard invoice.status != .platita, invoice.status != .anulata else { return false }
            return invoice.restDePlata > 0
        }
        .sorted { lhs, rhs in
            let leftDue = lhs.effectiveDueDate
            let rightDue = rhs.effectiveDueDate
            if leftDue != rightDue { return leftDue < rightDue }
            if lhs.dataFactura != rhs.dataFactura { return lhs.dataFactura < rhs.dataFactura }
            return lhs.numarFactura.localizedStandardCompare(rhs.numarFactura) == .orderedAscending
        }
    }

    static func plan(
        invoices: [SupplierInvoice],
        selectedInvoiceIds: [UUID],
        creditAmount: Decimal
    ) -> PaymentAllocationPlan {
        PaymentAllocation.sanitizedPlan(
            PaymentAllocation.planForSelectedInvoices(
                invoices: invoices,
                selectedInvoiceIds: selectedInvoiceIds,
                totalAmount: creditAmount
            )
        )
    }

    static func remainingCreditAfterPlan(creditAmount: Decimal, plan: PaymentAllocationPlan) -> Decimal {
        let applied = plan.invoiceLines.reduce(Decimal.zero) { $0 + $1.amount }
        return max(0, SupplierFormatting.roundAmount(creditAmount - applied))
    }

    static func summaryMessage(
        creditInvoiceNumber: String,
        plan: PaymentAllocationPlan,
        creditAmount: Decimal,
        currency: String
    ) -> String {
        var lines = plan.invoiceLines.map { line in
            L10n.tr(
                "credit_note.offset_summary_line",
                line.numarFactura.uppercased(),
                SupplierFormatting.currency(line.amount, code: currency)
            )
        }
        let remaining = remainingCreditAfterPlan(creditAmount: creditAmount, plan: plan)
        if remaining > 0 {
            lines.append(
                L10n.tr(
                    "credit_note.offset_summary_remaining",
                    creditInvoiceNumber.uppercased(),
                    SupplierFormatting.currency(remaining, code: currency)
                )
            )
        }
        return lines.joined(separator: "\n")
    }
}

enum CreditNoteOffsetError: LocalizedError {
    case notCreditNote
    case amountExceedsAvailableCredit
    case targetInvoiceInvalid
    case differentSupplier

    var errorDescription: String? {
        switch self {
        case .notCreditNote:
            return L10n.tr("credit_note.offset_error_not_credit_note")
        case .amountExceedsAvailableCredit:
            return L10n.tr("credit_note.offset_error_exceeds_credit")
        case .targetInvoiceInvalid:
            return L10n.tr("credit_note.offset_error_invalid_target")
        case .differentSupplier:
            return L10n.tr("credit_note.offset_error_different_supplier")
        }
    }
}
