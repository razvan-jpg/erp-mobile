import Foundation
import Supabase

enum SupplierNIRService {
    private static let client = SupabaseManager.client

    private static func lineShare(
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception
    ) -> (lineValue: Decimal, vat: Decimal) {
        guard line.cantitate > 0 else {
            return (line.sumaLinie, line.sumaTva)
        }
        let ratio = reception.invoiceQuantity / line.cantitate
        return (line.sumaLinie * ratio, line.sumaTva * ratio)
    }

    private static func dateString(_ date: Date) -> String {
        SupabaseDecoding.dateOnlyString(from: date)
    }

    private struct NIRInsert: Encodable {
        let companyId: UUID
        let invoiceId: UUID
        let dataNir: String
        let workLocationId: UUID?
        let warehouseId: UUID?
        let createdBy: UUID?

        enum CodingKeys: String, CodingKey {
            case companyId = "company_id"
            case invoiceId = "invoice_id"
            case dataNir = "data_nir"
            case workLocationId = "work_location_id"
            case warehouseId = "warehouse_id"
            case createdBy = "created_by"
        }
    }

    private struct NIRLineInsert: Encodable {
        let nirId: UUID
        let companyId: UUID
        let invoiceLineId: UUID
        let productId: UUID
        let numarLinie: Int
        let denumire: String
        let cantitate: Double
        let pretUnitar: Double
        let sumaLinie: Double
        let sumaTva: Double
        let cotaTva: Double
        let unitateMasura: String
        let cantitateFactura: Double
        let unitateFactura: String
        let factorConversie: Double

        enum CodingKeys: String, CodingKey {
            case denumire, cantitate
            case nirId = "nir_id"
            case companyId = "company_id"
            case invoiceLineId = "invoice_line_id"
            case productId = "product_id"
            case numarLinie = "numar_linie"
            case pretUnitar = "pret_unitar"
            case sumaLinie = "suma_linie"
            case sumaTva = "suma_tva"
            case cotaTva = "cota_tva"
            case unitateMasura = "unitate_masura"
            case cantitateFactura = "cantitate_factura"
            case unitateFactura = "unitate_factura"
            case factorConversie = "factor_conversie"
        }
    }

    private struct NIRLineUpdate: Encodable {
        let productId: UUID
        let numarLinie: Int
        let denumire: String
        let cantitate: Double
        let pretUnitar: Double
        let sumaLinie: Double
        let sumaTva: Double
        let cotaTva: Double
        let unitateMasura: String
        let cantitateFactura: Double
        let unitateFactura: String
        let factorConversie: Double

        enum CodingKeys: String, CodingKey {
            case denumire, cantitate
            case productId = "product_id"
            case numarLinie = "numar_linie"
            case pretUnitar = "pret_unitar"
            case sumaLinie = "suma_linie"
            case sumaTva = "suma_tva"
            case cotaTva = "cota_tva"
            case unitateMasura = "unitate_masura"
            case cantitateFactura = "cantitate_factura"
            case unitateFactura = "unitate_factura"
            case factorConversie = "factor_conversie"
        }
    }

    static func fetchNIR(forInvoice invoiceId: UUID) async throws -> SupplierNIR? {
        try await fetchNIRs(forInvoice: invoiceId).first
    }

    static func fetchNIRs(forInvoice invoiceId: UUID) async throws -> [SupplierNIR] {
        try await client
            .from("supplier_nirs")
            .select()
            .eq("invoice_id", value: invoiceId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func receivedInvoiceQuantities(
        invoiceId: UUID,
        excludingNirId: UUID?
    ) async throws -> [UUID: Decimal] {
        let nirs = try await fetchNIRs(forInvoice: invoiceId)
        let nirIds = nirs.map(\.id).filter { $0 != excludingNirId }
        guard !nirIds.isEmpty else { return [:] }
        struct QtyRow: Decodable {
            let invoiceLineId: UUID
            let cantitateFactura: Decimal
            enum CodingKeys: String, CodingKey {
                case invoiceLineId = "invoice_line_id"
                case cantitateFactura = "cantitate_factura"
            }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                invoiceLineId = try container.decode(UUID.self, forKey: .invoiceLineId)
                cantitateFactura = try container.decode(SupabaseDecimal.self, forKey: .cantitateFactura).wrappedValue
            }
        }
        let rows: [QtyRow] = try await client
            .from("supplier_nir_lines")
            .select("invoice_line_id, cantitate_factura")
            .in("nir_id", values: nirIds.map(\.uuidString))
            .execute()
            .value
        var totals: [UUID: Decimal] = [:]
        for row in rows {
            totals[row.invoiceLineId, default: 0] += row.cantitateFactura
        }
        return totals
    }

    static func fetchNIR(id: UUID) async throws -> SupplierNIR {
        let rows: [SupplierNIR] = try await client
            .from("supplier_nirs")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let nir = rows.first else { throw ServiceError.invalidResponse }
        return nir
    }

    static func fetchNIRRow(id: UUID) async throws -> SupplierNIRRow {
        let rows: [SupplierNIRRow] = try await client
            .from("supplier_nirs")
            .select("*, invoice:supplier_invoices(numar_factura, data_factura, supplier_id, supplier:suppliers(denumire))")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { throw ServiceError.invalidResponse }
        return row
    }

    static func fetchNIRRows(companyId: UUID) async throws -> [SupplierNIRRow] {
        let rows: [SupplierNIRRow] = try await SupabasePaging.fetchAll { from, to in
            try await client
                .from("supplier_nirs")
                .select("*, invoice:supplier_invoices(numar_factura, data_factura, supplier_id, supplier:suppliers(denumire))")
                .eq("company_id", value: companyId.uuidString)
                .order("data_nir", ascending: false)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
        }
        return rows.sorted { lhs, rhs in
            if lhs.dataNir != rhs.dataNir {
                return lhs.dataNir > rhs.dataNir
            }
            return lhs.numarNir.localizedStandardCompare(rhs.numarNir) == .orderedDescending
        }
    }

    static func fetchInvoiceIdsWithNIR(companyId: UUID) async throws -> Set<UUID> {
        struct NIRInvoiceRef: Decodable {
            let invoiceId: UUID

            enum CodingKeys: String, CodingKey {
                case invoiceId = "invoice_id"
            }
        }

        let rows: [NIRInvoiceRef] = try await SupabasePaging.fetchAll { from, to in
            try await client
                .from("supplier_nirs")
                .select("invoice_id")
                .eq("company_id", value: companyId.uuidString)
                .order("invoice_id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
        }
        return Set(rows.map(\.invoiceId))
    }

    static func deleteNIR(id: UUID) async throws {
        struct DeleteNIRParams: Encodable {
            let pNirId: UUID

            enum CodingKeys: String, CodingKey {
                case pNirId = "p_nir_id"
            }
        }

        struct DeletedNIRRef: Decodable {
            let id: UUID
        }

        do {
            try await client
                .rpc("delete_supplier_nir", params: DeleteNIRParams(pNirId: id))
                .execute()
        } catch {
            throw NIRDeleteError.map(error)
        }

        let remaining: [DeletedNIRRef] = try await client
            .from("supplier_nirs")
            .select("id")
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        if !remaining.isEmpty {
            throw NIRDeleteError.deleteFailed
        }
    }

    static func fetchNIRLines(nirId: UUID) async throws -> [SupplierNIRLine] {
        let rows: [SupplierNIRLine] = try await client
            .from("supplier_nir_lines")
            .select()
            .eq("nir_id", value: nirId.uuidString)
            .order("numar_linie", ascending: true)
            .execute()
            .value
        return rows
    }

    static func createNIR(
        companyId: UUID,
        invoiceId: UUID,
        dataNir: Date,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createdBy: UUID?
    ) async throws -> SupplierNIR {
        let payload = NIRInsert(
            companyId: companyId,
            invoiceId: invoiceId,
            dataNir: dateString(dataNir),
            workLocationId: workLocationId,
            warehouseId: warehouseId,
            createdBy: createdBy
        )
        let rows: [SupplierNIR] = try await client
            .from("supplier_nirs")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let nir = rows.first else { throw ServiceError.invalidResponse }
        return nir
    }

    static func replaceNIRLines(
        nirId: UUID,
        companyId: UUID,
        invoiceLines: [SupplierInvoiceLine],
        productsById: [UUID: Product] = [:],
        conversions: [UUID: StockUnitConversion.Reception] = [:],
        workLocationId: UUID? = nil,
        warehouseId: UUID? = nil,
        updateReceptionBeforeInsert: Bool = false
    ) async throws {
        if updateReceptionBeforeInsert {
            _ = try await updateNIRReception(
                nirId: nirId,
                workLocationId: workLocationId,
                warehouseId: warehouseId
            )
        }

        let desiredLines = invoiceLines
            .filter(NIRLineEligibility.isSelectable)
            .sorted { $0.numarLinie < $1.numarLinie }
        let existingLines = try await fetchNIRLines(nirId: nirId)
        let existingByInvoiceLineId = Dictionary(
            uniqueKeysWithValues: existingLines.map { ($0.invoiceLineId, $0) }
        )
        let desiredLineIds = Set(desiredLines.map(\.id))

        let linesToDelete = existingLines.filter { !desiredLineIds.contains($0.invoiceLineId) }
        if !linesToDelete.isEmpty {
            let idsToDelete = linesToDelete.map { $0.id.uuidString }
            try await client
                .from("supplier_nir_lines")
                .delete()
                .in("id", values: idsToDelete)
                .execute()
        }

        var inserts: [NIRLineInsert] = []
        inserts.reserveCapacity(desiredLines.count)

        for (index, line) in desiredLines.enumerated() {
            let reception = conversions[line.id]
                ?? StockUnitConversion.reception(invoiceLine: line, product: productsById[line.productId])
            let share = lineShare(line: line, reception: reception)
            let payload = NIRLineUpdate(
                productId: line.productId,
                numarLinie: index + 1,
                denumire: line.denumire,
                cantitate: doubleQuantity(reception.stockQuantity),
                pretUnitar: doubleAmount(reception.stockUnitPrice),
                sumaLinie: doubleAmount(share.lineValue),
                sumaTva: doubleAmount(share.vat),
                cotaTva: doubleAmount(line.cotaTva),
                unitateMasura: reception.stockUnit,
                cantitateFactura: doubleQuantity(reception.invoiceQuantity),
                unitateFactura: reception.invoiceUnit,
                factorConversie: doubleQuantity(reception.factor)
            )

            if let existingLine = existingByInvoiceLineId[line.id] {
                try await client
                    .from("supplier_nir_lines")
                    .update(payload)
                    .eq("id", value: existingLine.id.uuidString)
                    .execute()
            } else {
                inserts.append(
                    NIRLineInsert(
                        nirId: nirId,
                        companyId: companyId,
                        invoiceLineId: line.id,
                        productId: line.productId,
                        numarLinie: index + 1,
                        denumire: line.denumire,
                        cantitate: doubleQuantity(reception.stockQuantity),
                        pretUnitar: doubleAmount(reception.stockUnitPrice),
                        sumaLinie: doubleAmount(share.lineValue),
                        sumaTva: doubleAmount(share.vat),
                        cotaTva: doubleAmount(line.cotaTva),
                        unitateMasura: reception.stockUnit,
                        cantitateFactura: doubleQuantity(reception.invoiceQuantity),
                        unitateFactura: reception.invoiceUnit,
                        factorConversie: doubleQuantity(reception.factor)
                    )
                )
            }
        }

        for chunk in inserts.chunked(into: 200) {
            try await client
                .from("supplier_nir_lines")
                .insert(chunk)
                .execute()
        }
    }

    private struct NIRReceptionUpdate: Encodable {
        let workLocationId: UUID?
        let warehouseId: UUID?

        enum CodingKeys: String, CodingKey {
            case workLocationId = "work_location_id"
            case warehouseId = "warehouse_id"
        }
    }

    static func updateNIRReception(
        nirId: UUID,
        workLocationId: UUID?,
        warehouseId: UUID?
    ) async throws -> SupplierNIR {
        let payload = NIRReceptionUpdate(
            workLocationId: workLocationId,
            warehouseId: warehouseId
        )
        try await client
            .from("supplier_nirs")
            .update(payload)
            .eq("id", value: nirId.uuidString)
            .execute()
        return try await fetchNIR(id: nirId)
    }

    static func saveNIR(
        context: NIREditorContext,
        companyId: UUID,
        selectedInvoiceLineIds: Set<UUID>,
        workLocationId: UUID?,
        warehouseId: UUID?,
        createdBy: UUID?,
        productsById: [UUID: Product] = [:],
        conversions: [UUID: StockUnitConversion.Reception] = [:]
    ) async throws -> SupplierNIR {
        let allInvoiceLines = try await SupplierService.fetchInvoiceLines(invoiceId: context.invoice.id)
        let selectedLines = allInvoiceLines
            .filter { selectedInvoiceLineIds.contains($0.id) }
            .filter(NIRLineEligibility.isSelectable)
            .sorted { $0.numarLinie < $1.numarLinie }

        guard !selectedLines.isEmpty else {
            throw NIRSaveError.noReceivableLines
        }

        let receivedElsewhere = try await receivedInvoiceQuantities(
            invoiceId: context.invoice.id,
            excludingNirId: context.existingNIR?.id
        )
        for line in selectedLines {
            let reception = conversions[line.id]
                ?? StockUnitConversion.reception(invoiceLine: line, product: productsById[line.productId])
            let already = receivedElsewhere[line.id] ?? 0
            let tolerance = NSDecimalNumber(string: "0.0001").decimalValue
            if reception.invoiceQuantity + already > line.cantitate + tolerance {
                throw NIRSaveError.quantityExceedsRemaining
            }
        }

        let nir: SupplierNIR
        if let existingNIR = context.existingNIR {
            try await replaceNIRLines(
                nirId: existingNIR.id,
                companyId: companyId,
                invoiceLines: selectedLines,
                productsById: productsById,
                conversions: conversions,
                workLocationId: workLocationId,
                warehouseId: warehouseId,
                updateReceptionBeforeInsert: true
            )
            nir = try await fetchNIR(id: existingNIR.id)
        } else {
            nir = try await createNIR(
                companyId: companyId,
                invoiceId: context.invoice.id,
                dataNir: context.invoice.dataFactura,
                workLocationId: workLocationId,
                warehouseId: warehouseId,
                createdBy: createdBy
            )
            try await replaceNIRLines(
                nirId: nir.id,
                companyId: companyId,
                invoiceLines: selectedLines,
                productsById: productsById,
                conversions: conversions
            )
        }

        return nir
    }

    static func computeMarkupTotals(
        nirLines: [SupplierNIRLine],
        productsById: [UUID: Product],
        allProducts: [Product] = []
    ) -> NIRComputedTotals {
        let invoiceLines = nirLines.map { invoiceLineRepresentation(from: $0) }
        let conversionByLineId = Dictionary(
            uniqueKeysWithValues: nirLines.map { ($0.invoiceLineId, StockUnitConversion.reception(nirLine: $0)) }
        )
        let computedLines = NIRCalculation.computeLines(
            invoiceLines: invoiceLines,
            productsById: productsById,
            allProducts: allProducts,
            conversionByLineId: conversionByLineId
        )
        return NIRCalculation.computeTotals(from: computedLines)
    }

    static func buildSnapshot(
        company: Company,
        supplier: Supplier,
        invoice: SupplierInvoice,
        nir: SupplierNIR,
        workLocationName: String?,
        warehouseName: String?,
        salePriceByLineId: [UUID: Decimal] = [:]
    ) async throws -> NIRSnapshot {
        let nirLines = try await fetchNIRLines(nirId: nir.id)
        let invoiceLines = nirLines.map { invoiceLineRepresentation(from: $0) }
        let conversionByLineId = Dictionary(
            uniqueKeysWithValues: nirLines.map { ($0.invoiceLineId, StockUnitConversion.reception(nirLine: $0)) }
        )
        let products = try await ProductService.fetchProducts(ids: invoiceLines.map(\.productId))
        let productsById = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let reception = try await resolveReceptionDetails(
            nir: nir,
            companyId: company.id,
            fallbackWorkLocationName: workLocationName,
            fallbackWarehouseName: warehouseName
        )
        let computedLines = NIRCalculation.computeLines(
            invoiceLines: invoiceLines,
            productsById: productsById,
            salePriceByLineId: salePriceByLineId,
            allProducts: products,
            conversionByLineId: conversionByLineId
        )
        return NIRSnapshot(
            company: company,
            supplier: supplier,
            invoiceNumber: invoice.numarFactura,
            invoiceDate: invoice.dataFactura,
            nir: nir,
            workLocationName: reception.workLocationName,
            workLocationAddress: reception.workLocationAddress,
            warehouseName: reception.warehouseName,
            warehouseAddress: reception.warehouseAddress,
            warehouseManagerName: reception.warehouseManagerName,
            lines: computedLines,
            totals: NIRCalculation.computeTotals(from: computedLines),
            generatedAt: Date()
        )
    }

    static func prepareExport(
        company: Company,
        supplier: Supplier,
        invoice: SupplierInvoice,
        nir: SupplierNIR,
        workLocationName: String?,
        warehouseName: String?,
        salePriceByLineId: [UUID: Decimal] = [:]
    ) async throws -> NIRExportItem {
        let snapshot = try await buildSnapshot(
            company: company,
            supplier: supplier,
            invoice: invoice,
            nir: nir,
            workLocationName: workLocationName,
            warehouseName: warehouseName,
            salePriceByLineId: salePriceByLineId
        )
        let pdfURL = try NIRPDFBuilder.writeTemporaryPDF(from: snapshot)
        return NIRExportItem(id: nir.id, snapshot: snapshot, pdfURL: pdfURL)
    }

    private static func invoiceLineRepresentation(from nirLine: SupplierNIRLine) -> SupplierInvoiceLine {
        SupplierInvoiceLine(
            id: nirLine.invoiceLineId,
            companyId: nirLine.companyId,
            invoiceId: UUID(),
            productId: nirLine.productId,
            numarLinie: nirLine.numarLinie,
            denumire: nirLine.denumire,
            cantitate: nirLine.cantitate,
            pretUnitar: nirLine.pretUnitar,
            sumaLinie: nirLine.sumaLinie,
            sumaTva: nirLine.sumaTva,
            cotaTva: nirLine.cotaTva,
            unitateMasura: nirLine.unitateMasura,
            createdAt: nirLine.createdAt
        )
    }

    private struct NIRReceptionDetails {
        let workLocationName: String?
        let workLocationAddress: String?
        let warehouseName: String?
        let warehouseAddress: String?
        let warehouseManagerName: String?
    }

    private static func resolveReceptionDetails(
        nir: SupplierNIR,
        companyId: UUID,
        fallbackWorkLocationName: String?,
        fallbackWarehouseName: String?
    ) async throws -> NIRReceptionDetails {
        async let workLocationsTask = WorkLocationService.fetchWorkLocations(companyId: companyId)
        async let warehousesTask = WarehouseService.fetchWarehouses(companyId: companyId)
        let workLocations = try await workLocationsTask
        let warehouses = try await warehousesTask

        let hasActiveWorkLocations = workLocations.contains(where: \.isActive)
        let hasActiveWarehouses = warehouses.contains(where: \.isActive)

        var workLocationName: String?
        var workLocationAddress: String?
        if hasActiveWorkLocations {
            if let workLocationId = nir.workLocationId,
               let workLocation = workLocations.first(where: { $0.id == workLocationId }) {
                workLocationName = workLocation.denumire
                workLocationAddress = workLocation.formattedPostalAddress
            } else if let fallbackWorkLocationName = trimmedNonEmpty(fallbackWorkLocationName) {
                workLocationName = fallbackWorkLocationName
            }
        }

        var warehouseName: String?
        var warehouseAddress: String?
        var warehouseManagerName: String?
        if hasActiveWarehouses {
            if let warehouseId = nir.warehouseId,
               let warehouse = warehouses.first(where: { $0.id == warehouseId }) {
                warehouseName = warehouse.denumire
                warehouseAddress = trimmedNonEmpty(warehouse.adresa)
                warehouseManagerName = trimmedNonEmpty(warehouse.managerName)
            } else if let fallbackWarehouseName = trimmedNonEmpty(fallbackWarehouseName) {
                warehouseName = fallbackWarehouseName
            }
        }

        return NIRReceptionDetails(
            workLocationName: workLocationName,
            workLocationAddress: workLocationAddress,
            warehouseName: warehouseName,
            warehouseAddress: warehouseAddress,
            warehouseManagerName: warehouseManagerName
        )
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func doubleAmount(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: SupplierFormatting.roundAmount(value)).doubleValue
    }

    private static func doubleQuantity(_ value: Decimal) -> Double {
        var rounded = Decimal()
        var input = value
        NSDecimalRound(&rounded, &input, 4, .plain)
        return NSDecimalNumber(decimal: rounded).doubleValue
    }
}
