import Foundation

struct SupplierInvoiceBalanceRow: Codable, Sendable {
    let supplierId: UUID
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    let status: InvoiceStatus
    let dataScadenta: Date?
    let moneda: String

    enum CodingKeys: String, CodingKey {
        case status, moneda
        case supplierId = "supplier_id"
        case sumaTotala = "suma_totala"
        case sumaPlatita = "suma_platita"
        case dataScadenta = "data_scadenta"
    }

    var restDePlata: Decimal {
        if sumaTotala < 0 {
            return sumaTotala + sumaPlatita
        }
        return sumaTotala - sumaPlatita
    }
}

struct SupplierInvoiceCreditOffset: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    let creditInvoiceId: UUID
    let targetInvoiceId: UUID
    @SupabaseDecimal var amount: Decimal
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount
        case companyId = "company_id"
        case creditInvoiceId = "credit_invoice_id"
        case targetInvoiceId = "target_invoice_id"
        case createdAt = "created_at"
    }
}

struct SupplierBalanceSummary: Sendable {
    var soldRestant: Decimal = 0
    var primaScadenta: Date?
    var moneda: String = "RON"
}

struct SupplierListRow: Identifiable, Hashable, Sendable {
    let supplier: Supplier
    let soldRestant: Decimal
    let primaScadenta: Date?
    let moneda: String

    var id: UUID { supplier.id }
}

struct Supplier: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var denumire: String
    var cui: String?
    var nrRegCom: String?
    var adresa: String?
    var iban: String?
    var email: String?
    var telefon: String?
    var observatii: String?
    var nrZileScadenta: Int
    var isActive: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire, cui, adresa, iban, email, telefon, observatii
        case nrRegCom = "nr_reg_com"
        case nrZileScadenta = "nr_zile_scadenta"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        denumire = try container.decode(String.self, forKey: .denumire)
        cui = try container.decodeIfPresent(String.self, forKey: .cui)
        nrRegCom = try container.decodeIfPresent(String.self, forKey: .nrRegCom)
        adresa = try container.decodeIfPresent(String.self, forKey: .adresa)
        iban = try container.decodeIfPresent(String.self, forKey: .iban)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        telefon = try container.decodeIfPresent(String.self, forKey: .telefon)
        observatii = try container.decodeIfPresent(String.self, forKey: .observatii)
        nrZileScadenta = try container.decodeIfPresent(Int.self, forKey: .nrZileScadenta) ?? 0
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case neplatita
    case partial
    case platita
    case anulata

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neplatita: return L10n.tr("invoice.status.unpaid")
        case .partial: return L10n.tr("invoice.status.partial")
        case .platita: return L10n.tr("invoice.status.paid")
        case .anulata: return L10n.tr("invoice.status.cancelled")
        }
    }

    var compactLabel: String {
        switch self {
        case .neplatita: return L10n.tr("invoice.status.unpaid_short")
        case .partial: return L10n.tr("invoice.status.partial_short")
        case .platita: return L10n.tr("invoice.status.paid_short")
        case .anulata: return L10n.tr("invoice.status.cancelled_short")
        }
    }
}

struct SupplierInvoice: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let supplierId: UUID
    var numarFactura: String
    var dataFactura: Date
    var dataScadenta: Date?
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    var moneda: String
    var status: InvoiceStatus
    var observatii: String?
    var workLocationId: UUID?
    var warehouseId: UUID?
    /// Recepție închisă manual (restul nu se mai așteaptă). Complet = toate cantitățile pe NIR.
    var receptionClosed: Bool
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, moneda, status, observatii
        case supplierId = "supplier_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case sumaPlatita = "suma_platita"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
        case receptionClosed = "reception_closed"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        supplierId = try c.decode(UUID.self, forKey: .supplierId)
        numarFactura = try c.decode(String.self, forKey: .numarFactura)
        dataFactura = try c.decode(Date.self, forKey: .dataFactura)
        dataScadenta = try c.decodeIfPresent(Date.self, forKey: .dataScadenta)
        _sumaTotala = try c.decode(SupabaseDecimal.self, forKey: .sumaTotala)
        _sumaTva = try c.decode(SupabaseDecimal.self, forKey: .sumaTva)
        _sumaPlatita = try c.decode(SupabaseDecimal.self, forKey: .sumaPlatita)
        moneda = try c.decode(String.self, forKey: .moneda)
        status = try c.decode(InvoiceStatus.self, forKey: .status)
        observatii = try c.decodeIfPresent(String.self, forKey: .observatii)
        workLocationId = try c.decodeIfPresent(UUID.self, forKey: .workLocationId)
        warehouseId = try c.decodeIfPresent(UUID.self, forKey: .warehouseId)
        receptionClosed = try c.decodeIfPresent(Bool.self, forKey: .receptionClosed) ?? false
        createdBy = try c.decodeIfPresent(UUID.self, forKey: .createdBy)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var restDePlata: Decimal {
        if sumaTotala < 0 {
            return sumaTotala + sumaPlatita
        }
        return sumaTotala - sumaPlatita
    }

    var isCreditNote: Bool {
        sumaTotala < 0
    }

    /// Credit disponibil pentru compensare (valoare pozitivă).
    var availableCreditAmount: Decimal {
        guard isCreditNote else { return 0 }
        return max(0, -restDePlata)
    }

    /// Scadența efectivă: data scadență sau, dacă lipsește, data facturii.
    var effectiveDueDate: Date {
        dataScadenta ?? dataFactura
    }
}

struct SupplierInvoiceRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let supplierId: UUID
    var numarFactura: String
    var dataFactura: Date
    var dataScadenta: Date?
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    var moneda: String
    var status: InvoiceStatus
    var observatii: String?
    var workLocationId: UUID?
    var warehouseId: UUID?
    var receptionClosed: Bool
    let createdAt: Date?
    let updatedAt: Date?
    var supplier: SupplierNameRef?

    enum CodingKeys: String, CodingKey {
        case id, moneda, status, observatii, supplier
        case supplierId = "supplier_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case sumaPlatita = "suma_platita"
        case workLocationId = "work_location_id"
        case warehouseId = "warehouse_id"
        case receptionClosed = "reception_closed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        supplierId = try c.decode(UUID.self, forKey: .supplierId)
        numarFactura = try c.decode(String.self, forKey: .numarFactura)
        dataFactura = try c.decode(Date.self, forKey: .dataFactura)
        dataScadenta = try c.decodeIfPresent(Date.self, forKey: .dataScadenta)
        _sumaTotala = try c.decode(SupabaseDecimal.self, forKey: .sumaTotala)
        _sumaTva = try c.decode(SupabaseDecimal.self, forKey: .sumaTva)
        _sumaPlatita = try c.decode(SupabaseDecimal.self, forKey: .sumaPlatita)
        moneda = try c.decode(String.self, forKey: .moneda)
        status = try c.decode(InvoiceStatus.self, forKey: .status)
        observatii = try c.decodeIfPresent(String.self, forKey: .observatii)
        workLocationId = try c.decodeIfPresent(UUID.self, forKey: .workLocationId)
        warehouseId = try c.decodeIfPresent(UUID.self, forKey: .warehouseId)
        receptionClosed = try c.decodeIfPresent(Bool.self, forKey: .receptionClosed) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        supplier = try c.decodeIfPresent(SupplierNameRef.self, forKey: .supplier)
    }

    var supplierName: String {
        supplier?.denumire ?? "—"
    }

    var restDePlata: Decimal {
        if sumaTotala < 0 {
            return sumaTotala + sumaPlatita
        }
        return sumaTotala - sumaPlatita
    }

    var isCreditNote: Bool {
        sumaTotala < 0
    }

    /// Credit disponibil pentru compensare (valoare pozitivă).
    var availableCreditAmount: Decimal {
        guard isCreditNote else { return 0 }
        return max(0, -restDePlata)
    }

    /// Scadența efectivă: data scadență sau, dacă lipsește, data facturii.
    var effectiveDueDate: Date {
        dataScadenta ?? dataFactura
    }
}

struct SupplierNameRef: Codable, Hashable, Sendable {
    let denumire: String
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case transfer
    case numerar
    case card
    case altele

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transfer: return L10n.tr("payment.method.transfer")
        case .numerar: return L10n.tr("payment.method.cash")
        case .card: return L10n.tr("payment.method.card")
        case .altele: return L10n.tr("payment.method.other")
        }
    }
}

struct SupplierPayment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let supplierId: UUID
    var invoiceId: UUID?
    var dataPlata: Date
    @SupabaseDecimal var suma: Decimal
    var metodaPlata: PaymentMethod
    var referinta: String?
    var observatii: String?
    let createdBy: UUID?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, suma, referinta, observatii
        case supplierId = "supplier_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct UserDisplayName: Codable, Hashable, Sendable {
    let id: UUID
    let nume: String
    let prenume: String

    var displayName: String { "\(prenume) \(nume)" }
}

struct SupplierPaymentRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let supplierId: UUID
    var invoiceId: UUID?
    var dataPlata: Date
    @SupabaseDecimal var suma: Decimal
    var metodaPlata: PaymentMethod
    var referinta: String?
    var observatii: String?
    let createdAt: Date?
    var supplier: SupplierNameRef?
    var invoice: InvoiceNumberRef?

    enum CodingKeys: String, CodingKey {
        case id, suma, referinta, observatii, supplier, invoice
        case supplierId = "supplier_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdAt = "created_at"
    }

    var supplierName: String {
        supplier?.denumire ?? "—"
    }

    var invoiceNumber: String? {
        invoice?.numarFactura
    }
}

struct InvoiceNumberRef: Codable, Hashable, Sendable {
    let numarFactura: String

    enum CodingKeys: String, CodingKey {
        case numarFactura = "numar_factura"
    }
}

struct ModuleAccessRights: Sendable {
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    static let full = ModuleAccessRights(canView: true, canCreate: true, canEdit: true, canDelete: true)
    static let none = ModuleAccessRights(canView: false, canCreate: false, canEdit: false, canDelete: false)

    var canWrite: Bool { canCreate || canEdit }

    static func load(moduleId: UUID, moduleCode: String? = nil, profile: UserProfile) async throws -> ModuleAccessRights {
        if moduleCode == ModuleCode.nomenclatoare {
            return profile.isSuperAdmin || profile.isCompanyAdmin ? .full : .none
        }
        if profile.isSuperAdmin || profile.isCompanyAdmin { return .full }
        let permissions = try await ModuleService.fetchUserPermissions(userId: profile.id)
        guard let permission = permissions.first(where: { $0.moduleId == moduleId }) else {
            return .none
        }
        return ModuleAccessRights(
            canView: permission.canView,
            canCreate: permission.canCreate,
            canEdit: permission.canEdit,
            canDelete: permission.canDelete
        )
    }
}
