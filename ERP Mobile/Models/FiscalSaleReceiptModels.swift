import Foundation

enum FiscalSaleReceiptSource: String, Codable, Sendable {
    case manual
    case pos
    case binaImport = "bina_import"
}

struct FiscalSaleReceipt: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var workLocationId: UUID?
    var saleDate: Date
    var issuedAt: Date
    var receiptNumber: String
    @SupabaseDecimal var totalAmount: Decimal
    @SupabaseDecimal var numerar: Decimal
    @SupabaseDecimal var card: Decimal
    @SupabaseDecimal var plataModerna: Decimal
    var closingZReportId: UUID?
    var source: FiscalSaleReceiptSource
    var clientLabel: String?
    var notes: String?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, notes, source
        case companyId = "company_id"
        case workLocationId = "work_location_id"
        case saleDate = "sale_date"
        case issuedAt = "issued_at"
        case receiptNumber = "receipt_number"
        case totalAmount = "total_amount"
        case numerar, card
        case plataModerna = "plata_moderna"
        case closingZReportId = "closing_z_report_id"
        case clientLabel = "client_label"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displayClient: String {
        let label = clientLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? L10n.tr("module.sales.cash_sale.client_implicit") : label
    }
}

struct FiscalSaleReceiptLine: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let receiptId: UUID
    var productId: UUID?
    var denumire: String
    @SupabaseDecimal var cantitate: Decimal
    @SupabaseDecimal var pretUnitar: Decimal
    @SupabaseDecimal var cotaTva: Decimal
    @SupabaseDecimal var discountAmount: Decimal
    var sortOrder: Int
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire
        case companyId = "company_id"
        case receiptId = "receipt_id"
        case productId = "product_id"
        case cantitate
        case pretUnitar = "pret_unitar"
        case cotaTva = "cota_tva"
        case discountAmount = "discount_amount"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var lineGross: Decimal {
        cantitate * pretUnitar - discountAmount
    }
}

struct FiscalSaleShiftBucket: Identifiable, Hashable, Sendable {
    let id: UUID
    let workLocationId: UUID?
    let saleDate: Date
    let zNumber: Int?
    let closingZReportId: UUID?
    let endsAt: Date?
    let isNightShift: Bool
    let isOpen: Bool
    var receipts: [FiscalSaleReceipt]
    /// Linked Z report when closed (for Detalii / PDF).
    var zReport: CompanyZReportRecord?

    var receiptCount: Int { receipts.count }

    var totalAmount: Decimal {
        if let zReport { return zReport.totalVanzari }
        return receipts.reduce(0) { $0 + $1.totalAmount }
    }

    var titleKeySuffix: String {
        if isOpen { return "open" }
        return isNightShift ? "night" : "day"
    }

    static func == (lhs: FiscalSaleShiftBucket, rhs: FiscalSaleShiftBucket) -> Bool {
        lhs.id == rhs.id
            && lhs.workLocationId == rhs.workLocationId
            && lhs.saleDate == rhs.saleDate
            && lhs.zNumber == rhs.zNumber
            && lhs.closingZReportId == rhs.closingZReportId
            && lhs.endsAt == rhs.endsAt
            && lhs.isNightShift == rhs.isNightShift
            && lhs.isOpen == rhs.isOpen
            && lhs.receipts == rhs.receipts
            && lhs.zReport?.id == rhs.zReport?.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(workLocationId)
        hasher.combine(saleDate)
        hasher.combine(zNumber)
        hasher.combine(closingZReportId)
        hasher.combine(endsAt)
        hasher.combine(isNightShift)
        hasher.combine(isOpen)
        hasher.combine(receipts)
        hasher.combine(zReport?.id)
    }
}

struct FiscalSaleDayBucket: Identifiable, Hashable, Sendable {
    var id: Date { saleDate }
    let saleDate: Date
    var shifts: [FiscalSaleShiftBucket]

    var receiptCount: Int { shifts.reduce(0) { $0 + $1.receiptCount } }

    var totalAmount: Decimal {
        shifts.reduce(0) { $0 + $1.totalAmount }
    }
}

struct FiscalSaleLocationBucket: Identifiable, Hashable, Sendable {
    let id: UUID
    let location: CompanyWorkLocation
    var days: [FiscalSaleDayBucket]

    var receiptCount: Int { days.reduce(0) { $0 + $1.receiptCount } }

    var totalAmount: Decimal {
        days.reduce(0) { $0 + $1.totalAmount }
    }
}

/// Prefill for creating a client invoice from a fiscal receipt.
struct ClientInvoiceCreateDraft: Sendable {
    var sumaTotala: Decimal
    var dataFactura: Date
    var observatii: String?
    var sourceFiscalReceiptId: UUID?
}

struct FiscalSaleReceiptInsert: Encodable, Sendable {
    let id: UUID?
    let companyId: UUID
    let workLocationId: UUID?
    let saleDate: String
    let issuedAt: Date
    let receiptNumber: String
    let totalAmount: String
    let numerar: String
    let card: String
    let plataModerna: String
    let closingZReportId: UUID?
    let source: String
    let clientLabel: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes, source
        case companyId = "company_id"
        case workLocationId = "work_location_id"
        case saleDate = "sale_date"
        case issuedAt = "issued_at"
        case receiptNumber = "receipt_number"
        case totalAmount = "total_amount"
        case numerar, card
        case plataModerna = "plata_moderna"
        case closingZReportId = "closing_z_report_id"
        case clientLabel = "client_label"
    }
}

struct SalesSavedZSheet: Decodable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sheetDate: String
    let shiftNo: Int
    let zNumber: String

    enum CodingKeys: String, CodingKey {
        case id
        case sheetDate = "sheet_date"
        case shiftNo = "shift_no"
        case zNumber = "z_number"
    }

    var label: String {
        let parts = sheetDate.split(separator: "-")
        let shown = parts.count == 3 ? "\(parts[2]).\(parts[1]).\(parts[0])" : sheetDate
        let number = zNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let z = number.isEmpty ? "—" : number
        return L10n.tr("module.sales.cash_sale.receipts_z_label", z, shown, shiftNo)
    }
}

struct SalesIssuedReceiptLine: Decodable, Hashable, Sendable {
    let denumire: String
    let um: String
    let cantitate: Decimal

    enum CodingKeys: String, CodingKey {
        case denumire, cantitate, um
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        denumire = try container.decodeIfPresent(String.self, forKey: .denumire) ?? ""
        um = try container.decodeIfPresent(String.self, forKey: .um) ?? "buc"
        if let number = try? container.decode(Double.self, forKey: .cantitate) {
            cantitate = Decimal(number)
        } else if let text = try? container.decode(String.self, forKey: .cantitate),
                  let number = Decimal(string: text.replacingOccurrences(of: ",", with: ".")) {
            cantitate = number
        } else {
            cantitate = 0
        }
    }
}

struct SalesIssuedReceipt: Decodable, Identifiable, Hashable, Sendable {
    let receiptNumber: String
    let issuedAt: Date
    let lines: [SalesIssuedReceiptLine]
    let slipPath: String?

    var id: String { "\(receiptNumber)|\(issuedAt.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case receiptNumber = "receipt_number"
        case issuedAt = "issued_at"
        case lines
        case slipPath = "slip_path"
    }
}

struct PosSoldProductsOpenParams: Encodable {
    let workLocationId: UUID

    enum CodingKeys: String, CodingKey {
        case workLocationId = "p_work_location_id"
    }
}

struct PosSoldProductsSheetParams: Encodable {
    let workLocationId: UUID
    let sheetId: UUID

    enum CodingKeys: String, CodingKey {
        case workLocationId = "p_work_location_id"
        case sheetId = "p_sheet_id"
    }
}

struct PosSoldProduct: Decodable, Identifiable, Hashable, Sendable {
    let id: UUID
    let group: String
    let groupOrder: Int
    let code: String
    let name: String
    let unit: String
    let quantity: Decimal
    let price: Decimal
    let value: Decimal

    enum CodingKeys: String, CodingKey {
        case group = "grupa"
        case groupOrder = "grupa_ordine"
        case code = "cod"
        case name = "denumire"
        case unit = "um"
        case quantity = "cantitate"
        case price = "pret"
        case value = "valoare"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        group = try container.decodeIfPresent(String.self, forKey: .group) ?? "Fără grupă"
        groupOrder = try container.decodeIfPresent(Int.self, forKey: .groupOrder) ?? 100000
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? ""
        quantity = try container.decode(SupabaseDecimal.self, forKey: .quantity).wrappedValue
        price = try container.decode(SupabaseDecimal.self, forKey: .price).wrappedValue
        value = try container.decode(SupabaseDecimal.self, forKey: .value).wrappedValue
    }
}

struct SalesFiscalReceiptsParams: Encodable {
    let workLocationId: UUID
    let sheetId: UUID?

    enum CodingKeys: String, CodingKey {
        case workLocationId = "p_work_location_id"
        case sheetId = "p_sheet_id"
    }
}

struct FiscalSaleReceiptLineInsert: Encodable, Sendable {
    let companyId: UUID
    let receiptId: UUID
    let productId: UUID?
    let denumire: String
    let cantitate: String
    let pretUnitar: String
    let cotaTva: String
    let discountAmount: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case denumire
        case companyId = "company_id"
        case receiptId = "receipt_id"
        case productId = "product_id"
        case cantitate
        case pretUnitar = "pret_unitar"
        case cotaTva = "cota_tva"
        case discountAmount = "discount_amount"
        case sortOrder = "sort_order"
    }

    init(
        companyId: UUID,
        receiptId: UUID,
        productId: UUID?,
        denumire: String,
        cantitate: Decimal,
        pretUnitar: Decimal,
        cotaTva: Decimal,
        discountAmount: Decimal,
        sortOrder: Int
    ) {
        self.companyId = companyId
        self.receiptId = receiptId
        self.productId = productId
        self.denumire = denumire
        self.cantitate = NSDecimalNumber(decimal: cantitate).stringValue
        self.pretUnitar = NSDecimalNumber(decimal: pretUnitar).stringValue
        self.cotaTva = NSDecimalNumber(decimal: cotaTva).stringValue
        self.discountAmount = NSDecimalNumber(decimal: discountAmount).stringValue
        self.sortOrder = sortOrder
    }
}
