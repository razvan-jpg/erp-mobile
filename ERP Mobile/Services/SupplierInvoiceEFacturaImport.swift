import Foundation

struct EFacturaImportPreviewItem: Identifiable, Sendable {
    let id: String
    let fileURL: URL
    let fileName: String
    let invoiceNumber: String
    let supplierName: String
    let issueDate: Date
    let totalAmount: Decimal
    let currency: String
    let lineCount: Int
    let isDuplicate: Bool
    let duplicateLabel: String?
    let isCreditNote: Bool
    let errorMessage: String?
    var createNIR: Bool

    var canImport: Bool {
        errorMessage == nil && !isDuplicate
    }
}

struct EFacturaImportResult: Sendable {
    let importedCount: Int
    let linesImportedCount: Int
    let productsCreatedCount: Int
    let skippedDuplicates: [String]
    let failures: [EFacturaImportFailure]
    let pendingNIRInvoiceIds: [UUID]
    let pendingCreditNoteOffsetInvoiceIds: [UUID]
}

struct EFacturaImportFailure: Sendable {
    let fileName: String
    let message: String
}

enum EFacturaImportError: LocalizedError {
    case companyCUIMissing
    case buyerCUIMissing
    case buyerMismatch(companyName: String, buyerName: String, companyCUI: String, buyerCUI: String)

    var errorDescription: String? {
        switch self {
        case .companyCUIMissing:
            return L10n.tr("invoices.import_error_company_cui_missing")
        case .buyerCUIMissing:
            return L10n.tr("invoices.import_error_buyer_cui_missing")
        case .buyerMismatch(let companyName, let buyerName, let companyCUI, let buyerCUI):
            return L10n.tr(
                "invoices.import_error_buyer_mismatch",
                companyName,
                companyCUI,
                buyerName,
                buyerCUI
            )
        }
    }
}

enum SupplierInvoiceEFacturaImport {
    static func canImportItems(
        _ items: [EFacturaImportPreviewItem],
        receptionOptions: InvoiceReceptionOptions,
        receptionRequirements: InvoiceReceptionRequirements
    ) -> Bool {
        let importable = items.filter(\.canImport)
        guard !importable.isEmpty else { return false }

        let needsReceptionFields = importable.contains { !$0.createNIR && !$0.isCreditNote }
        if !needsReceptionFields { return true }

        if receptionRequirements.requiresWorkLocation, receptionOptions.workLocationId == nil {
            return false
        }
        if receptionRequirements.requiresWarehouse, receptionOptions.warehouseId == nil {
            return false
        }
        return true
    }

    static func previewFiles(urls: [URL], company: Company) async -> [EFacturaImportPreviewItem] {
        let suppliers: [Supplier]
        let existingInvoices: [SupplierInvoiceRow]
        do {
            suppliers = try await SupplierService.fetchSuppliers()
            existingInvoices = try await SupplierService.fetchInvoices()
        } catch {
            return urls.enumerated().map { index, url in
                EFacturaImportPreviewItem(
                    id: previewItemID(for: url, index: index),
                    fileURL: url,
                    fileName: url.lastPathComponent,
                    invoiceNumber: "—",
                    supplierName: "—",
                    issueDate: Date(),
                    totalAmount: .zero,
                    currency: "RON",
                    lineCount: 0,
                    isDuplicate: false,
                    duplicateLabel: nil,
                    isCreditNote: false,
                    errorMessage: error.localizedDescription,
                    createNIR: false
                )
            }
        }

        var supplierCache = suppliers
        var importedKeys = SupplierInvoiceDuplicateCheck.duplicateKeySet(
            from: existingInvoices,
            suppliers: suppliers
        )
        var previewSupplierIds: [String: UUID] = [:]

        var items: [EFacturaImportPreviewItem] = []
        items.reserveCapacity(urls.count)
        for (index, url) in sortedURLsByIssueDate(urls).enumerated() {
            let item = previewFile(
                url: url,
                previewId: previewItemID(for: url, index: index),
                company: company,
                suppliers: &supplierCache,
                importedKeys: &importedKeys,
                previewSupplierIds: &previewSupplierIds
            )
            items.append(item)
        }
        return sortedPreviewItemsByIssueDate(items)
    }

    private static func sortedURLsByIssueDate(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            let lhsDate = issueDate(from: lhs) ?? .distantFuture
            let rhsDate = issueDate(from: rhs) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            if lhs.lastPathComponent != rhs.lastPathComponent {
                return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
            }
            return lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    private static func sortedPreviewItemsByIssueDate(_ items: [EFacturaImportPreviewItem]) -> [EFacturaImportPreviewItem] {
        items.sorted { lhs, rhs in
            if lhs.issueDate != rhs.issueDate {
                return lhs.issueDate < rhs.issueDate
            }
            if lhs.invoiceNumber != rhs.invoiceNumber {
                return lhs.invoiceNumber.localizedStandardCompare(rhs.invoiceNumber) == .orderedAscending
            }
            return lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }
    }

    private static func issueDate(from url: URL) -> Date? {
        guard let data = try? readFileData(from: url),
              let parsed = try? EFacturaInvoiceParser.parse(data: data) else {
            return nil
        }
        return parsed.issueDate
    }

    private static func previewItemID(for url: URL, index: Int) -> String {
        "\(url.absoluteString)#\(index)"
    }

    static func importFiles(
        items: [EFacturaImportPreviewItem],
        company: Company,
        receptionOptions: InvoiceReceptionOptions,
        receptionRequirements: InvoiceReceptionRequirements,
        createdBy: UUID?
    ) async -> EFacturaImportResult {
        let importableItems = sortedPreviewItemsByIssueDate(items.filter(\.canImport))
        var importedCount = 0
        var linesImportedCount = 0
        var productsCreatedCount = 0
        var skippedDuplicates: [String] = []
        var failures: [EFacturaImportFailure] = []
        var pendingNIRInvoiceIds: [UUID] = []
        var pendingCreditNoteOffsetInvoiceIds: [UUID] = []

        for item in items where item.isDuplicate {
            if let label = item.duplicateLabel {
                skippedDuplicates.append(label)
            } else {
                skippedDuplicates.append(item.fileName)
            }
        }

        for item in items where item.errorMessage != nil && !item.isDuplicate {
            failures.append(
                EFacturaImportFailure(
                    fileName: item.fileName,
                    message: item.errorMessage ?? L10n.tr("invoices.import_error_invalid_xml")
                )
            )
        }

        guard canImportItems(items, receptionOptions: receptionOptions, receptionRequirements: receptionRequirements) else {
            if importableItems.isEmpty {
                return EFacturaImportResult(
                    importedCount: 0,
                    linesImportedCount: 0,
                    productsCreatedCount: 0,
                    skippedDuplicates: skippedDuplicates,
                    failures: failures,
                    pendingNIRInvoiceIds: [],
                    pendingCreditNoteOffsetInvoiceIds: []
                )
            }

            let receptionError = L10n.tr("invoices.reception_required")
            failures.append(contentsOf: importableItems.map {
                EFacturaImportFailure(fileName: $0.fileName, message: receptionError)
            })
            return EFacturaImportResult(
                importedCount: 0,
                linesImportedCount: 0,
                productsCreatedCount: 0,
                skippedDuplicates: skippedDuplicates,
                failures: failures,
                pendingNIRInvoiceIds: [],
                pendingCreditNoteOffsetInvoiceIds: []
            )
        }

        let suppliers: [Supplier]
        let existingInvoices: [SupplierInvoiceRow]
        var products: [Product]
        do {
            suppliers = try await SupplierService.fetchSuppliers()
            existingInvoices = try await SupplierService.fetchInvoices()
            products = try await ProductService.fetchProducts(companyId: company.id)
        } catch {
            failures.append(contentsOf: importableItems.map {
                EFacturaImportFailure(fileName: $0.fileName, message: error.localizedDescription)
            })
            return EFacturaImportResult(
                importedCount: 0,
                linesImportedCount: 0,
                productsCreatedCount: 0,
                skippedDuplicates: skippedDuplicates,
                failures: failures,
                pendingNIRInvoiceIds: [],
                pendingCreditNoteOffsetInvoiceIds: []
            )
        }

        let workLocationId = receptionOptions.workLocationId
        let warehouseId = receptionOptions.warehouseId

        var supplierCache = suppliers
        var importedKeys = SupplierInvoiceDuplicateCheck.duplicateKeySet(
            from: existingInvoices,
            suppliers: suppliers
        )

        for item in importableItems {
            do {
                let data = try readFileData(from: item.fileURL)
                let parsed = try EFacturaInvoiceParser.parse(data: data)
                let outcome = try await importParsedInvoice(
                    parsed,
                    fileName: item.fileName,
                    company: company,
                    workLocationId: workLocationId,
                    warehouseId: warehouseId,
                    createNIR: item.createNIR,
                    createdBy: createdBy,
                    suppliers: &supplierCache,
                    products: &products,
                    importedKeys: &importedKeys,
                    linesImportedCount: &linesImportedCount,
                    productsCreatedCount: &productsCreatedCount,
                    pendingNIRInvoiceIds: &pendingNIRInvoiceIds,
                    pendingCreditNoteOffsetInvoiceIds: &pendingCreditNoteOffsetInvoiceIds
                )
                switch outcome {
                case .imported:
                    importedCount += 1
                case .duplicate(let label):
                    skippedDuplicates.append(label)
                }
            } catch {
                failures.append(EFacturaImportFailure(fileName: item.fileName, message: error.localizedDescription))
            }
        }

        return EFacturaImportResult(
            importedCount: importedCount,
            linesImportedCount: linesImportedCount,
            productsCreatedCount: productsCreatedCount,
            skippedDuplicates: skippedDuplicates,
            failures: failures,
            pendingNIRInvoiceIds: pendingNIRInvoiceIds,
            pendingCreditNoteOffsetInvoiceIds: pendingCreditNoteOffsetInvoiceIds
        )
    }

    private static func previewFile(
        url: URL,
        previewId: String,
        company: Company,
        suppliers: inout [Supplier],
        importedKeys: inout Set<String>,
        previewSupplierIds: inout [String: UUID]
    ) -> EFacturaImportPreviewItem {
        let fileName = url.lastPathComponent
        do {
            let data = try readFileData(from: url)
            let parsed = try EFacturaInvoiceParser.parse(data: data)
            try validateBuyer(parsed, company: company)

            let issueDate = parsed.issueDate ?? Date()
            let supplierName = parsed.supplier.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let totalAmount = parsed.taxInclusiveAmount ?? .zero
            let normalizedNumber = SupplierInvoiceDuplicateCheck.normalizeInvoiceNumber(parsed.invoiceNumber)
            let currency = parsed.currency

            let resolvedSupplier = resolveSupplierIdentityForPreview(
                from: parsed.supplier,
                suppliers: &suppliers,
                previewSupplierIds: &previewSupplierIds
            )

            let duplicateLabel = SupplierInvoiceDuplicateCheck.duplicateMessage(
                supplierName: resolvedSupplier.denumire,
                number: normalizedNumber,
                issueDate: issueDate,
                totalAmount: totalAmount,
                currency: currency
            )
            let duplicateKeys = SupplierInvoiceDuplicateCheck.duplicateKeys(
                supplierId: resolvedSupplier.id,
                supplierCUI: resolvedSupplier.cui,
                number: parsed.invoiceNumber,
                issueDate: issueDate,
                totalAmount: totalAmount
            )
            let isDuplicate = duplicateKeys.contains(where: { importedKeys.contains($0) })

            let item = EFacturaImportPreviewItem(
                id: previewId,
                fileURL: url,
                fileName: fileName,
                invoiceNumber: normalizedNumber,
                supplierName: resolvedSupplier.denumire.isEmpty ? supplierName : resolvedSupplier.denumire,
                issueDate: issueDate,
                totalAmount: totalAmount,
                currency: currency,
                lineCount: parsed.lines.count,
                isDuplicate: isDuplicate,
                duplicateLabel: isDuplicate ? duplicateLabel : nil,
                isCreditNote: parsed.isCreditNote,
                errorMessage: nil,
                createNIR: !isDuplicate && !parsed.isCreditNote
            )

            if item.canImport {
                for key in duplicateKeys {
                    importedKeys.insert(key)
                }
            }

            return item
        } catch {
            return EFacturaImportPreviewItem(
                id: previewId,
                fileURL: url,
                fileName: fileName,
                invoiceNumber: "—",
                supplierName: "—",
                issueDate: Date(),
                totalAmount: .zero,
                currency: "RON",
                lineCount: 0,
                isDuplicate: false,
                duplicateLabel: nil,
                isCreditNote: false,
                errorMessage: error.localizedDescription,
                createNIR: false
            )
        }
    }

    private struct PreviewSupplierIdentity {
        let id: UUID
        let denumire: String
        let cui: String?
    }

    private static func resolveSupplierIdentityForPreview(
        from party: EFacturaParsedInvoice.Party,
        suppliers: inout [Supplier],
        previewSupplierIds: inout [String: UUID]
    ) -> PreviewSupplierIdentity {
        let trimmedName = party.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCUI = EFacturaInvoiceParser.resolvedPartyCUI(party)

        if let cui = normalizedCUI,
           let match = suppliers.first(where: { EFacturaInvoiceParser.normalizeCUI($0.cui) == cui }) {
            return PreviewSupplierIdentity(id: match.id, denumire: match.denumire, cui: cui)
        }

        if normalizedCUI == nil,
           let match = suppliers.first(where: {
               $0.denumire.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
           }) {
            return PreviewSupplierIdentity(
                id: match.id,
                denumire: match.denumire,
                cui: EFacturaInvoiceParser.normalizeCUI(match.cui)
            )
        }

        let cacheKey = normalizedCUI ?? trimmedName.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "ro_RO")
        )
        let supplierId = previewSupplierIds[cacheKey] ?? UUID()
        previewSupplierIds[cacheKey] = supplierId
        return PreviewSupplierIdentity(
            id: supplierId,
            denumire: trimmedName,
            cui: normalizedCUI
        )
    }

    static func importFiles(
        urls: [URL],
        company: Company,
        receptionOptions: InvoiceReceptionOptions,
        receptionRequirements: InvoiceReceptionRequirements,
        createdBy: UUID?
    ) async -> EFacturaImportResult {
        let items = await previewFiles(urls: urls, company: company)
        let itemsWithNIR = items.map { item in
            var updated = item
            if item.canImport, !item.isCreditNote {
                updated.createNIR = receptionOptions.createNIR
            }
            return updated
        }
        return await importFiles(
            items: itemsWithNIR,
            company: company,
            receptionOptions: receptionOptions,
            receptionRequirements: receptionRequirements,
            createdBy: createdBy
        )
    }

    private enum ImportOutcome {
        case imported
        case duplicate(String)
    }

    private static func validateBuyer(_ parsed: EFacturaParsedInvoice, company: Company) throws {
        guard let companyCUI = EFacturaInvoiceParser.normalizeCUI(company.cui) else {
            throw EFacturaImportError.companyCUIMissing
        }
        guard let buyerCUI = EFacturaInvoiceParser.resolvedPartyCUI(parsed.customer) else {
            throw EFacturaImportError.buyerCUIMissing
        }
        guard companyCUI == buyerCUI else {
            throw EFacturaImportError.buyerMismatch(
                companyName: company.denumire,
                buyerName: parsed.customer.name.isEmpty ? buyerCUI : parsed.customer.name,
                companyCUI: companyCUI,
                buyerCUI: buyerCUI
            )
        }
    }

    private static func importParsedInvoice(
        _ parsed: EFacturaParsedInvoice,
        fileName: String,
        company: Company,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createNIR: Bool,
        createdBy: UUID?,
        suppliers: inout [Supplier],
        products: inout [Product],
        importedKeys: inout Set<String>,
        linesImportedCount: inout Int,
        productsCreatedCount: inout Int,
        pendingNIRInvoiceIds: inout [UUID],
        pendingCreditNoteOffsetInvoiceIds: inout [UUID]
    ) async throws -> ImportOutcome {
        try validateBuyer(parsed, company: company)

        let issueDate = parsed.issueDate ?? Date()
        let dueDate = effectiveDueDate(for: parsed, issueDate: issueDate)

        let supplier = try await resolveSupplier(
            from: parsed.supplier,
            companyId: company.id,
            invoiceDate: issueDate,
            dueDate: dueDate,
            suppliers: &suppliers
        )
        let totalAmount = SupplierFormatting.roundAmount(parsed.taxInclusiveAmount ?? .zero)
        let taxAmount = resolvedDocumentTaxAmount(from: parsed)
        let normalizedNumber = SupplierInvoiceDuplicateCheck.normalizeInvoiceNumber(parsed.invoiceNumber)
        let currency = parsed.currency

        let duplicateLabel = SupplierInvoiceDuplicateCheck.duplicateMessage(
            supplierName: supplier.denumire,
            number: normalizedNumber,
            issueDate: issueDate,
            totalAmount: totalAmount,
            currency: currency
        )
        if SupplierInvoiceDuplicateCheck.duplicateKeys(
            for: supplier,
            number: parsed.invoiceNumber,
            issueDate: issueDate,
            totalAmount: totalAmount
        ).contains(where: { importedKeys.contains($0) }) {
            return .duplicate(duplicateLabel)
        }

        let invoice = try await SupplierService.createInvoice(
            companyId: company.id,
            supplierId: supplier.id,
            numarFactura: normalizedNumber,
            dataFactura: issueDate,
            dataScadenta: dueDate,
            sumaTotala: totalAmount,
            sumaTva: taxAmount,
            moneda: currency,
            status: .neplatita,
            observatii: parsed.isCreditNote
                ? L10n.tr("invoices.import_observatii_credit_note", fileName)
                : L10n.tr("invoices.import_observatii", fileName),
            workLocationId: workLocationId,
            warehouseId: warehouseId,
            createdBy: createdBy
        )

        if !parsed.lines.isEmpty {
            var lineInputs: [SupplierService.InvoiceLineCreateInput] = []
            lineInputs.reserveCapacity(parsed.lines.count)

            for (index, line) in parsed.lines.enumerated() {
                let productResult = try await ProductService.findOrCreateProduct(
                    companyId: company.id,
                    cod: line.sellerCode,
                    codBare: line.barcode,
                    denumire: line.name,
                    descriere: line.description,
                    unitateMasura: line.unitCode,
                    cpv: line.cpv,
                    products: &products
                )
                if productResult.created {
                    productsCreatedCount += 1
                }

                let unitPrice = line.unitPrice ?? .zero
                let lineTotal = line.lineTotal ?? SupplierFormatting.roundAmount(unitPrice * line.quantity)
                let lineTax = SupplierFormatting.roundAmount(line.lineTax ?? .zero)
                let vatRate = line.lineTaxPercent ?? InvoiceLineVAT.vatRate(amount: lineTax, lineTotal: lineTotal)
                lineInputs.append(
                    SupplierService.InvoiceLineCreateInput(
                        productId: productResult.product.id,
                        numarLinie: index + 1,
                        denumire: line.name,
                        cantitate: line.quantity,
                        pretUnitar: unitPrice,
                        sumaLinie: lineTotal,
                        sumaTva: lineTax,
                        cotaTva: vatRate,
                        unitateMasura: line.unitCode
                    )
                )
            }

            try await SupplierService.createInvoiceLines(
                companyId: company.id,
                invoiceId: invoice.id,
                lines: lineInputs
            )
            linesImportedCount += lineInputs.count
        }

        for key in SupplierInvoiceDuplicateCheck.duplicateKeys(
            for: supplier,
            number: parsed.invoiceNumber,
            issueDate: issueDate,
            totalAmount: totalAmount
        ) {
            importedKeys.insert(key)
        }

        if createNIR {
            pendingNIRInvoiceIds.append(invoice.id)
        } else if parsed.isCreditNote {
            pendingCreditNoteOffsetInvoiceIds.append(invoice.id)
        }

        return .imported
    }

    private static func resolvedDocumentTaxAmount(from parsed: EFacturaParsedInvoice) -> Decimal {
        if let headerTax = parsed.taxAmount {
            return SupplierFormatting.roundAmount(headerTax)
        }
        guard !parsed.lines.isEmpty else { return .zero }
        let lineSum = parsed.lines.reduce(Decimal.zero) { partial, line in
            partial + (line.lineTax ?? .zero)
        }
        return SupplierFormatting.roundAmount(lineSum)
    }

    private static let metroSupplierCUI = "8119423"

    private static func isMetroSupplier(_ party: EFacturaParsedInvoice.Party) -> Bool {
        if let cui = EFacturaInvoiceParser.normalizeCUI(party.cui), cui == metroSupplierCUI {
            return true
        }

        let folded = party.name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
        return folded.contains("METRO CASH")
    }

    private static func effectiveDueDate(for parsed: EFacturaParsedInvoice, issueDate: Date) -> Date? {
        guard isMetroSupplier(parsed.supplier) else {
            return parsed.dueDate
        }
        return SupplierFormatting.metroDueDate(from: issueDate)
    }

    private static func resolveSupplier(
        from party: EFacturaParsedInvoice.Party,
        companyId: UUID,
        invoiceDate: Date,
        dueDate: Date?,
        suppliers: inout [Supplier]
    ) async throws -> Supplier {
        let trimmedName = party.name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cui = EFacturaInvoiceParser.resolvedPartyCUI(party),
           let match = suppliers.first(where: { EFacturaInvoiceParser.normalizeCUI($0.cui) == cui }) {
            return try await enrichSupplierIfNeeded(
                supplier: match,
                party: party,
                suppliers: &suppliers
            )
        }

        if EFacturaInvoiceParser.resolvedPartyCUI(party) == nil,
           let match = suppliers.first(where: {
               $0.denumire.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
           }) {
            return try await enrichSupplierIfNeeded(
                supplier: match,
                party: party,
                suppliers: &suppliers
            )
        }

        let nrZileScadenta = SupplierFormatting.paymentTermDays(
            from: invoiceDate,
            dueDate: dueDate
        )

        let created = try await SupplierService.createSupplier(
            companyId: companyId,
            denumire: trimmedName,
            cui: party.cui,
            nrRegCom: party.nrRegCom,
            adresa: party.adresa,
            iban: party.iban,
            email: party.email,
            telefon: party.telefon,
            observatii: L10n.tr("invoices.import_supplier_created"),
            nrZileScadenta: nrZileScadenta,
            isActive: true
        )
        suppliers.append(created)
        return created
    }

    private static func enrichSupplierIfNeeded(
        supplier: Supplier,
        party: EFacturaParsedInvoice.Party,
        suppliers: inout [Supplier]
    ) async throws -> Supplier {
        let email = coalesceMissing(existing: supplier.email, incoming: party.email)
        let iban = coalesceMissing(existing: supplier.iban, incoming: normalizedIBAN(party.iban))
        let telefon = coalesceMissing(existing: supplier.telefon, incoming: party.telefon)

        guard email != supplier.email || iban != supplier.iban || telefon != supplier.telefon else {
            return supplier
        }

        let updated = try await SupplierService.updateSupplier(
            id: supplier.id,
            denumire: supplier.denumire,
            cui: supplier.cui,
            nrRegCom: supplier.nrRegCom,
            adresa: supplier.adresa,
            iban: iban,
            email: email,
            telefon: telefon,
            observatii: supplier.observatii,
            nrZileScadenta: supplier.nrZileScadenta,
            isActive: supplier.isActive
        )

        if let index = suppliers.firstIndex(where: { $0.id == supplier.id }) {
            suppliers[index] = updated
        }
        return updated
    }

    private static func coalesceMissing(existing: String?, incoming: String?) -> String? {
        if let existing = trimmedNonEmpty(existing) {
            return existing
        }
        return trimmedNonEmpty(incoming) ?? existing
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedIBAN(_ value: String?) -> String? {
        guard let trimmed = trimmedNonEmpty(value) else { return nil }
        return trimmed
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    private static func readFileData(from url: URL) throws -> Data {
        var didAccess = false
        if url.startAccessingSecurityScopedResource() {
            didAccess = true
        }
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}
