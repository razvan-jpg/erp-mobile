import Foundation

struct InvoiceReceptionOptions: Equatable, Sendable {
    var workLocationId: UUID?
    var warehouseId: UUID?
    var createNIR: Bool = false
}

struct InvoiceReceptionRequirements: Equatable, Sendable {
    let requiresWorkLocation: Bool
    let requiresWarehouse: Bool

    init(workLocations: [CompanyWorkLocation], warehouses: [CompanyWarehouse]) {
        requiresWorkLocation = workLocations.contains(where: \.isActive)
        requiresWarehouse = warehouses.contains(where: \.isActive)
    }

    var hasAnyReceptionField: Bool {
        requiresWorkLocation || requiresWarehouse
    }

    func isValid(_ options: InvoiceReceptionOptions) -> Bool {
        if options.createNIR { return true }
        if requiresWorkLocation, options.workLocationId == nil { return false }
        if requiresWarehouse, options.warehouseId == nil { return false }
        return true
    }

    func invoiceHasReception(
        workLocationId: UUID?,
        warehouseId: UUID?,
        hasNIR: Bool
    ) -> Bool {
        if hasNIR { return true }
        if requiresWorkLocation, workLocationId == nil { return false }
        if requiresWarehouse, warehouseId == nil { return false }
        return true
    }
}

struct SupplierNIR: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let invoiceId: UUID
    var numarNir: String
    var dataNir: Date
    let workLocationId: UUID?
    let warehouseId: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case invoiceId = "invoice_id"
        case numarNir = "numar_nir"
        case dataNir = "data_nir"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NIRComputedLine: Sendable {
    let index: Int
    let denumire: String
    let unitateMasura: String
    let cotaTva: Decimal
    let cantitate: Decimal
    let pretUnitar: Decimal
    let valoare: Decimal
    let tvaPeUnitate: Decimal
    let tvaTotal: Decimal
    let totalFactura: Decimal
    let adaosProcent: Decimal
    let adaosSuma: Decimal
    let pretUnitarFaraTvaAmanunt: Decimal
    let tvaAfAdeaos: Decimal
    let pretUnitarCuTvaAmanunt: Decimal
    let valoareAmanunt: Decimal
    let tvaAmanuntPeUnitate: Decimal
    let tvaAmanuntTotal: Decimal
    let conversieNota: String?
}

struct NIRComputedTotals: Sendable {
    let cantitate: Decimal
    let valoare: Decimal
    let tvaTotal: Decimal
    let totalFactura: Decimal
    let adaosProcent: Decimal
    let adaosSuma: Decimal
    let tvaAfAdeaos: Decimal
    let valoareAmanunt: Decimal
    let tvaAmanuntTotal: Decimal
}

struct NIRMarkupAccountingEntry: Identifiable, Sendable {
    let id: UUID
    let numarNir: String
    let dataNir: Date
    let invoiceNumber: String
    let supplierName: String
    let adaosSuma: Decimal
    let tvaAfAdeaos: Decimal
}

struct NIRMarkupAccountingReport: Sendable {
    let month: Date
    let entries: [NIRMarkupAccountingEntry]
    let adaosSuma: Decimal
    let tvaAfAdeaos: Decimal
}

struct NIRSnapshot: Sendable {
    let company: Company
    let supplier: Supplier
    let invoiceNumber: String
    let invoiceDate: Date
    let nir: SupplierNIR
    let workLocationName: String?
    let workLocationAddress: String?
    let warehouseName: String?
    let warehouseAddress: String?
    let warehouseManagerName: String?
    let lines: [NIRComputedLine]
    let totals: NIRComputedTotals
    let generatedAt: Date
}

struct SupplierNIRLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let nirId: UUID
    let companyId: UUID
    let invoiceLineId: UUID
    let productId: UUID
    var numarLinie: Int
    var denumire: String
    @SupabaseDecimal var cantitate: Decimal
    @SupabaseDecimal var pretUnitar: Decimal
    @SupabaseDecimal var sumaLinie: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var cotaTva: Decimal
    var unitateMasura: String
    @SupabaseDecimal var cantitateFactura: Decimal
    var unitateFactura: String
    @SupabaseDecimal var factorConversie: Decimal
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire, cantitate
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct NIREditorContext: Identifiable, Sendable {
    let id: UUID
    let invoice: SupplierInvoice
    let supplier: Supplier
    let workLocationId: UUID?
    let warehouseId: UUID?
    let workLocationName: String?
    let warehouseName: String?
    let existingNIR: SupplierNIR?

    init(
        invoice: SupplierInvoice,
        supplier: Supplier,
        workLocationId: UUID?,
        warehouseId: UUID?,
        workLocationName: String?,
        warehouseName: String?,
        existingNIR: SupplierNIR? = nil
    ) {
        id = existingNIR?.id ?? UUID()
        self.invoice = invoice
        self.supplier = supplier
        self.workLocationId = workLocationId
        self.warehouseId = warehouseId
        self.workLocationName = workLocationName
        self.warehouseName = warehouseName
        self.existingNIR = existingNIR
    }
}

struct NIRExportItem: Identifiable, Sendable {
    let id: UUID
    let snapshot: NIRSnapshot
    let pdfURL: URL
}

struct SupplierNIRInvoiceRef: Codable, Hashable, Sendable {
    let numarFactura: String
    var dataFactura: Date
    let supplierId: UUID
    var supplier: SupplierNameRef?

    enum CodingKeys: String, CodingKey {
        case supplier
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case supplierId = "supplier_id"
    }
}

struct SupplierNIRRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let invoiceId: UUID
    var numarNir: String
    var dataNir: Date
    let workLocationId: UUID?
    let warehouseId: UUID?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    var invoice: SupplierNIRInvoiceRef?

    enum CodingKeys: String, CodingKey {
        case id, invoice
        case companyId = "company_id"
        case invoiceId = "invoice_id"
        case numarNir = "numar_nir"
        case dataNir = "data_nir"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var invoiceNumber: String {
        invoice?.numarFactura ?? "—"
    }

    var supplierName: String {
        invoice?.supplier?.denumire ?? "—"
    }

    var supplierId: UUID? {
        invoice?.supplierId
    }
}
