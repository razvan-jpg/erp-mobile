import Foundation
import Supabase

private struct ClientInsert: Encodable {
    let companyId: UUID
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let observatii: String?
    let nrZileScadenta: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, cui, adresa, iban, email, telefon, observatii
        case companyId = "company_id"
        case nrRegCom = "nr_reg_com"
        case nrZileScadenta = "nr_zile_scadenta"
        case isActive = "is_active"
    }
}

private struct ClientUpdate: Encodable {
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let observatii: String?
    let nrZileScadenta: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, cui, adresa, iban, email, telefon, observatii
        case nrRegCom = "nr_reg_com"
        case nrZileScadenta = "nr_zile_scadenta"
        case isActive = "is_active"
    }
}

private struct InvoiceInsert: Encodable {
    let companyId: UUID
    let clientId: UUID
    let numarFactura: String
    let dataFactura: String
    let dataScadenta: String?
    let sumaTotala: Double
    let sumaTva: Double
    let moneda: String
    let status: String
    let observatii: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case moneda, status, observatii
        case companyId = "company_id"
        case clientId = "client_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case createdBy = "created_by"
    }
}

private struct InvoiceUpdate: Encodable {
    let clientId: UUID
    let numarFactura: String
    let dataFactura: String
    let dataScadenta: String?
    let sumaTotala: Double
    let sumaTva: Double
    let moneda: String
    let status: String
    let observatii: String?

    enum CodingKeys: String, CodingKey {
        case moneda, status, observatii
        case clientId = "client_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
    }
}

private struct PaymentInsert: Encodable {
    let companyId: UUID
    let clientId: UUID
    let invoiceId: UUID?
    let dataPlata: String
    let suma: Double
    let metodaPlata: String
    let referinta: String?
    let observatii: String?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case suma, referinta, observatii
        case companyId = "company_id"
        case clientId = "client_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdBy = "created_by"
    }
}

private struct PaymentUpdate: Encodable {
    let clientId: UUID
    let invoiceId: UUID?
    let dataPlata: String
    let suma: Double
    let metodaPlata: String
    let referinta: String?
    let observatii: String?

    enum CodingKeys: String, CodingKey {
        case suma, referinta, observatii
        case clientId = "client_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
    }
}

enum ClientService {
    private static let client = SupabaseManager.client

    private static func dateString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private static func doubleAmount(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: SupplierFormatting.roundAmount(value)).doubleValue
    }

    private static func paymentAmountLines(from plan: ClientPaymentAllocationPlan) -> [(invoiceId: UUID?, amount: Decimal)] {
        var lines: [(invoiceId: UUID?, amount: Decimal)] = plan.invoiceLines.map { ($0.invoiceId, $0.amount) }
        if plan.advanceAmount > 0 {
            lines.append((nil, plan.advanceAmount))
        }
        return lines.compactMap { line in
            let amount = SupplierFormatting.roundAmount(line.amount)
            guard amount > 0 else { return nil }
            return (line.invoiceId, amount)
        }
    }

    // MARK: - Clients

    static func fetchOpenInvoiceBalances() async throws -> [ClientInvoiceBalanceRow] {
        try await client
            .from("client_invoices")
            .select("client_id, suma_totala, suma_platita, status, data_scadenta, moneda")
            .in("status", values: [InvoiceStatus.neplatita.rawValue, InvoiceStatus.partial.rawValue])
            .execute()
            .value
    }

    static func buildBalanceSummaries(
        from invoices: [ClientInvoiceBalanceRow]
    ) -> [UUID: ClientBalanceSummary] {
        var result: [UUID: ClientBalanceSummary] = [:]
        for invoice in invoices {
            let rest = invoice.restDePlata
            guard rest != 0 else { continue }

            var summary = result[invoice.clientId] ?? ClientBalanceSummary()
            summary.soldRestant += rest
            summary.moneda = invoice.moneda
            if rest > 0, let scadenta = invoice.dataScadenta {
                if let current = summary.primaScadenta {
                    if scadenta < current { summary.primaScadenta = scadenta }
                } else {
                    summary.primaScadenta = scadenta
                }
            }
            result[invoice.clientId] = summary
        }
        for clientId in result.keys {
            guard var summary = result[clientId] else { continue }
            if summary.soldRestant <= 0 {
                summary.primaScadenta = nil
            }
            result[clientId] = summary
        }
        return result
    }

    static func fetchClientListRows() async throws -> [ClientListRow] {
        async let clientsTask = fetchClients()
        async let balancesTask = fetchOpenInvoiceBalances()
        async let advancesTask = fetchAdvancePaymentTotalsByClient()
        let (clients, invoices, advances) = try await (clientsTask, balancesTask, advancesTask)
        let summaries = buildBalanceSummaries(from: invoices)

        return clients
            .map { client in
                var summary = summaries[client.id] ?? ClientBalanceSummary()
                if let advance = advances[client.id] {
                    summary.soldRestant -= advance
                }
                if summary.soldRestant <= 0 {
                    summary.primaScadenta = nil
                }
                return ClientListRow(
                    client: client,
                    soldRestant: summary.soldRestant,
                    primaScadenta: summary.primaScadenta,
                    moneda: summary.moneda
                )
            }
            .sorted { $0.client.denumire.localizedStandardCompare($1.client.denumire) == .orderedAscending }
    }

    static func fetchClientAccount(
        clientId: UUID
    ) async throws -> ClientAccountSnapshot {
        async let clientTask = fetchClient(id: clientId)
        async let invoicesTask = fetchInvoicesForAccount(clientId: clientId)
        async let paymentsTask = fetchPayments(forClient: clientId)
        let client = try await clientTask
        async let counterpartTask = PartnerRoleService.hasSupplierCounterpart(for: client)
        let (invoices, payments, hasSupplierCounterpart) = try await (invoicesTask, paymentsTask, counterpartTask)

        let balance = accountBalance(from: invoices, payments: payments)
        let ledgerEntries = ClientAccountLedgerBuilder.build(
            invoices: invoices,
            payments: payments
        )

        return ClientAccountSnapshot(
            company: nil,
            client: client,
            ledgerEntries: ledgerEntries,
            soldRestant: balance.soldRestant,
            primaScadenta: balance.primaScadenta,
            moneda: balance.moneda,
            generatedAt: Date(),
            partnerRole: PartnerRole.forClient(hasSupplierCounterpart: hasSupplierCounterpart)
        )
    }

    static func balanceSummary(
        from invoices: [ClientInvoice],
        payments: [ClientPayment] = []
    ) -> ClientBalanceSummary {
        accountBalance(from: invoices, payments: payments)
    }

    private static func accountBalance(
        from invoices: [ClientInvoice],
        payments: [ClientPayment] = []
    ) -> ClientBalanceSummary {
        var summary = ClientBalanceSummary()
        for invoice in invoices where invoice.status == .neplatita || invoice.status == .partial {
            let rest = invoice.restDePlata
            guard rest != 0 else { continue }
            summary.soldRestant += rest
            summary.moneda = invoice.moneda
            if rest > 0 {
                let scadenta = invoice.effectiveDueDate
                if let current = summary.primaScadenta {
                    if scadenta < current { summary.primaScadenta = scadenta }
                } else {
                    summary.primaScadenta = scadenta
                }
            }
        }
        let advanceTotal = payments
            .filter { $0.invoiceId == nil }
            .reduce(Decimal.zero) { $0 + $1.suma }
        summary.soldRestant -= advanceTotal
        if summary.soldRestant <= 0 {
            summary.primaScadenta = nil
        }
        return summary
    }

    private static func fetchAdvancePaymentTotalsByClient() async throws -> [UUID: Decimal] {
        struct AdvancePaymentRow: Codable {
            let clientId: UUID
            @SupabaseDecimal var suma: Decimal

            enum CodingKeys: String, CodingKey {
                case suma
                case clientId = "client_id"
            }
        }

        let rows: [AdvancePaymentRow] = try await client
            .from("client_payments")
            .select("client_id, suma")
            .is("invoice_id", value: nil)
            .execute()
            .value

        var totals: [UUID: Decimal] = [:]
        for row in rows {
            totals[row.clientId, default: 0] += row.suma
        }
        return totals
    }

    static func fetchClient(id: UUID) async throws -> Client {
        let rows: [Client] = try await client
            .from("clients")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let client = rows.first else { throw ServiceError.invalidResponse }
        return client
    }

    static func fetchInvoicesForAccount(clientId: UUID) async throws -> [ClientInvoice] {
        let rows: [ClientInvoice] = try await client
            .from("client_invoices")
            .select()
            .eq("client_id", value: clientId.uuidString)
            .execute()
            .value
        return rows.sorted { $0.dataFactura < $1.dataFactura }
    }

    static func fetchUserDisplayNames(ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let rows: [UserDisplayName] = try await client
            .from("user_profiles")
            .select("id, nume, prenume")
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.displayName) })
    }

    static func fetchPayments(forClient clientId: UUID) async throws -> [ClientPayment] {
        try await client
            .from("client_payments")
            .select()
            .eq("client_id", value: clientId.uuidString)
            .order("data_plata", ascending: false)
            .execute()
            .value
    }

    static func fetchClients(activeOnly: Bool = false) async throws -> [Client] {
        if activeOnly {
            return try await client
                .from("clients")
                .select()
                .eq("is_active", value: true)
                .order("denumire", ascending: true)
                .execute()
                .value
        }
        return try await client
            .from("clients")
            .select()
            .order("denumire", ascending: true)
            .execute()
            .value
    }

    static func createClient(
        companyId: UUID,
        denumire: String,
        cui: String?,
        nrRegCom: String?,
        adresa: String?,
        iban: String?,
        email: String?,
        telefon: String?,
        observatii: String?,
        nrZileScadenta: Int,
        isActive: Bool
    ) async throws -> Client {
        let payload = ClientInsert(
            companyId: companyId,
            denumire: denumire,
            cui: emptyToNil(cui),
            nrRegCom: emptyToNil(nrRegCom),
            adresa: emptyToNil(adresa),
            iban: emptyToNil(iban),
            email: emptyToNil(email),
            telefon: emptyToNil(telefon),
            observatii: emptyToNil(observatii),
            nrZileScadenta: max(0, nrZileScadenta),
            isActive: isActive
        )
        let rows: [Client] = try await client
            .from("clients")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let client = rows.first else { throw ServiceError.invalidResponse }
        return client
    }

    static func updateClient(
        id: UUID,
        denumire: String,
        cui: String?,
        nrRegCom: String?,
        adresa: String?,
        iban: String?,
        email: String?,
        telefon: String?,
        observatii: String?,
        nrZileScadenta: Int,
        isActive: Bool
    ) async throws -> Client {
        let payload = ClientUpdate(
            denumire: denumire,
            cui: emptyToNil(cui),
            nrRegCom: emptyToNil(nrRegCom),
            adresa: emptyToNil(adresa),
            iban: emptyToNil(iban),
            email: emptyToNil(email),
            telefon: emptyToNil(telefon),
            observatii: emptyToNil(observatii),
            nrZileScadenta: max(0, nrZileScadenta),
            isActive: isActive
        )
        let rows: [Client] = try await client
            .from("clients")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value
        guard let client = rows.first else { throw ServiceError.invalidResponse }
        return client
    }

    static func deleteClient(id: UUID) async throws {
        struct DeleteClientParams: Encodable {
            let pClientId: UUID

            enum CodingKeys: String, CodingKey {
                case pClientId = "p_client_id"
            }
        }

        do {
            try await client
                .rpc("delete_client", params: DeleteClientParams(pClientId: id))
                .execute()
        } catch {
            throw ClientDeleteError.map(error)
        }
    }

    static func clientHasInvoices(clientId: UUID) async throws -> Bool {
        struct InvoiceRef: Decodable {
            let id: UUID
        }

        let rows: [InvoiceRef] = try await client
            .from("client_invoices")
            .select("id")
            .eq("client_id", value: clientId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Invoices

    static func fetchInvoices(
        dateFilter: InvoiceListDateFilter = .none
    ) async throws -> [ClientInvoiceRow] {
        let rows: [ClientInvoiceRow] = try await SupabasePaging.fetchAll { from, to in
            var query = client
                .from("client_invoices")
                .select("*, client:clients(denumire)")
            query = applyDateFilter(query, dateFilter)
            return try await query
                .order("created_at", ascending: false)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
        }
        return rows.sorted(by: compareInvoiceRowsByDueDate)
    }

    private static func applyDateFilter(
        _ query: PostgrestFilterBuilder,
        _ dateFilter: InvoiceListDateFilter
    ) -> PostgrestFilterBuilder {
        switch dateFilter {
        case .none:
            return query
        case .created(let start, let end):
            return query
                .gte("created_at", value: InvoiceListDateFilter.timestampString(start))
                .lt("created_at", value: InvoiceListDateFilter.timestampString(end))
        case .invoiceDate(let start, let end):
            return query
                .gte("data_factura", value: InvoiceListDateFilter.dateOnlyString(start))
                .lte("data_factura", value: InvoiceListDateFilter.dateOnlyString(end))
        }
    }

    static func fetchInvoiceRow(id: UUID) async throws -> ClientInvoiceRow {
        let rows: [ClientInvoiceRow] = try await client
            .from("client_invoices")
            .select("*, client:clients(denumire)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func fetchInvoices(forClient clientId: UUID) async throws -> [ClientInvoice] {
        let rows: [ClientInvoice] = try await client
            .from("client_invoices")
            .select()
            .eq("client_id", value: clientId.uuidString)
            .neq("status", value: InvoiceStatus.anulata.rawValue)
            .execute()
            .value
        return rows.sorted(by: compareInvoicesByDueDate)
    }

    private static func compareInvoiceRowsByDueDate(_ lhs: ClientInvoiceRow, _ rhs: ClientInvoiceRow) -> Bool {
        compareDueDates(lhs.dataScadenta, rhs.dataScadenta, fallback: lhs.dataFactura, rhs.dataFactura)
    }

    private static func compareInvoicesByDueDate(_ lhs: ClientInvoice, _ rhs: ClientInvoice) -> Bool {
        compareDueDates(lhs.dataScadenta, rhs.dataScadenta, fallback: lhs.dataFactura, rhs.dataFactura)
    }

    /// Cea mai apropiată scadență prima; facturile fără scadență la final.
    private static func compareDueDates(
        _ lhsDue: Date?,
        _ rhsDue: Date?,
        fallback lhsDate: Date,
        _ rhsDate: Date
    ) -> Bool {
        switch (lhsDue, rhsDue) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, .some):
            return lhsDate < rhsDate
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case (nil, nil):
            return lhsDate < rhsDate
        }
    }

    static func createInvoice(
        companyId: UUID,
        clientId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?,
        createdBy: UUID?
    ) async throws -> ClientInvoice {
        let payload = InvoiceInsert(
            companyId: companyId,
            clientId: clientId,
            numarFactura: numarFactura,
            dataFactura: dateString(dataFactura),
            dataScadenta: dataScadenta.map(dateString),
            sumaTotala: doubleAmount(sumaTotala),
            sumaTva: doubleAmount(sumaTva),
            moneda: moneda,
            status: status.rawValue,
            observatii: emptyToNil(observatii),
            createdBy: createdBy
        )
        let rows: [ClientInvoice] = try await client
            .from("client_invoices")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let invoice = rows.first else { throw ServiceError.invalidResponse }
        return invoice
    }

    static func updateInvoice(
        id: UUID,
        clientId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?
    ) async throws -> ClientInvoice {
        let payload = InvoiceUpdate(
            clientId: clientId,
            numarFactura: numarFactura,
            dataFactura: dateString(dataFactura),
            dataScadenta: dataScadenta.map(dateString),
            sumaTotala: doubleAmount(sumaTotala),
            sumaTva: doubleAmount(sumaTva),
            moneda: moneda,
            status: status.rawValue,
            observatii: emptyToNil(observatii)
        )
        let rows: [ClientInvoice] = try await client
            .from("client_invoices")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value
        guard let invoice = rows.first else { throw ServiceError.invalidResponse }
        return invoice
    }

    static func deleteInvoice(id: UUID) async throws {
        if try await invoiceHasPayments(invoiceId: id) {
            throw InvoiceDeleteError.hasRegisteredPayments
        }

        struct DeleteInvoiceParams: Encodable {
            let pInvoiceId: UUID

            enum CodingKeys: String, CodingKey {
                case pInvoiceId = "p_invoice_id"
            }
        }

        struct DeletedInvoiceRef: Decodable {
            let id: UUID
        }

        do {
            try await client
                .rpc("delete_client_invoice", params: DeleteInvoiceParams(pInvoiceId: id))
                .execute()
        } catch {
            throw InvoiceDeleteError.map(error)
        }

        let remaining: [DeletedInvoiceRef] = try await client
            .from("client_invoices")
            .select("id")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        if !remaining.isEmpty {
            throw InvoiceDeleteError.deleteFailed
        }
    }

    static func invoiceHasPayments(invoiceId: UUID) async throws -> Bool {
        struct PaymentRef: Decodable {
            let id: UUID
        }

        let rows: [PaymentRef] = try await client
            .from("client_payments")
            .select("id")
            .eq("invoice_id", value: invoiceId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Payments

    static func fetchPayments() async throws -> [ClientPaymentRow] {
        try await client
            .from("client_payments")
            .select("*, client:clients(denumire), invoice:client_invoices(numar_factura)")
            .order("data_plata", ascending: false)
            .execute()
            .value
    }

    static func fetchCashPayments() async throws -> [ClientPaymentRow] {
        try await client
            .from("client_payments")
            .select("*, client:clients(denumire), invoice:client_invoices(numar_factura)")
            .eq("metoda_plata", value: PaymentMethod.numerar.rawValue)
            .order("data_plata", ascending: true)
            .execute()
            .value
    }

    static func fetchPaymentRow(id: UUID) async throws -> ClientPaymentRow {
        let rows: [ClientPaymentRow] = try await client
            .from("client_payments")
            .select("*, client:clients(denumire), invoice:client_invoices(numar_factura)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func createPayment(
        companyId: UUID,
        clientId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) async throws -> ClientPayment {
        let payload = PaymentInsert(
            companyId: companyId,
            clientId: clientId,
            invoiceId: invoiceId,
            dataPlata: dateString(dataPlata),
            suma: doubleAmount(suma),
            metodaPlata: metodaPlata.rawValue,
            referinta: emptyToNil(referinta),
            observatii: emptyToNil(observatii),
            createdBy: createdBy
        )
        let rows: [ClientPayment] = try await client
            .from("client_payments")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let payment = rows.first else { throw ServiceError.invalidResponse }
        return payment
    }

    static func createPaymentsFromPlan(
        companyId: UUID,
        clientId: UUID,
        plan: ClientPaymentAllocationPlan,
        dataPlata: Date,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) async throws -> [ClientPayment] {
        let sanitizedPlan = ClientPaymentAllocation.sanitizedPlan(plan)
        let lines = paymentAmountLines(from: sanitizedPlan)
        guard !lines.isEmpty else {
            throw ServiceError.server(L10n.tr("client_collections.invalid_plan"))
        }

        var created: [ClientPayment] = []
        do {
            for line in lines {
                let payment = try await createPayment(
                    companyId: companyId,
                    clientId: clientId,
                    invoiceId: line.invoiceId,
                    dataPlata: dataPlata,
                    suma: line.amount,
                    metodaPlata: metodaPlata,
                    referinta: referinta,
                    observatii: observatii,
                    createdBy: createdBy
                )
                created.append(payment)
            }
            return created
        } catch {
            for payment in created.reversed() {
                try? await deletePayment(id: payment.id)
            }
            throw error
        }
    }

    static func updatePayment(
        id: UUID,
        clientId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?
    ) async throws -> ClientPayment {
        let payload = PaymentUpdate(
            clientId: clientId,
            invoiceId: invoiceId,
            dataPlata: dateString(dataPlata),
            suma: doubleAmount(suma),
            metodaPlata: metodaPlata.rawValue,
            referinta: emptyToNil(referinta),
            observatii: emptyToNil(observatii)
        )
        let rows: [ClientPayment] = try await client
            .from("client_payments")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value
        guard let payment = rows.first else { throw ServiceError.invalidResponse }
        return payment
    }

    static func deletePayment(id: UUID) async throws {
        try await client
            .from("client_payments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
