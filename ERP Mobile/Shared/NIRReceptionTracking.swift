import Foundation

/// Urmărire cantități recepționate pe linii de factură (mai multe NIR-uri).
enum NIRReceptionTracking {
    /// Cantitate din factură deja pe NIR-uri (excluzând un NIR editat).
    static func receivedInvoiceQuantity(
        invoiceLineId: UUID,
        receivedByInvoiceLineId: [UUID: Decimal],
        excludingNIRQuantities: [UUID: Decimal] = [:]
    ) -> Decimal {
        let total = receivedByInvoiceLineId[invoiceLineId] ?? 0
        let excluded = excludingNIRQuantities[invoiceLineId] ?? 0
        return max(total - excluded, 0)
    }

    static func remainingInvoiceQuantity(
        line: SupplierInvoiceLine,
        receivedByInvoiceLineId: [UUID: Decimal],
        excludingNIRQuantities: [UUID: Decimal] = [:]
    ) -> Decimal {
        let received = receivedInvoiceQuantity(
            invoiceLineId: line.id,
            receivedByInvoiceLineId: receivedByInvoiceLineId,
            excludingNIRQuantities: excludingNIRQuantities
        )
        return max(line.cantitate - received, 0)
    }

    /// Linii stocabile care mai au cantitate nerecepționată (fără SGR / Amb.).
    static func hasIncompleteReception(
        invoiceLines: [SupplierInvoiceLine],
        receivedByInvoiceLineId: [UUID: Decimal]
    ) -> Bool {
        for line in invoiceLines {
            guard NIRLineEligibility.countsTowardReceptionCompletion(line) else { continue }
            let remaining = remainingInvoiceQuantity(
                line: line,
                receivedByInvoiceLineId: receivedByInvoiceLineId
            )
            if remaining > 0.0001 {
                return true
            }
        }
        return false
    }

    static func isFullyReceived(
        invoiceLines: [SupplierInvoiceLine],
        receivedByInvoiceLineId: [UUID: Decimal]
    ) -> Bool {
        let receivable = invoiceLines.filter { NIRLineEligibility.countsTowardReceptionCompletion($0) }
        guard !receivable.isEmpty else { return true }
        return !hasIncompleteReception(
            invoiceLines: receivable,
            receivedByInvoiceLineId: receivedByInvoiceLineId
        )
    }

    static func proportionalLineValue(fullValue: Decimal, invoiceQuantity: Decimal, fullQuantity: Decimal) -> Decimal {
        guard fullQuantity > 0 else { return 0 }
        guard invoiceQuantity < fullQuantity else { return fullValue }
        return SupplierFormatting.roundAmount(fullValue * invoiceQuantity / fullQuantity)
    }
}

enum InvoiceNIRReceptionState: Equatable, Sendable {
    case none
    case partial
    case complete

    var hasNIR: Bool {
        self != .none
    }
}
