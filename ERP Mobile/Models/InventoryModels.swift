import Foundation

struct ProductStockProductRef: Codable, Hashable, Sendable {
    let id: UUID
    let denumire: String
    let cod: String?
    let codBare: String?
    let unitateMasura: String
    let tip: ProductKind

    enum CodingKeys: String, CodingKey {
        case id, denumire, cod, tip
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
    }
}

struct ProductStockRow: Codable, Identifiable, Hashable, Sendable {
    let companyId: UUID
    let productId: UUID
    @SupabaseDecimal var cantitate: Decimal
    let updatedAt: Date?
    let product: ProductStockProductRef?

    var id: UUID { productId }

    enum CodingKeys: String, CodingKey {
        case cantitate, product
        case companyId = "company_id"
        case productId = "product_id"
        case updatedAt = "updated_at"
    }
}

enum StockMovementKind: String, Codable, Sendable {
    case intrare
    case iesire

    var label: String {
        switch self {
        case .intrare: return L10n.tr("inventory.movement_in")
        case .iesire: return L10n.tr("inventory.movement_out")
        }
    }

    var isInbound: Bool { self == .intrare }
}

enum StockMovementSource: String, Codable, Sendable {
    case supplierInvoice = "supplier_invoice"
    case supplierInvoiceDelete = "supplier_invoice_delete"
    case supplierInvoiceBackfill = "supplier_invoice_backfill"
    case supplierInvoiceStorno = "supplier_invoice_storno"
    case supplierInvoiceStornoDelete = "supplier_invoice_storno_delete"
    case physicalInventory = "physical_inventory"
    case initialStock = "initial_stock"

    var label: String {
        switch self {
        case .supplierInvoice: return L10n.tr("inventory.source_supplier_invoice")
        case .supplierInvoiceDelete: return L10n.tr("inventory.source_supplier_invoice_delete")
        case .supplierInvoiceBackfill: return L10n.tr("inventory.source_supplier_invoice_backfill")
        case .supplierInvoiceStorno: return L10n.tr("inventory.source_supplier_invoice_storno")
        case .supplierInvoiceStornoDelete: return L10n.tr("inventory.source_supplier_invoice_storno_delete")
        case .physicalInventory: return L10n.tr("inventory.source_physical_inventory")
        case .initialStock: return L10n.tr("inventory.source_initial_stock")
        }
    }
}

struct StockMovementInvoiceRef: Codable, Hashable, Sendable {
    let numarFactura: String
    let dataFactura: Date

    enum CodingKeys: String, CodingKey {
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
    }
}

struct StockMovementInvoiceLineRef: Codable, Hashable, Sendable {
    @SupabaseDecimal var pretUnitar: Decimal
    @SupabaseDecimal var sumaLinie: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var cotaTva: Decimal

    enum CodingKeys: String, CodingKey {
        case pretUnitar = "pret_unitar"
        case sumaLinie = "suma_linie"
        case sumaTva = "suma_tva"
        case cotaTva = "cota_tva"
    }

    var vatPercent: Decimal? {
        if cotaTva > 0 { return cotaTva }
        guard sumaLinie > 0, sumaTva > 0 else { return nil }
        return InvoiceLineVAT.vatRate(amount: sumaTva, lineTotal: sumaLinie)
    }
}

struct StockMovementDetailRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let productId: UUID
    let tip: StockMovementKind
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    let sursa: String
    let referinta: String?
    let dataTranzactie: Date?
    let createdAt: Date?
    let invoiceId: UUID?
    let invoiceLineId: UUID?
    @SupabaseOptionalDecimal var pretUnitar: Decimal?
    let invoice: StockMovementInvoiceRef?
    let invoiceLine: StockMovementInvoiceLineRef?

    enum CodingKeys: String, CodingKey {
        case id, tip, cantitate, sursa, referinta, invoice
        case companyId = "company_id"
        case productId = "product_id"
        case unitateMasura = "unitate_masura"
        case dataTranzactie = "data_tranzactie"
        case createdAt = "created_at"
        case invoiceId = "invoice_id"
        case invoiceLineId = "invoice_line_id"
        case pretUnitar = "pret_unitar"
        case invoiceLine = "invoice_line"
    }

    var transactionDate: Date {
        dataTranzactie ?? createdAt ?? .distantPast
    }

    var documentNumber: String {
        let trimmed = invoice?.numarFactura.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        let reference = referinta?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !reference.isEmpty { return reference }
        return "—"
    }

    var unitPurchasePrice: Decimal {
        if let pretUnitar, pretUnitar != 0 {
            return pretUnitar
        }
        return invoiceLine?.pretUnitar ?? .zero
    }

    var vatPercent: Decimal? {
        invoiceLine?.vatPercent
    }
}

struct ProductWarehouseCardContext: Identifiable, Hashable, Sendable {
    let row: ProductStockRow
    let canEdit: Bool

    var id: UUID { row.productId }
}

struct ProductWarehouseLedgerEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let nrCrt: Int
    let dataTranzactie: Date
    let numarDocument: String
    let fel: StockMovementKind
    let cantitate: Decimal
    let pret: Decimal
    let stocFinal: Decimal

    var cantitateDisplay: String {
        let amount = SupplierFormatting.amountString(abs(cantitate))
        return cantitate >= 0 ? "+\(amount)" : "−\(amount)"
    }

    var pretDisplay: String {
        SupplierFormatting.amountString(pret)
    }

    var stocFinalDisplay: String {
        SupplierFormatting.amountString(stocFinal)
    }
}

struct StockMovementProductRef: Codable, Hashable, Sendable {
    let denumire: String
    let cod: String?
    let codBare: String?

    enum CodingKeys: String, CodingKey {
        case denumire, cod
        case codBare = "cod_bare"
    }
}

struct StockMovementRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let productId: UUID
    let tip: StockMovementKind
    @SupabaseDecimal var cantitate: Decimal
    let unitateMasura: String
    let sursa: String
    let referinta: String?
    let dataTranzactie: Date?
    let createdAt: Date?
    let product: StockMovementProductRef?

    enum CodingKeys: String, CodingKey {
        case id, tip, cantitate, sursa, referinta, product
        case companyId = "company_id"
        case productId = "product_id"
        case unitateMasura = "unitate_masura"
        case dataTranzactie = "data_tranzactie"
        case createdAt = "created_at"
    }

    var transactionDate: Date {
        dataTranzactie ?? createdAt ?? .distantPast
    }

    var sourceLabel: String {
        StockMovementSource(rawValue: sursa)?.label ?? sursa
    }

    var productName: String {
        product?.denumire ?? L10n.tr("inventory.unknown_product")
    }
}
