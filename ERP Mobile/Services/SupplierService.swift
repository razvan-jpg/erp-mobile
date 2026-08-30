import Foundation
import Supabase

private struct SupplierInsert: Encodable {
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

private struct SupplierUpdate: Encodable {
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
    let supplierId: UUID
    let numarFactura: String
    let dataFactura: String
    let dataScadenta: String?
    let sumaTotala: Double
    let sumaTva: Double
    let moneda: String
    let status: String
    let observatii: String?
    let workLocationId: UUID?
    let warehouseId: UUID?
    let createdBy: UUID?

    enum CodingKeys: String, CodingKey {
        case moneda, status, observatii
        case companyId = "company_id"
        case supplierId = "supplier_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
        case createdBy = "created_by"
    }
}

private struct InvoiceUpdate: Encodable {
    let supplierId: UUID
    let numarFactura: String
    let dataFactura: String
    let dataScadenta: String?
    let sumaTotala: Double
    let sumaTva: Double
    let moneda: String
    let status: String
    let observatii: String?
    let workLocationId: UUID?
    let warehouseId: UUID?

    enum CodingKeys: String, CodingKey {
        case moneda, status, observatii
        case supplierId = "supplier_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
    }
}

private struct PaymentInsert: Encodable {
    let companyId: UUID
    let supplierId: UUID
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
        case supplierId = "supplier_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdBy = "created_by"
    }
}

private struct PaymentUpdate: Encodable {
    let supplierId: UUID
    let invoiceId: UUID?
    let dataPlata: String
    let suma: Double
    let metodaPlata: String
    let referinta: String?
    let observatii: String?

    enum CodingKeys: String, CodingKey {
        case suma, referinta, observatii
        case supplierId = "supplier_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
    }
}

private struct InvoiceLineInsert: Encodable {
    let companyId: UUID
    let invoiceId: UUID
    let productId: UUID
    let numarLinie: Int
    let denumire: String
    let cantitate: Double
    let pretUnitar: Double
    let sumaLinie: Double
        let sumaTva: Double
        let cotaTva: Double
        let unitateMasura: String

    enum CodingKeys: String, CodingKey {
        case denumire, cantitate
        case companyId = "company_id"
        case invoiceId = "invoice_id"
        case productId = "product_id"
        case numarLinie = "numar_linie"
        case pretUnitar = "pret_unitar"
        case sumaLinie = "suma_linie"
        case sumaTva = "suma_tva"
        case cotaTva = "cota_tva"
        case unitateMasura = "unitate_masura"
    }
}

enum SupplierService {
    private static let client = SupabaseManager.client

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dateString(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    private static func doubleAmount(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: SupplierFormatting.roundAmount(value)).doubleValue
    }

    private static func paymentAmountLines(from plan: PaymentAllocationPlan) -> [(invoiceId: UUID?, amount: Decimal)] {
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

    // MARK: - Suppliers

    static func fetchOpenInvoiceBalances() async throws -> [SupplierInvoiceBalanceRow] {
        try await client
            .from("supplier_invoices")
            .select("supplier_id, suma_totala, suma_platita, status, data_scadenta, moneda")
            .in("status", values: [InvoiceStatus.neplatita.rawValue, InvoiceStatus.partial.rawValue])
            .execute()
            .value
    }

    static func buildBalanceSummaries(
        from invoices: [SupplierInvoiceBalanceRow]
    ) -> [UUID: SupplierBalanceSummary] {
        var result: [UUID: SupplierBalanceSummary] = [:]
        for invoice in invoices {
            let rest = invoice.restDePlata
            guard rest != 0 else { continue }

            var summary = result[invoice.supplierId] ?? SupplierBalanceSummary()
            summary.soldRestant += rest
            summary.moneda = invoice.moneda
            if rest > 0, let scadenta = invoice.dataScadenta {
                if let current = summary.primaScadenta {
                    if scadenta < current { summary.primaScadenta = scadenta }
                } else {
                    summary.primaScadenta = scadenta
                }
            }
            result[invoice.supplierId] = summary
        }
        for supplierId in result.keys {
            guard var summary = result[supplierId] else { continue }
            if summary.soldRestant <= 0 {
                summary.primaScadenta = nil
            }
            result[supplierId] = summary
        }
        return result
    }

    static func fetchSupplierListRows() async throws -> [SupplierListRow] {
        async let suppliersTask = fetchSuppliers()
        async let balancesTask = fetchOpenInvoiceBalances()
        async let advancesTask = fetchAdvancePaymentTotalsBySupplier()
        let (suppliers, invoices, advances) = try await (suppliersTask, balancesTask, advancesTask)
        let summaries = buildBalanceSummaries(from: invoices)

        return suppliers
            .map { supplier in
                var summary = summaries[supplier.id] ?? SupplierBalanceSummary()
                if let advance = advances[supplier.id] {
                    summary.soldRestant -= advance
                }
                if summary.soldRestant <= 0 {
                    summary.primaScadenta = nil
                }
                return SupplierListRow(
                    supplier: supplier,
                    soldRestant: summary.soldRestant,
                    primaScadenta: summary.primaScadenta,
                    moneda: summary.moneda
                )
            }
            .sorted { $0.supplier.denumire.localizedStandardCompare($1.supplier.denumire) == .orderedAscending }
    }

    static func fetchSupplierAccount(
        supplierId: UUID
    ) async throws -> SupplierAccountSnapshot {
        async let supplierTask = fetchSupplier(id: supplierId)
        async let invoicesTask = fetchInvoicesForAccount(supplierId: supplierId)
        async let paymentsTask = fetchPayments(forSupplier: supplierId)
        async let offsetsTask = fetchCreditOffsets(forSupplier: supplierId)
        let supplier = try await supplierTask
        async let counterpartTask = PartnerRoleService.hasClientCounterpart(for: supplier)
        let (invoices, payments, creditOffsets, hasClientCounterpart) = try await (
            invoicesTask,
            paymentsTask,
            offsetsTask,
            counterpartTask
        )

        let balance = accountBalance(from: invoices, payments: payments)
        let ledgerEntries = SupplierAccountLedgerBuilder.build(
            invoices: invoices,
            payments: payments,
            creditOffsets: creditOffsets
        )

        return SupplierAccountSnapshot(
            company: nil,
            supplier: supplier,
            ledgerEntries: ledgerEntries,
            soldRestant: balance.soldRestant,
            primaScadenta: balance.primaScadenta,
            moneda: balance.moneda,
            generatedAt: Date(),
            partnerRole: PartnerRole.forSupplier(hasClientCounterpart: hasClientCounterpart)
        )
    }

    static func balanceSummary(
        from invoices: [SupplierInvoice],
        payments: [SupplierPayment] = []
    ) -> SupplierBalanceSummary {
        accountBalance(from: invoices, payments: payments)
    }

    private static func accountBalance(
        from invoices: [SupplierInvoice],
        payments: [SupplierPayment] = []
    ) -> SupplierBalanceSummary {
        var summary = SupplierBalanceSummary()
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

    private static func fetchAdvancePaymentTotalsBySupplier() async throws -> [UUID: Decimal] {
        struct AdvancePaymentRow: Codable {
            let supplierId: UUID
            @SupabaseDecimal var suma: Decimal

            enum CodingKeys: String, CodingKey {
                case suma
                case supplierId = "supplier_id"
            }
        }

        let rows: [AdvancePaymentRow] = try await client
            .from("supplier_payments")
            .select("supplier_id, suma")
            .is("invoice_id", value: nil)
            .execute()
            .value

        var totals: [UUID: Decimal] = [:]
        for row in rows {
            totals[row.supplierId, default: 0] += row.suma
        }
        return totals
    }

    static func fetchSupplier(id: UUID) async throws -> Supplier {
        let rows: [Supplier] = try await client
            .from("suppliers")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let supplier = rows.first else { throw ServiceError.invalidResponse }
        return supplier
    }

    static func fetchInvoicesForAccount(supplierId: UUID) async throws -> [SupplierInvoice] {
        let rows: [SupplierInvoice] = try await client
            .from("supplier_invoices")
            .select()
            .eq("supplier_id", value: supplierId.uuidString)
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

    static func fetchPayments(forSupplier supplierId: UUID) async throws -> [SupplierPayment] {
        try await client
            .from("supplier_payments")
            .select()
            .eq("supplier_id", value: supplierId.uuidString)
            .order("data_plata", ascending: false)
            .execute()
            .value
    }

    static func fetchSuppliers(activeOnly: Bool = false) async throws -> [Supplier] {
        if activeOnly {
            return try await client
                .from("suppliers")
                .select()
                .eq("is_active", value: true)
                .order("denumire", ascending: true)
                .execute()
                .value
        }
        return try await client
            .from("suppliers")
            .select()
            .order("denumire", ascending: true)
            .execute()
            .value
    }

    static func createSupplier(
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
    ) async throws -> Supplier {
        let payload = SupplierInsert(
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
        let rows: [Supplier] = try await client
            .from("suppliers")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let supplier = rows.first else { throw ServiceError.invalidResponse }
        return supplier
    }

    static func updateSupplier(
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
    ) async throws -> Supplier {
        let payload = SupplierUpdate(
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
        let rows: [Supplier] = try await client
            .from("suppliers")
            .update(payload)
            .eq("id", value: id.uuidString)
            .select()
            .execute()
            .value
        guard let supplier = rows.first else { throw ServiceError.invalidResponse }
        return supplier
    }

    static func deleteSupplier(id: UUID) async throws {
        struct DeleteSupplierParams: Encodable {
            let pSupplierId: UUID

            enum CodingKeys: String, CodingKey {
                case pSupplierId = "p_supplier_id"
            }
        }

        do {
            try await client
                .rpc("delete_supplier", params: DeleteSupplierParams(pSupplierId: id))
                .execute()
        } catch {
            throw SupplierDeleteError.map(error)
        }
    }

    static func supplierHasInvoices(supplierId: UUID) async throws -> Bool {
        struct InvoiceRef: Decodable {
            let id: UUID
        }

        let rows: [InvoiceRef] = try await client
            .from("supplier_invoices")
            .select("id")
            .eq("supplier_id", value: supplierId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Invoices

    static func fetchInvoices() async throws -> [SupplierInvoiceRow] {
        let rows: [SupplierInvoiceRow] = try await client
            .from("supplier_invoices")
            .select("*, supplier:suppliers(denumire)")
            .execute()
            .value
        return rows.sorted(by: compareInvoiceRowsByDueDate)
    }

    static func fetchInvoiceRow(id: UUID) async throws -> SupplierInvoiceRow {
        let rows: [SupplierInvoiceRow] = try await client
            .from("supplier_invoices")
            .select("*, supplier:suppliers(denumire)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func fetchInvoice(id: UUID) async throws -> SupplierInvoice {
        let rows: [SupplierInvoice] = try await client
            .from("supplier_invoices")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let invoice = rows.first else { throw ServiceError.invalidResponse }
        return invoice
    }

    static func fetchInvoices(forSupplier supplierId: UUID) async throws -> [SupplierInvoice] {
        let rows: [SupplierInvoice] = try await client
            .from("supplier_invoices")
            .select()
            .eq("supplier_id", value: supplierId.uuidString)
            .neq("status", value: InvoiceStatus.anulata.rawValue)
            .execute()
            .value
        return rows.sorted(by: compareInvoicesByDueDate)
    }

    private static func compareInvoiceRowsByDueDate(_ lhs: SupplierInvoiceRow, _ rhs: SupplierInvoiceRow) -> Bool {
        compareDueDates(lhs.dataScadenta, rhs.dataScadenta, fallback: lhs.dataFactura, rhs.dataFactura)
    }

    private static func compareInvoicesByDueDate(_ lhs: SupplierInvoice, _ rhs: SupplierInvoice) -> Bool {
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
        supplierId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createdBy: UUID?
    ) async throws -> SupplierInvoice {
        let payload = InvoiceInsert(
            companyId: companyId,
            supplierId: supplierId,
            numarFactura: numarFactura,
            dataFactura: dateString(dataFactura),
            dataScadenta: dataScadenta.map(dateString),
            sumaTotala: doubleAmount(sumaTotala),
            sumaTva: doubleAmount(sumaTva),
            moneda: moneda,
            status: status.rawValue,
            observatii: emptyToNil(observatii),
            workLocationId: workLocationId,
            warehouseId: warehouseId,
            createdBy: createdBy
        )
        let rows: [SupplierInvoice] = try await client
            .from("supplier_invoices")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let invoice = rows.first else { throw ServiceError.invalidResponse }
        return invoice
    }

    static func updateInvoice(
        id: UUID,
        supplierId: UUID,
        numarFactura: String,
        dataFactura: Date,
        dataScadenta: Date?,
        sumaTotala: Decimal,
        sumaTva: Decimal,
        moneda: String,
        status: InvoiceStatus,
        observatii: String?,
        workLocationId: UUID? = nil,
        warehouseId: UUID? = nil
    ) async throws -> SupplierInvoice {
        let payload = InvoiceUpdate(
            supplierId: supplierId,
            numarFactura: numarFactura,
            dataFactura: dateString(dataFactura),
            dataScadenta: dataScadenta.map(dateString),
            sumaTotala: doubleAmount(sumaTotala),
            sumaTva: doubleAmount(sumaTva),
            moneda: moneda,
            status: status.rawValue,
            observatii: emptyToNil(observatii),
            workLocationId: workLocationId,
            warehouseId: warehouseId
        )
        let rows: [SupplierInvoice] = try await client
            .from("supplier_invoices")
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
                .rpc("delete_supplier_invoice", params: DeleteInvoiceParams(pInvoiceId: id))
                .execute()
        } catch {
            throw InvoiceDeleteError.map(error)
        }

        let remaining: [DeletedInvoiceRef] = try await client
            .from("supplier_invoices")
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
            .from("supplier_payments")
            .select("id")
            .eq("invoice_id", value: invoiceId.uuidString)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    // MARK: - Payments

    static func fetchPayments() async throws -> [SupplierPaymentRow] {
        try await client
            .from("supplier_payments")
            .select("*, supplier:suppliers(denumire), invoice:supplier_invoices(numar_factura)")
            .order("data_plata", ascending: false)
            .execute()
            .value
    }

    /// Chitanțe de plată numerar (Furnizori → Plăți) pentru Registru de casă.
    static func fetchCashPayments(upTo endDate: Date? = nil) async throws -> [SupplierPaymentRow] {
        let rows: [SupplierPaymentRow] = try await client
            .from("supplier_payments")
            .select("*, supplier:suppliers(denumire), invoice:supplier_invoices(numar_factura)")
            .eq("metoda_plata", value: PaymentMethod.numerar.rawValue)
            .order("data_plata", ascending: true)
            .execute()
            .value
        guard let endDate else { return rows }
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.startOfDay(for: endDate)
        return rows.filter { calendar.startOfDay(for: $0.dataPlata) <= end }
    }

    static func fetchPaymentRow(id: UUID) async throws -> SupplierPaymentRow {
        let rows: [SupplierPaymentRow] = try await client
            .from("supplier_payments")
            .select("*, supplier:suppliers(denumire), invoice:supplier_invoices(numar_factura)")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func createPayment(
        companyId: UUID,
        supplierId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) async throws -> SupplierPayment {
        let payload = PaymentInsert(
            companyId: companyId,
            supplierId: supplierId,
            invoiceId: invoiceId,
            dataPlata: dateString(dataPlata),
            suma: doubleAmount(suma),
            metodaPlata: metodaPlata.rawValue,
            referinta: emptyToNil(referinta),
            observatii: emptyToNil(observatii),
            createdBy: createdBy
        )
        let rows: [SupplierPayment] = try await client
            .from("supplier_payments")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let payment = rows.first else { throw ServiceError.invalidResponse }
        return payment
    }

    static func createPaymentsFromPlan(
        companyId: UUID,
        supplierId: UUID,
        plan: PaymentAllocationPlan,
        dataPlata: Date,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?,
        createdBy: UUID?
    ) async throws -> [SupplierPayment] {
        let sanitizedPlan = PaymentAllocation.sanitizedPlan(plan)
        let lines = paymentAmountLines(from: sanitizedPlan)
        guard !lines.isEmpty else {
            throw ServiceError.server(L10n.tr("payments.invalid_plan"))
        }

        var created: [SupplierPayment] = []
        do {
            for line in lines {
                let payment = try await createPayment(
                    companyId: companyId,
                    supplierId: supplierId,
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
        supplierId: UUID,
        invoiceId: UUID?,
        dataPlata: Date,
        suma: Decimal,
        metodaPlata: PaymentMethod,
        referinta: String?,
        observatii: String?
    ) async throws -> SupplierPayment {
        let payload = PaymentUpdate(
            supplierId: supplierId,
            invoiceId: invoiceId,
            dataPlata: dateString(dataPlata),
            suma: doubleAmount(suma),
            metodaPlata: metodaPlata.rawValue,
            referinta: emptyToNil(referinta),
            observatii: emptyToNil(observatii)
        )
        let rows: [SupplierPayment] = try await client
            .from("supplier_payments")
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
            .from("supplier_payments")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    struct InvoiceLineCreateInput: Sendable {
        let productId: UUID
        let numarLinie: Int
        let denumire: String
        let cantitate: Decimal
        let pretUnitar: Decimal
        let sumaLinie: Decimal
        let sumaTva: Decimal
        let cotaTva: Decimal
        let unitateMasura: String
    }

    static func createInvoiceLines(
        companyId: UUID,
        invoiceId: UUID,
        lines: [InvoiceLineCreateInput]
    ) async throws {
        guard !lines.isEmpty else { return }

        let payload = lines.map { line in
            InvoiceLineInsert(
                companyId: companyId,
                invoiceId: invoiceId,
                productId: line.productId,
                numarLinie: line.numarLinie,
                denumire: line.denumire,
                cantitate: doubleAmount(line.cantitate),
                pretUnitar: doubleAmount(line.pretUnitar),
                sumaLinie: doubleAmount(line.sumaLinie),
                sumaTva: doubleAmount(line.sumaTva),
                cotaTva: doubleAmount(line.cotaTva),
                unitateMasura: line.unitateMasura
            )
        }
        try await client
            .from("supplier_invoice_lines")
            .insert(payload)
            .execute()
    }

    static func fetchInvoiceLines(invoiceId: UUID) async throws -> [SupplierInvoiceLine] {
        try await client
            .from("supplier_invoice_lines")
            .select()
            .eq("invoice_id", value: invoiceId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
    }

    static func replaceInvoiceLines(
        companyId: UUID,
        invoiceId: UUID,
        lines: [InvoiceLineCreateInput]
    ) async throws {
        try await client
            .from("supplier_invoice_lines")
            .delete()
            .eq("invoice_id", value: invoiceId.uuidString)
            .execute()

        try await createInvoiceLines(
            companyId: companyId,
            invoiceId: invoiceId,
            lines: lines
        )
    }

    // MARK: - Credit note offsets

    static func fetchCreditOffsets(forSupplier supplierId: UUID) async throws -> [SupplierInvoiceCreditOffset] {
        let invoiceIds = try await fetchInvoicesForAccount(supplierId: supplierId).map(\.id)
        guard !invoiceIds.isEmpty else { return [] }

        let rows: [SupplierInvoiceCreditOffset] = try await client
            .from("supplier_invoice_credit_offsets")
            .select()
            .in("credit_invoice_id", values: invoiceIds)
            .execute()
            .value
        return rows
    }

    static func fetchCreditOffsets(creditInvoiceId: UUID) async throws -> [SupplierInvoiceCreditOffset] {
        try await client
            .from("supplier_invoice_credit_offsets")
            .select()
            .eq("credit_invoice_id", value: creditInvoiceId.uuidString)
            .execute()
            .value
    }

    static func replaceCreditNoteOffsets(
        companyId: UUID,
        creditInvoice: SupplierInvoice,
        plan: PaymentAllocationPlan
    ) async throws {
        guard creditInvoice.isCreditNote else {
            throw CreditNoteOffsetError.notCreditNote
        }

        let sanitized = PaymentAllocation.sanitizedPlan(plan)
        let availableCredit = creditInvoice.availableCreditAmount
        let appliedTotal = SupplierFormatting.roundAmount(
            sanitized.invoiceLines.reduce(Decimal.zero) { $0 + $1.amount }
        )
        if appliedTotal > SupplierFormatting.roundAmount(availableCredit) {
            throw CreditNoteOffsetError.amountExceedsAvailableCredit
        }

        let supplierInvoices = try await fetchInvoicesForAccount(supplierId: creditInvoice.supplierId)
        let invoiceById = Dictionary(uniqueKeysWithValues: supplierInvoices.map { ($0.id, $0) })

        for line in sanitized.invoiceLines {
            guard let target = invoiceById[line.invoiceId] else {
                throw CreditNoteOffsetError.targetInvoiceInvalid
            }
            guard target.supplierId == creditInvoice.supplierId, !target.isCreditNote else {
                throw CreditNoteOffsetError.targetInvoiceInvalid
            }
            guard SupplierFormatting.roundAmount(line.amount) <= SupplierFormatting.roundAmount(target.restDePlata) else {
                throw CreditNoteOffsetError.targetInvoiceInvalid
            }
        }

        try await client
            .from("supplier_invoice_credit_offsets")
            .delete()
            .eq("credit_invoice_id", value: creditInvoice.id.uuidString)
            .execute()

        guard !sanitized.invoiceLines.isEmpty else { return }

        struct OffsetInsert: Encodable {
            let companyId: UUID
            let creditInvoiceId: UUID
            let targetInvoiceId: UUID
            let amount: Double

            enum CodingKeys: String, CodingKey {
                case amount
                case companyId = "company_id"
                case creditInvoiceId = "credit_invoice_id"
                case targetInvoiceId = "target_invoice_id"
            }
        }

        let payload = sanitized.invoiceLines.map { line in
            OffsetInsert(
                companyId: companyId,
                creditInvoiceId: creditInvoice.id,
                targetInvoiceId: line.invoiceId,
                amount: doubleAmount(line.amount)
            )
        }

        try await client
            .from("supplier_invoice_credit_offsets")
            .insert(payload)
            .execute()
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
