import Foundation

enum AccountDocumentType {
    case invoice
    case cashReceipt
    case paymentOrder

    var label: String {
        switch self {
        case .invoice: return L10n.tr("ledger.doc.invoice")
        case .cashReceipt: return L10n.tr("ledger.doc.cash_receipt")
        case .paymentOrder: return L10n.tr("ledger.doc.payment_order")
        }
    }

    var shortLabel: String {
        switch self {
        case .invoice: return "F"
        case .cashReceipt: return "C"
        case .paymentOrder: return "OP"
        }
    }
}

extension PaymentMethod {
    var accountDocumentType: AccountDocumentType {
        switch self {
        case .numerar: return .cashReceipt
        case .transfer, .card, .altele: return .paymentOrder
        }
    }
}

enum AccountLedgerDisplay {
    static func remainingInvoiceBalance(status: InvoiceStatus, restDePlata: Decimal) -> Decimal? {
        guard status != .anulata, status != .platita else { return nil }
        guard restDePlata != 0 else { return nil }
        return restDePlata
    }

    static func amountText(suma: Decimal, isInvoice: Bool, moneda: String) -> String {
        if isInvoice {
            return SupplierFormatting.currency(suma, code: moneda)
        }
        return SupplierFormatting.currency(-suma, code: moneda)
    }

    static func balanceText(_ value: Decimal?, moneda: String) -> String {
        guard let value else { return "—" }
        return SupplierFormatting.currency(value, code: moneda)
    }

    /// Sold final: doar pe facturi deschise (neplătite/parțial); nu pe plăți sau facturi închise.
    static func displayedFinalBalance(
        isInvoice: Bool,
        invoiceStatus: InvoiceStatus?,
        runningBalance: Decimal
    ) -> Decimal? {
        guard isInvoice,
              let invoiceStatus,
              invoiceStatus != .platita,
              invoiceStatus != .anulata else {
            return nil
        }
        return runningBalance
    }
}

enum AccountLedgerOrdering {
    struct InvoiceAnchor: Sendable {
        let id: UUID
        let dataFactura: Date
        let numarFactura: String
    }

    struct PaymentAnchor: Sendable {
        let id: UUID
        let invoiceId: UUID?
        let dataPlata: Date
    }

    enum OrderedItem: Sendable {
        case invoice(UUID)
        case payment(UUID)
    }

    /// Facturi în ordine cronologică; plățile alocate imediat sub factură; plățile nealocate la data plății.
    static func displayOrder(
        invoices: [InvoiceAnchor],
        payments: [PaymentAnchor]
    ) -> [OrderedItem] {
        let sortedInvoices = invoices.sorted { lhs, rhs in
            let leftDay = Calendar.current.startOfDay(for: lhs.dataFactura)
            let rightDay = Calendar.current.startOfDay(for: rhs.dataFactura)
            if leftDay != rightDay { return leftDay < rightDay }
            return lhs.numarFactura.localizedStandardCompare(rhs.numarFactura) == .orderedAscending
        }
        let invoiceIds = Set(sortedInvoices.map(\.id))

        var allocatedByInvoice: [UUID: [PaymentAnchor]] = [:]
        var unallocated: [PaymentAnchor] = []

        for payment in payments {
            if let invoiceId = payment.invoiceId, invoiceIds.contains(invoiceId) {
                allocatedByInvoice[invoiceId, default: []].append(payment)
            } else {
                unallocated.append(payment)
            }
        }

        let sortPayments: ([PaymentAnchor]) -> [PaymentAnchor] = { items in
            items.sorted { lhs, rhs in
                let leftDay = Calendar.current.startOfDay(for: lhs.dataPlata)
                let rightDay = Calendar.current.startOfDay(for: rhs.dataPlata)
                if leftDay != rightDay { return leftDay < rightDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }

        for invoiceId in allocatedByInvoice.keys {
            allocatedByInvoice[invoiceId] = sortPayments(allocatedByInvoice[invoiceId] ?? [])
        }
        unallocated = sortPayments(unallocated)

        let blocks: [[OrderedItem]] = sortedInvoices.map { invoice in
            var block: [OrderedItem] = [.invoice(invoice.id)]
            if let allocated = allocatedByInvoice[invoice.id] {
                block.append(contentsOf: allocated.map { .payment($0.id) })
            }
            return block
        }

        var result: [OrderedItem] = []
        var unallocatedIndex = 0
        let calendar = Calendar.current

        for (blockIndex, block) in blocks.enumerated() {
            let blockInvoiceDay = calendar.startOfDay(for: sortedInvoices[blockIndex].dataFactura)

            while unallocatedIndex < unallocated.count {
                let paymentDay = calendar.startOfDay(for: unallocated[unallocatedIndex].dataPlata)
                if paymentDay < blockInvoiceDay {
                    result.append(.payment(unallocated[unallocatedIndex].id))
                    unallocatedIndex += 1
                } else {
                    break
                }
            }

            result.append(contentsOf: block)
        }

        while unallocatedIndex < unallocated.count {
            result.append(.payment(unallocated[unallocatedIndex].id))
            unallocatedIndex += 1
        }

        return result
    }

    /// Indexul ultimului rând din blocul facturii (factura + plățile alocate imediat dedesubt).
    static func blockEndIndex(for invoiceIndex: Int, in order: [OrderedItem]) -> Int {
        guard invoiceIndex < order.count else { return invoiceIndex }
        var end = invoiceIndex
        var index = invoiceIndex + 1
        while index < order.count {
            if case .payment = order[index] {
                end = index
                index += 1
            } else {
                break
            }
        }
        return end
    }
}

protocol AccountLedgerFilterEntry {
    var isInvoice: Bool { get }
    var soldFactura: Decimal? { get }
    var invoiceStatus: InvoiceStatus? { get }
    var dataDocument: Date { get }
    var suma: Decimal { get }
    var balanceDelta: Decimal { get }
}

extension ClientAccountLedgerEntry: AccountLedgerFilterEntry {}
extension SupplierAccountLedgerEntry: AccountLedgerFilterEntry {}

enum AccountLedgerFiltering {
    static func isOpenInvoice<Entry: AccountLedgerFilterEntry>(_ entry: Entry) -> Bool {
        guard entry.isInvoice, let status = entry.invoiceStatus else { return false }
        return (status == .neplatita || status == .partial) && (entry.soldFactura ?? 0) != 0
    }

    static func filterOpenOnly<Entry: AccountLedgerFilterEntry>(_ entries: [Entry]) -> [Entry] {
        var result: [Entry] = []
        var index = 0

        while index < entries.count {
            let entry = entries[index]
            if entry.isInvoice {
                var block: [Entry] = [entry]
                var next = index + 1
                while next < entries.count, !entries[next].isInvoice {
                    block.append(entries[next])
                    next += 1
                }
                if isOpenInvoice(entry) {
                    result.append(contentsOf: block)
                }
                index = next
            } else {
                result.append(entry)
                index += 1
            }
        }

        return result
    }

    static func filterByPeriod<Entry: AccountLedgerFilterEntry>(
        _ entries: [Entry],
        periodFilter: AccountLedgerPeriodFilter,
        customFrom: Date,
        customTo: Date
    ) -> [Entry] {
        guard periodFilter != .all else { return entries }

        var result: [Entry] = []
        var index = 0

        while index < entries.count {
            let entry = entries[index]
            if entry.isInvoice {
                var block: [Entry] = [entry]
                var next = index + 1
                while next < entries.count, !entries[next].isInvoice {
                    block.append(entries[next])
                    next += 1
                }
                if periodFilter.includes(documentDate: entry.dataDocument, customFrom: customFrom, customTo: customTo) {
                    result.append(contentsOf: block)
                }
                index = next
            } else if periodFilter.includes(documentDate: entry.dataDocument, customFrom: customFrom, customTo: customTo) {
                result.append(entry)
                index += 1
            } else {
                index += 1
            }
        }

        return result
    }

    static func balanceDelta<Entry: AccountLedgerFilterEntry>(for entry: Entry) -> Decimal {
        entry.balanceDelta
    }
}

extension ClientAccountLedgerEntry {
    func withDisplayMetadata(nrCrt: Int, soldFinal: Decimal?) -> ClientAccountLedgerEntry {
        ClientAccountLedgerEntry(
            id: id,
            nrCrt: nrCrt,
            tipDocument: tipDocument,
            tipDocumentScurt: tipDocumentScurt,
            nrDocument: nrDocument,
            dataDocument: dataDocument,
            dataScadenta: dataScadenta,
            suma: suma,
            soldFactura: soldFactura,
            soldFinal: soldFinal,
            zileIntarziere: zileIntarziere,
            invoiceStatus: invoiceStatus,
            isInvoice: isInvoice,
            balanceDelta: balanceDelta
        )
    }

    static func prepareForDisplay(
        from entries: [ClientAccountLedgerEntry],
        periodFilter: AccountLedgerPeriodFilter,
        customFrom: Date,
        customTo: Date,
        openOnly: Bool
    ) -> [ClientAccountLedgerEntry] {
        let visibilityFiltered = openOnly
            ? AccountLedgerFiltering.filterOpenOnly(entries)
            : entries
        let periodFiltered = AccountLedgerFiltering.filterByPeriod(
            visibilityFiltered,
            periodFilter: periodFilter,
            customFrom: customFrom,
            customTo: customTo
        )
        return renumberedWithBalances(periodFiltered)
    }

    private static func renumberedWithBalances(_ entries: [ClientAccountLedgerEntry]) -> [ClientAccountLedgerEntry] {
        guard !entries.isEmpty else { return [] }

        var runningByIndex: [Decimal] = []
        runningByIndex.reserveCapacity(entries.count)
        var runningSold: Decimal = 0

        for entry in entries {
            runningSold += AccountLedgerFiltering.balanceDelta(for: entry)
            runningByIndex.append(runningSold)
        }

        var result: [ClientAccountLedgerEntry] = []
        result.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let soldFinal: Decimal?
            if entry.isInvoice {
                var blockEnd = index
                var next = index + 1
                while next < entries.count, !entries[next].isInvoice {
                    blockEnd = next
                    next += 1
                }
                soldFinal = AccountLedgerDisplay.displayedFinalBalance(
                    isInvoice: true,
                    invoiceStatus: entry.invoiceStatus,
                    runningBalance: runningByIndex[blockEnd]
                )
            } else {
                soldFinal = nil
            }

            result.append(entry.withDisplayMetadata(nrCrt: index + 1, soldFinal: soldFinal))
        }

        return result
    }
}

extension SupplierAccountLedgerEntry {
    func withDisplayMetadata(nrCrt: Int, soldFinal: Decimal?) -> SupplierAccountLedgerEntry {
        SupplierAccountLedgerEntry(
            id: id,
            nrCrt: nrCrt,
            tipDocument: tipDocument,
            tipDocumentScurt: tipDocumentScurt,
            nrDocument: nrDocument,
            dataDocument: dataDocument,
            dataScadenta: dataScadenta,
            suma: suma,
            soldFactura: soldFactura,
            soldFinal: soldFinal,
            zileIntarziere: zileIntarziere,
            invoiceStatus: invoiceStatus,
            isInvoice: isInvoice,
            balanceDelta: balanceDelta
        )
    }

    static func prepareForDisplay(
        from entries: [SupplierAccountLedgerEntry],
        periodFilter: AccountLedgerPeriodFilter,
        customFrom: Date,
        customTo: Date,
        openOnly: Bool
    ) -> [SupplierAccountLedgerEntry] {
        let visibilityFiltered = openOnly
            ? AccountLedgerFiltering.filterOpenOnly(entries)
            : entries
        let periodFiltered = AccountLedgerFiltering.filterByPeriod(
            visibilityFiltered,
            periodFilter: periodFilter,
            customFrom: customFrom,
            customTo: customTo
        )
        return renumberedWithBalances(periodFiltered)
    }

    private static func renumberedWithBalances(_ entries: [SupplierAccountLedgerEntry]) -> [SupplierAccountLedgerEntry] {
        guard !entries.isEmpty else { return [] }

        var runningByIndex: [Decimal] = []
        runningByIndex.reserveCapacity(entries.count)
        var runningSold: Decimal = 0

        for entry in entries {
            runningSold += AccountLedgerFiltering.balanceDelta(for: entry)
            runningByIndex.append(runningSold)
        }

        var result: [SupplierAccountLedgerEntry] = []
        result.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let soldFinal: Decimal?
            if entry.isInvoice {
                var blockEnd = index
                var next = index + 1
                while next < entries.count, !entries[next].isInvoice {
                    blockEnd = next
                    next += 1
                }
                soldFinal = AccountLedgerDisplay.displayedFinalBalance(
                    isInvoice: true,
                    invoiceStatus: entry.invoiceStatus,
                    runningBalance: runningByIndex[blockEnd]
                )
            } else {
                soldFinal = nil
            }

            result.append(entry.withDisplayMetadata(nrCrt: index + 1, soldFinal: soldFinal))
        }

        return result
    }
}
