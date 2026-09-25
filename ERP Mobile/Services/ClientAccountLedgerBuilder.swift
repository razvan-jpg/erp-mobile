import Foundation

struct ClientAccountLedgerEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let nrCrt: Int
    let tipDocument: String
    let tipDocumentScurt: String
    let nrDocument: String
    let dataDocument: Date
    let dataScadenta: Date?
    let suma: Decimal
    let soldFactura: Decimal?
    let soldFinal: Decimal?
    let zileIntarziere: Int?
    let invoiceStatus: InvoiceStatus?
    let isInvoice: Bool
    let balanceDelta: Decimal

    var zileIntarziereDisplay: String {
        guard let zileIntarziere else { return "—" }
        return String(zileIntarziere)
    }

    var statusDisplay: String {
        invoiceStatus?.label ?? "—"
    }

    var statusDisplayCompact: String {
        invoiceStatus?.compactLabel ?? "—"
    }
}

enum ClientAccountLedgerBuilder {
    private struct Draft: Identifiable {
        let id: UUID
        let tipDocument: String
        let tipDocumentScurt: String
        let nrDocument: String
        let dataDocument: Date
        let dataScadenta: Date?
        let suma: Decimal
        let balanceDelta: Decimal
        let soldFactura: Decimal?
        let zileIntarziere: Int?
        let invoiceStatus: InvoiceStatus?
        let isInvoice: Bool
    }

    static func build(
        invoices: [ClientInvoice],
        payments: [ClientPayment]
    ) -> [ClientAccountLedgerEntry] {
        var invoiceDrafts: [UUID: Draft] = [:]
        for invoice in invoices {
            invoiceDrafts[invoice.id] = makeInvoiceDraft(invoice)
        }

        var paymentDrafts: [UUID: Draft] = [:]
        for payment in payments {
            paymentDrafts[payment.id] = makePaymentDraft(payment)
        }

        let order = AccountLedgerOrdering.displayOrder(
            invoices: invoices.map {
                AccountLedgerOrdering.InvoiceAnchor(
                    id: $0.id,
                    dataFactura: $0.dataFactura,
                    numarFactura: $0.numarFactura
                )
            },
            payments: payments.map {
                AccountLedgerOrdering.PaymentAnchor(
                    id: $0.id,
                    invoiceId: $0.invoiceId,
                    dataPlata: $0.dataPlata
                )
            }
        )

        var orderedDrafts: [Draft] = []
        orderedDrafts.reserveCapacity(order.count)
        for item in order {
            switch item {
            case .invoice(let id):
                if let draft = invoiceDrafts[id] { orderedDrafts.append(draft) }
            case .payment(let id):
                if let draft = paymentDrafts[id] { orderedDrafts.append(draft) }
            }
        }

        var runningByIndex: [Decimal] = []
        runningByIndex.reserveCapacity(orderedDrafts.count)
        var runningSold: Decimal = 0
        for draft in orderedDrafts {
            runningSold += draft.balanceDelta
            runningByIndex.append(runningSold)
        }

        var entries: [ClientAccountLedgerEntry] = []
        entries.reserveCapacity(orderedDrafts.count)

        for (index, draft) in orderedDrafts.enumerated() {
            let soldFinal: Decimal?
            if draft.isInvoice {
                let blockEnd = AccountLedgerOrdering.blockEndIndex(for: index, in: order)
                soldFinal = AccountLedgerDisplay.displayedFinalBalance(
                    isInvoice: true,
                    invoiceStatus: draft.invoiceStatus,
                    runningBalance: runningByIndex[blockEnd]
                )
            } else {
                soldFinal = nil
            }

            entries.append(
                ClientAccountLedgerEntry(
                    id: draft.id,
                    nrCrt: index + 1,
                    tipDocument: draft.tipDocument,
                    tipDocumentScurt: draft.tipDocumentScurt,
                    nrDocument: draft.nrDocument,
                    dataDocument: draft.dataDocument,
                    dataScadenta: draft.dataScadenta,
                    suma: draft.suma,
                    soldFactura: draft.soldFactura,
                    soldFinal: soldFinal,
                    zileIntarziere: draft.zileIntarziere,
                    invoiceStatus: draft.invoiceStatus,
                    isInvoice: draft.isInvoice,
                    balanceDelta: draft.balanceDelta
                )
            )
        }

        return entries
    }

    private static func makeInvoiceDraft(_ invoice: ClientInvoice) -> Draft {
        let isAnulata = invoice.status == .anulata
        let isCreditNote = invoice.sumaTotala < 0
        return Draft(
            id: invoice.id,
            tipDocument: L10n.tr("ledger.doc.invoice"),
            tipDocumentScurt: "F",
            nrDocument: invoice.numarFactura,
            dataDocument: invoice.dataFactura,
            dataScadenta: invoice.dataScadenta,
            suma: invoice.sumaTotala,
            balanceDelta: isAnulata ? 0 : invoice.sumaTotala,
            soldFactura: AccountLedgerDisplay.remainingInvoiceBalance(
                status: invoice.status,
                restDePlata: invoice.restDePlata
            ),
            zileIntarziere: overdueDays(
                dataScadenta: invoice.dataScadenta,
                dataFactura: invoice.dataFactura,
                isAnulata: isAnulata,
                isCreditNote: isCreditNote
            ),
            invoiceStatus: invoice.status,
            isInvoice: true
        )
    }

    private static func makePaymentDraft(_ payment: ClientPayment) -> Draft {
        let documentType = payment.metodaPlata.accountDocumentType
        return Draft(
            id: payment.id,
            tipDocument: documentType.label,
            tipDocumentScurt: documentType.shortLabel,
            nrDocument: paymentDocumentNumber(payment),
            dataDocument: payment.dataPlata,
            dataScadenta: nil,
            suma: payment.suma,
            balanceDelta: -payment.suma,
            soldFactura: nil,
            zileIntarziere: nil,
            invoiceStatus: nil,
            isInvoice: false
        )
    }

    private static func paymentDocumentNumber(_ payment: ClientPayment) -> String {
        if let referinta = payment.referinta?.trimmingCharacters(in: .whitespacesAndNewlines), !referinta.isEmpty {
            return referinta
        }
        return "PL-\(SupplierFormatting.inputDateString(payment.dataPlata))"
    }

    private static func overdueDays(
        dataScadenta: Date?,
        dataFactura: Date,
        isAnulata: Bool,
        isCreditNote: Bool = false
    ) -> Int? {
        guard !isAnulata, !isCreditNote else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: dataScadenta ?? dataFactura)
        guard dueDay < today else { return 0 }
        return max(0, calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0)
    }
}
