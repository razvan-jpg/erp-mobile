import Foundation

enum SyncPayloads {
    struct UUIDPayload: Codable {
        let id: UUID
    }

    struct CashRegisterUpsert: Codable {
        let entry: CashRegisterManualEntry
        let companyId: UUID
    }

    struct CashRegisterDelete: Codable {
        let id: UUID
        let companyId: UUID
    }

    struct SupplierInvoiceCreate: Codable {
        let id: UUID
        let companyId: UUID
        let supplierId: UUID
        let numarFactura: String
        let dataFactura: Date
        let dataScadenta: Date?
        let sumaTotala: Decimal
        let sumaTva: Decimal
        let moneda: String
        let status: InvoiceStatus
        let observatii: String?
        let workLocationId: UUID?
        let warehouseId: UUID?
        let createdBy: UUID?
    }

    struct SupplierInvoiceUpdate: Codable {
        let id: UUID
        let supplierId: UUID
        let numarFactura: String
        let dataFactura: Date
        let dataScadenta: Date?
        let sumaTotala: Decimal
        let sumaTva: Decimal
        let moneda: String
        let status: InvoiceStatus
        let observatii: String?
        let workLocationId: UUID?
        let warehouseId: UUID?
    }

    struct SupplierInvoiceLinesReplace: Codable {
        let invoiceId: UUID
        let companyId: UUID
        let lines: [SupplierInvoiceLineDraft]
    }

    struct SupplierInvoiceLineDraft: Codable {
        let id: UUID?
        let productId: UUID?
        let numarLinie: Int
        let denumire: String
        let cantitate: Decimal
        let pretUnitar: Decimal
        let sumaLinie: Decimal
        let sumaTva: Decimal
        let cotaTva: Decimal
        let unitateMasura: String?
        let needsProductReview: Bool
    }

    struct SupplierPaymentCreate: Codable {
        let id: UUID
        let companyId: UUID
        let supplierId: UUID
        let invoiceId: UUID?
        let dataPlata: Date
        let suma: Decimal
        let metodaPlata: PaymentMethod
        let referinta: String?
        let observatii: String?
        let createdBy: UUID?
    }

    struct SupplierPaymentUpdate: Codable {
        let id: UUID
        let supplierId: UUID
        let invoiceId: UUID?
        let dataPlata: Date
        let suma: Decimal
        let metodaPlata: PaymentMethod
        let referinta: String?
        let observatii: String?
    }

    struct ReceptionClosed: Codable {
        let invoiceId: UUID
        let closed: Bool
    }

    struct CreditOffsetsReplace: Codable {
        let creditNoteInvoiceId: UUID
        let companyId: UUID
        let offsets: [CreditOffsetDraft]
    }

    struct CreditOffsetDraft: Codable {
        let targetInvoiceId: UUID
        let amount: Decimal
    }

    struct ReceptionConversion: Codable {
        let invoiceLineId: UUID
        let invoiceQuantity: Decimal
        let invoiceUnit: String
        let factor: Decimal
        let stockQuantity: Decimal
        let stockUnit: String
        let stockUnitPrice: Decimal
        let lineValue: Decimal
        let needsConversionReview: Bool
    }

    struct SupplierNIRSave: Codable {
        let nirId: UUID
        let companyId: UUID
        let invoiceId: UUID
        let dataNir: Date
        let workLocationId: UUID?
        let warehouseId: UUID?
        let createdBy: UUID?
        let isUpdate: Bool
        let invoiceLines: [SupplierInvoiceLine]
        let conversions: [ReceptionConversion]
        let products: [Product]
    }

    struct StockTransferPost: Codable {
        let localId: UUID
        let companyId: UUID
        let dataBon: Date
        let sourceWarehouseId: UUID
        let destinationWarehouseId: UUID
        let observatii: String?
        let lines: [StockTransferLineDraft]
    }

    struct StockTransferUpdate: Codable {
        let id: UUID
        let dataBon: Date
        let sourceWarehouseId: UUID
        let destinationWarehouseId: UUID
        let observatii: String?
        let lines: [StockTransferLineDraft]
    }

    struct StockTransferLineDraft: Codable {
        let productId: UUID
        let quantity: Decimal
    }

    struct PhysicalInventoryCreate: Codable {
        let id: UUID
        let companyId: UUID
        let dataInventar: Date
        let observatii: String?
        let createdBy: UUID?
        let warehouseId: UUID?
        let populateFromStock: Bool
        let numarInventar: String
    }

    struct PhysicalInventoryUpsertLine: Codable {
        let inventoryId: UUID
        let productId: UUID
        let cantitateNumarata: Decimal
        let observatii: String?
    }

    struct ClientInvoiceCreate: Codable {
        let id: UUID
        let companyId: UUID
        let clientId: UUID
        let numarFactura: String
        let dataFactura: Date
        let dataScadenta: Date?
        let sumaTotala: Decimal
        let sumaTva: Decimal
        let moneda: String
        let status: InvoiceStatus
        let observatii: String?
        let createdBy: UUID?
    }

    struct ClientInvoiceUpdate: Codable {
        let id: UUID
        let clientId: UUID
        let numarFactura: String
        let dataFactura: Date
        let dataScadenta: Date?
        let sumaTotala: Decimal
        let sumaTva: Decimal
        let moneda: String
        let status: InvoiceStatus
        let observatii: String?
    }

    struct ClientPaymentCreate: Codable {
        let id: UUID
        let companyId: UUID
        let clientId: UUID
        let invoiceId: UUID?
        let dataPlata: Date
        let suma: Decimal
        let metodaPlata: PaymentMethod
        let referinta: String?
        let observatii: String?
        let createdBy: UUID?
    }

    struct ClientPaymentUpdate: Codable {
        let id: UUID
        let clientId: UUID
        let invoiceId: UUID?
        let dataPlata: Date
        let suma: Decimal
        let metodaPlata: PaymentMethod
        let referinta: String?
        let observatii: String?
    }

    struct ZReportUpsertBatch: Codable {
        let companyId: UUID
        let reports: [ZReportOfflineDTO]
    }

    struct ZReportOfflineDTO: Codable {
        let id: UUID
        let zNumber: Int
        let date: Date
        let totalVanzari: Decimal
        let numerar: Decimal
        let card: Decimal
        let plataModerna: Decimal
        let vanzari21: Decimal
        let tva21: Decimal
        let vanzari11: Decimal
        let tva11: Decimal
        let vanzari11C: Decimal
        let tva11C: Decimal
        let vanzari0: Decimal
        let firma: String
        let cui: String
        let locatieLabel: String
        let sourceFileName: String
        let ocrText: String
        let importDedupKey: String?
    }

    struct CMGroupCreate: Codable {
        let id: UUID
        let companyId: UUID
        let name: String
        let sortOrder: Int
    }

    struct CMGroupRename: Codable {
        let id: UUID
        let name: String
    }

    struct CMSetProductGroups: Codable {
        let companyId: UUID
        let productId: UUID
        let groupIds: [UUID]
    }

    struct CMMenuCreate: Codable {
        let id: UUID
        let companyId: UUID
        let name: String
        let pretVanzare: Decimal
        let productIds: [UUID]
        let permiteSecundareMultiple: Bool

        enum CodingKeys: String, CodingKey {
            case id, companyId, name, pretVanzare, productIds, permiteSecundareMultiple
        }

        init(id: UUID, companyId: UUID, name: String, pretVanzare: Decimal, productIds: [UUID], permiteSecundareMultiple: Bool = false) {
            self.id = id
            self.companyId = companyId
            self.name = name
            self.pretVanzare = pretVanzare
            self.productIds = productIds
            self.permiteSecundareMultiple = permiteSecundareMultiple
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            companyId = try container.decode(UUID.self, forKey: .companyId)
            name = try container.decode(String.self, forKey: .name)
            pretVanzare = try container.decode(Decimal.self, forKey: .pretVanzare)
            productIds = try container.decode([UUID].self, forKey: .productIds)
            permiteSecundareMultiple = try container.decodeIfPresent(Bool.self, forKey: .permiteSecundareMultiple) ?? false
        }
    }

    struct CMMenuUpdate: Codable {
        let id: UUID
        let companyId: UUID
        let name: String
        let pretVanzare: Decimal
        let isActive: Bool
        let productIds: [UUID]
        let permiteSecundareMultiple: Bool

        enum CodingKeys: String, CodingKey {
            case id, companyId, name, pretVanzare, isActive, productIds, permiteSecundareMultiple
        }

        init(id: UUID, companyId: UUID, name: String, pretVanzare: Decimal, isActive: Bool, productIds: [UUID], permiteSecundareMultiple: Bool = false) {
            self.id = id
            self.companyId = companyId
            self.name = name
            self.pretVanzare = pretVanzare
            self.isActive = isActive
            self.productIds = productIds
            self.permiteSecundareMultiple = permiteSecundareMultiple
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            companyId = try container.decode(UUID.self, forKey: .companyId)
            name = try container.decode(String.self, forKey: .name)
            pretVanzare = try container.decode(Decimal.self, forKey: .pretVanzare)
            isActive = try container.decode(Bool.self, forKey: .isActive)
            productIds = try container.decode([UUID].self, forKey: .productIds)
            permiteSecundareMultiple = try container.decodeIfPresent(Bool.self, forKey: .permiteSecundareMultiple) ?? false
        }
    }
}

extension SyncPayloads.ReceptionConversion {
    init(lineId: UUID, reception: StockUnitConversion.Reception) {
        invoiceLineId = lineId
        invoiceQuantity = reception.invoiceQuantity
        invoiceUnit = reception.invoiceUnit
        factor = reception.factor
        stockQuantity = reception.stockQuantity
        stockUnit = reception.stockUnit
        stockUnitPrice = reception.stockUnitPrice
        lineValue = reception.lineValue
        needsConversionReview = reception.needsConversionReview
    }

    var asReception: StockUnitConversion.Reception {
        StockUnitConversion.Reception(
            invoiceQuantity: invoiceQuantity,
            invoiceUnit: invoiceUnit,
            factor: factor,
            stockQuantity: stockQuantity,
            stockUnit: stockUnit,
            stockUnitPrice: stockUnitPrice,
            lineValue: lineValue,
            needsConversionReview: needsConversionReview
        )
    }
}
