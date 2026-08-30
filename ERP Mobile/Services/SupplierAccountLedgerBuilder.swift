import Foundation

struct SupplierAccountLedgerEntry: Identifiable, Hashable, Sendable {
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

enum SupplierAccountLedgerBuilder {
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
        invoices: [SupplierInvoice],
        payments: [SupplierPayment],
        creditOffsets: [SupplierInvoiceCreditOffset] = []
    ) -> [SupplierAccountLedgerEntry] {
        let invoiceById = Dictionary(uniqueKeysWithValues: invoices.map { ($0.id, $0) })

        var invoiceDrafts: [UUID: Draft] = [:]
        for invoice in invoices {
            invoiceDrafts[invoice.id] = makeInvoiceDraft(invoice)
        }

        var paymentDrafts: [UUID: Draft] = [:]
        for payment in payments {
            paymentDrafts[payment.id] = makePaymentDraft(payment)
        }

        var creditOffsetDrafts: [UUID: Draft] = [:]
        var offsetsByTarget: [UUID: [SupplierInvoiceCreditOffset]] = [:]
        for offset in creditOffsets {
            guard let creditInvoice = invoiceById[offset.creditInvoiceId],
                  let targetInvoice = invoiceById[offset.targetInvoiceId] else {
                continue
            }
            creditOffsetDrafts[offset.id] = makeCreditOffsetDraft(
                offset: offset,
                creditInvoice: creditInvoice,
                targetInvoice: targetInvoice
            )
            offsetsByTarget[offset.targetInvoiceId, default: []].append(offset)
        }

        let baseOrder = AccountLedgerOrdering.displayOrder(
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

        let order = expandedOrder(baseOrder: baseOrder, offsetsByTarget: offsetsByTarget)

        var orderedDrafts: [Draft] = []
        orderedDrafts.reserveCapacity(order.count)
        for item in order {
            switch item {
            case .invoice(let id):
                if let draft = invoiceDrafts[id] { orderedDrafts.append(draft) }
            case .payment(let id):
                if let draft = paymentDrafts[id] {
                    orderedDrafts.append(draft)
                } else if let draft = creditOffsetDrafts[id] {
                    orderedDrafts.append(draft)
                }
            }
        }

        var runningByIndex: [Decimal] = []
        runningByIndex.reserveCapacity(orderedDrafts.count)
        var runningSold: Decimal = 0
        for draft in orderedDrafts {
            runningSold += draft.balanceDelta
            runningByIndex.append(runningSold)
        }

        var entries: [SupplierAccountLedgerEntry] = []
        entries.reserveCapacity(orderedDrafts.count)

        for (index, draft) in orderedDrafts.enumerated() {
            let soldFinal: Decimal?
            if draft.isInvoice {
                let blockEnd = blockEndIndex(for: index, in: order)
                soldFinal = AccountLedgerDisplay.displayedFinalBalance(
                    isInvoice: true,
                    invoiceStatus: draft.invoiceStatus,
                    runningBalance: runningByIndex[blockEnd]
                )
            } else {
                soldFinal = nil
            }

            entries.append(
                SupplierAccountLedgerEntry(
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
                    isInvoice: draft.isInvoice
                )
            )
        }

        return entries
    }

    private static func expandedOrder(
        baseOrder: [AccountLedgerOrdering.OrderedItem],
        offsetsByTarget: [UUID: [SupplierInvoiceCreditOffset]]
    ) -> [AccountLedgerOrdering.OrderedItem] {
        guard !offsetsByTarget.isEmpty else { return baseOrder }

        var result: [AccountLedgerOrdering.OrderedItem] = []
        var index = 0
        while index < baseOrder.count {
            let item = baseOrder[index]
            result.append(item)

            if case .invoice(let invoiceId) = item {
                let blockEnd = AccountLedgerOrdering.blockEndIndex(for: index, in: baseOrder)
                if blockEnd > index {
                    result.append(contentsOf: baseOrder[(index + 1)...blockEnd])
                }
                for offset in offsetsByTarget[invoiceId] ?? [] {
                    result.append(.payment(offset.id))
                }
                index = blockEnd + 1
            } else {
                index += 1
            }
        }
        return result
    }

    private static func blockEndIndex(
        for invoiceIndex: Int,
        in order: [AccountLedgerOrdering.OrderedItem]
    ) -> Int {
        AccountLedgerOrdering.blockEndIndex(for: invoiceIndex, in: order)
    }

    private static func makeInvoiceDraft(_ invoice: SupplierInvoice) -> Draft {
        let isAnulata = invoice.status == .anulata
        let isCreditNote = invoice.isCreditNote
        let balanceDelta: Decimal
        if isAnulata {
            balanceDelta = 0
        } else if isCreditNote {
            balanceDelta = invoice.restDePlata
        } else {
            balanceDelta = invoice.sumaTotala
        }

        return Draft(
            id: invoice.id,
            tipDocument: isCreditNote ? L10n.tr("ledger.doc.credit_note") : L10n.tr("ledger.doc.invoice"),
            tipDocumentScurt: isCreditNote ? "NC" : "F",
            nrDocument: invoice.numarFactura,
            dataDocument: invoice.dataFactura,
            dataScadenta: invoice.dataScadenta,
            suma: invoice.sumaTotala,
            balanceDelta: balanceDelta,
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

    private static func makePaymentDraft(_ payment: SupplierPayment) -> Draft {
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

    private static func makeCreditOffsetDraft(
        offset: SupplierInvoiceCreditOffset,
        creditInvoice: SupplierInvoice,
        targetInvoice: SupplierInvoice
    ) -> Draft {
        Draft(
            id: offset.id,
            tipDocument: L10n.tr("ledger.doc.credit_offset"),
            tipDocumentScurt: "NC",
            nrDocument: L10n.tr(
                "ledger.doc.credit_offset_ref",
                creditInvoice.numarFactura.uppercased(),
                targetInvoice.numarFactura.uppercased()
            ),
            dataDocument: creditInvoice.dataFactura,
            dataScadenta: nil,
            suma: offset.amount,
            balanceDelta: -offset.amount,
            soldFactura: nil,
            zileIntarziere: nil,
            invoiceStatus: nil,
            isInvoice: false
        )
    }

    private static func paymentDocumentNumber(_ payment: SupplierPayment) -> String {
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
