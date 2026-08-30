import Foundation

struct PaymentAllocationLine: Identifiable, Sendable {
    let invoiceId: UUID
    let numarFactura: String
    let amount: Decimal

    var id: UUID { invoiceId }
}

struct PaymentAllocationPlan: Sendable {
    let invoiceLines: [PaymentAllocationLine]
    let advanceAmount: Decimal

    static let empty = PaymentAllocationPlan(invoiceLines: [], advanceAmount: 0)

    var hasInvoiceAllocations: Bool { !invoiceLines.isEmpty }
    var hasAdvance: Bool { advanceAmount > 0 }
    var isFullAdvance: Bool { invoiceLines.isEmpty && advanceAmount > 0 }
}

enum PaymentAllocation {
    static func sortedOpenInvoices(_ invoices: [SupplierInvoice]) -> [SupplierInvoice] {
        openInvoices(invoices)
            .sorted { a, b in
                if a.dataFactura != b.dataFactura { return a.dataFactura < b.dataFactura }
                let scadA = a.dataScadenta ?? .distantFuture
                let scadB = b.dataScadenta ?? .distantFuture
                if scadA != scadB { return scadA < scadB }
                return a.numarFactura.localizedCaseInsensitiveCompare(b.numarFactura) == .orderedAscending
            }
    }

    static func sortedOpenInvoicesByDueDate(_ invoices: [SupplierInvoice]) -> [SupplierInvoice] {
        openInvoices(invoices)
            .sorted { a, b in
                let scadA = a.dataScadenta ?? .distantFuture
                let scadB = b.dataScadenta ?? .distantFuture
                if scadA != scadB { return scadA < scadB }
                if a.dataFactura != b.dataFactura { return a.dataFactura < b.dataFactura }
                return a.numarFactura.localizedCaseInsensitiveCompare(b.numarFactura) == .orderedAscending
            }
    }

    /// Allocates `totalAmount` starting at `startingInvoiceId`, then across following open invoices in date order.
    static func plan(
        invoices: [SupplierInvoice],
        startingInvoiceId: UUID,
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        let sorted = sortedOpenInvoices(invoices)
        guard let startIdx = sorted.firstIndex(where: { $0.id == startingInvoiceId }) else {
            return PaymentAllocationPlan(invoiceLines: [], advanceAmount: totalAmount)
        }
        return allocateAmount(sortedInvoices: sorted, fromIndex: startIdx, totalAmount: totalAmount)
    }

    /// Allocates `totalAmount` across open invoices ordered by due date (oldest first).
    static func planByDueDate(
        invoices: [SupplierInvoice],
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        let sorted = allocatableOpenInvoices(invoices)
        guard !sorted.isEmpty else {
            return PaymentAllocationPlan(invoiceLines: [], advanceAmount: totalAmount)
        }
        return allocateAmount(sortedInvoices: sorted, fromIndex: 0, totalAmount: totalAmount)
    }

    static func hasAllocatableOpenInvoices(_ invoices: [SupplierInvoice]) -> Bool {
        !allocatableOpenInvoices(invoices).isEmpty
    }

    static func totalRest(invoices: [SupplierInvoice], selectedInvoiceIds: [UUID]) -> Decimal {
        let byId = Dictionary(uniqueKeysWithValues: openInvoices(invoices).map { ($0.id, $0) })
        return selectedInvoiceIds.compactMap { byId[$0]?.restDePlata }.reduce(0, +)
    }

    /// Allocates across explicitly selected invoices (selection order matters).
    /// Under-payment: earlier selected invoices are paid in full when possible; the last selected may be partial.
    /// Over-payment: all selected are paid in full, then spillover continues on other open invoices chronologically.
    static func planForSelectedInvoices(
        invoices: [SupplierInvoice],
        selectedInvoiceIds: [UUID],
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        guard totalAmount > 0, !selectedInvoiceIds.isEmpty else {
            return PaymentAllocationPlan(invoiceLines: [], advanceAmount: max(0, totalAmount))
        }

        let byId = Dictionary(uniqueKeysWithValues: openInvoices(invoices).map { ($0.id, $0) })
        let selected = selectedInvoiceIds.compactMap { byId[$0] }.filter { $0.restDePlata > 0 }
        guard !selected.isEmpty else {
            return PaymentAllocationPlan(invoiceLines: [], advanceAmount: totalAmount)
        }

        let selectedTotal = selected.reduce(into: Decimal(0)) { $0 += $1.restDePlata }
        if totalAmount <= selectedTotal {
            return planUnderSelectedTotal(selected: selected, totalAmount: totalAmount)
        }
        return planOverSelectedTotal(invoices: invoices, selected: selected, totalAmount: totalAmount)
    }

    static func isPartialAllocation(invoice: SupplierInvoice, allocatedAmount: Decimal) -> Bool {
        allocatedAmount > 0 && allocatedAmount < invoice.restDePlata
    }

    static func advanceReferenceString(amount: Decimal) -> String {
        L10n.tr("payments.advance_reference", SupplierFormatting.currency(amount))
    }

    static func referenceString(from plan: PaymentAllocationPlan) -> String {
        referenceString(from: plan, projectedBalance: nil, currencyCode: "RON")
    }

    static func referenceString(
        from plan: PaymentAllocationPlan,
        projectedBalance: Decimal?,
        currencyCode: String
    ) -> String {
        var parts = plan.invoiceLines.map { line in
            L10n.tr(
                "payments.allocation_reference_line",
                line.numarFactura.uppercased(),
                SupplierFormatting.currency(line.amount)
            )
        }
        if plan.advanceAmount > 0 {
            parts.append(advanceReferenceString(amount: plan.advanceAmount))
        }
        if let projectedBalance {
            parts.append(balanceReferenceString(balance: projectedBalance, currencyCode: currencyCode))
        }
        return parts.joined(separator: "; ")
    }

    static func balanceReferenceString(balance: Decimal, currencyCode: String = "RON") -> String {
        L10n.tr("payments.balance_reference", SupplierFormatting.currency(balance, code: currencyCode))
    }

    static func projectedBalance(currentSoldRestant: Decimal, paymentAmount: Decimal) -> Decimal {
        currentSoldRestant - paymentAmount
    }

    static func sanitizedPlan(_ plan: PaymentAllocationPlan) -> PaymentAllocationPlan {
        let invoiceLines = plan.invoiceLines.compactMap { line -> PaymentAllocationLine? in
            let amount = SupplierFormatting.roundAmount(line.amount)
            guard amount > 0 else { return nil }
            return PaymentAllocationLine(
                invoiceId: line.invoiceId,
                numarFactura: line.numarFactura,
                amount: amount
            )
        }
        let advanceAmount = SupplierFormatting.roundAmount(plan.advanceAmount)
        return PaymentAllocationPlan(
            invoiceLines: invoiceLines,
            advanceAmount: advanceAmount > 0 ? advanceAmount : 0
        )
    }

    private static func openInvoices(_ invoices: [SupplierInvoice]) -> [SupplierInvoice] {
        invoices.filter { $0.status != .platita && $0.status != .anulata }
    }

    private static func allocatableOpenInvoices(_ invoices: [SupplierInvoice]) -> [SupplierInvoice] {
        sortedOpenInvoicesByDueDate(invoices).filter { $0.restDePlata > 0 }
    }

    private static func allocateAmount(
        sortedInvoices: [SupplierInvoice],
        fromIndex: Int,
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        var remaining = totalAmount
        var result: [PaymentAllocationLine] = []

        for index in fromIndex..<sortedInvoices.count {
            guard remaining > 0 else { break }
            let invoice = sortedInvoices[index]
            let rest = invoice.restDePlata
            guard rest > 0 else { continue }
            let allocated = min(remaining, rest)
            result.append(PaymentAllocationLine(
                invoiceId: invoice.id,
                numarFactura: invoice.numarFactura,
                amount: allocated
            ))
            remaining -= allocated
        }

        return PaymentAllocationPlan(invoiceLines: result, advanceAmount: max(0, remaining))
    }

    private static func planUnderSelectedTotal(
        selected: [SupplierInvoice],
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        guard let last = selected.last else {
            return .empty
        }

        if selected.count == 1 {
            let allocated = min(totalAmount, last.restDePlata)
            guard allocated > 0 else { return .empty }
            return PaymentAllocationPlan(
                invoiceLines: [allocationLine(last, amount: allocated)],
                advanceAmount: 0
            )
        }

        var remaining = totalAmount
        var lines: [PaymentAllocationLine] = []

        for invoice in selected.dropLast() {
            guard remaining >= invoice.restDePlata else { break }
            lines.append(allocationLine(invoice, amount: invoice.restDePlata))
            remaining -= invoice.restDePlata
        }

        if remaining > 0 {
            let allocated = min(remaining, last.restDePlata)
            if allocated > 0 {
                lines.append(allocationLine(last, amount: allocated))
            }
        }

        return PaymentAllocationPlan(invoiceLines: lines, advanceAmount: 0)
    }

    private static func planOverSelectedTotal(
        invoices: [SupplierInvoice],
        selected: [SupplierInvoice],
        totalAmount: Decimal
    ) -> PaymentAllocationPlan {
        var remaining = totalAmount
        var lines: [PaymentAllocationLine] = []

        for invoice in selected {
            lines.append(allocationLine(invoice, amount: invoice.restDePlata))
            remaining -= invoice.restDePlata
        }

        let allocatedIds = Set(lines.map(\.invoiceId))
        let spilloverCandidates = sortedOpenInvoices(invoices).filter {
            $0.restDePlata > 0 && !allocatedIds.contains($0.id)
        }

        for invoice in spilloverCandidates {
            guard remaining > 0 else { break }
            let allocated = min(remaining, invoice.restDePlata)
            guard allocated > 0 else { continue }
            lines.append(allocationLine(invoice, amount: allocated))
            remaining -= allocated
        }

        return PaymentAllocationPlan(invoiceLines: lines, advanceAmount: max(0, remaining))
    }

    private static func allocationLine(_ invoice: SupplierInvoice, amount: Decimal) -> PaymentAllocationLine {
        PaymentAllocationLine(
            invoiceId: invoice.id,
            numarFactura: invoice.numarFactura,
            amount: amount
        )
    }
}
