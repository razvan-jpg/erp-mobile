import Foundation

struct ClientInvoiceBalanceRow: Codable, Sendable {
    let clientId: UUID
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    let status: InvoiceStatus
    let dataScadenta: Date?
    let moneda: String

    enum CodingKeys: String, CodingKey {
        case status, moneda
        case clientId = "client_id"
        case sumaTotala = "suma_totala"
        case sumaPlatita = "suma_platita"
        case dataScadenta = "data_scadenta"
    }

    var restDePlata: Decimal {
        sumaTotala - sumaPlatita
    }
}

struct ClientBalanceSummary: Sendable {
    var soldRestant: Decimal = 0
    var primaScadenta: Date?
    var moneda: String = "RON"
}

struct ClientListRow: Identifiable, Hashable, Sendable {
    let client: Client
    let soldRestant: Decimal
    let primaScadenta: Date?
    let moneda: String

    var id: UUID { client.id }
}

struct Client: Codable, Identifiable, Hashable, Sendable {
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

struct ClientInvoice: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let clientId: UUID
    var numarFactura: String
    var dataFactura: Date
    var dataScadenta: Date?
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    var moneda: String
    var status: InvoiceStatus
    var observatii: String?
    let createdBy: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, moneda, status, observatii
        case clientId = "client_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case sumaPlatita = "suma_platita"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var restDePlata: Decimal {
        sumaTotala - sumaPlatita
    }

    /// Scadența efectivă: data scadență sau, dacă lipsește, data facturii.
    var effectiveDueDate: Date {
        dataScadenta ?? dataFactura
    }
}

struct ClientInvoiceRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let clientId: UUID
    var numarFactura: String
    var dataFactura: Date
    var dataScadenta: Date?
    @SupabaseDecimal var sumaTotala: Decimal
    @SupabaseDecimal var sumaTva: Decimal
    @SupabaseDecimal var sumaPlatita: Decimal
    var moneda: String
    var status: InvoiceStatus
    var observatii: String?
    var efacturaStatus: EFacturaSendStatus
    var efacturaSentAt: Date?
    var efacturaChannel: String?
    let createdAt: Date?
    let updatedAt: Date?
    var client: ClientNameRef?

    enum CodingKeys: String, CodingKey {
        case id, moneda, status, observatii, client
        case clientId = "client_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case dataScadenta = "data_scadenta"
        case sumaTotala = "suma_totala"
        case sumaTva = "suma_tva"
        case sumaPlatita = "suma_platita"
        case efacturaStatus = "efactura_status"
        case efacturaSentAt = "efactura_sent_at"
        case efacturaChannel = "efactura_channel"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clientId = try c.decode(UUID.self, forKey: .clientId)
        numarFactura = try c.decode(String.self, forKey: .numarFactura)
        dataFactura = try c.decode(Date.self, forKey: .dataFactura)
        dataScadenta = try c.decodeIfPresent(Date.self, forKey: .dataScadenta)
        _sumaTotala = try c.decode(SupabaseDecimal.self, forKey: .sumaTotala)
        _sumaTva = try c.decode(SupabaseDecimal.self, forKey: .sumaTva)
        _sumaPlatita = try c.decode(SupabaseDecimal.self, forKey: .sumaPlatita)
        moneda = try c.decodeIfPresent(String.self, forKey: .moneda) ?? "RON"
        status = try c.decode(InvoiceStatus.self, forKey: .status)
        observatii = try c.decodeIfPresent(String.self, forKey: .observatii)
        efacturaStatus = try c.decodeIfPresent(EFacturaSendStatus.self, forKey: .efacturaStatus) ?? .none
        efacturaSentAt = try c.decodeIfPresent(Date.self, forKey: .efacturaSentAt)
        efacturaChannel = try c.decodeIfPresent(String.self, forKey: .efacturaChannel)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        client = try c.decodeIfPresent(ClientNameRef.self, forKey: .client)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(clientId, forKey: .clientId)
        try c.encode(numarFactura, forKey: .numarFactura)
        try c.encode(dataFactura, forKey: .dataFactura)
        try c.encodeIfPresent(dataScadenta, forKey: .dataScadenta)
        try c.encode(_sumaTotala, forKey: .sumaTotala)
        try c.encode(_sumaTva, forKey: .sumaTva)
        try c.encode(_sumaPlatita, forKey: .sumaPlatita)
        try c.encode(moneda, forKey: .moneda)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(observatii, forKey: .observatii)
        try c.encode(efacturaStatus, forKey: .efacturaStatus)
        try c.encodeIfPresent(efacturaSentAt, forKey: .efacturaSentAt)
        try c.encodeIfPresent(efacturaChannel, forKey: .efacturaChannel)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(client, forKey: .client)
    }

    var clientName: String {
        client?.denumire ?? "—"
    }

    var restDePlata: Decimal {
        sumaTotala - sumaPlatita
    }

    /// Scadența efectivă: data scadență sau, dacă lipsește, data facturii.
    var effectiveDueDate: Date {
        dataScadenta ?? dataFactura
    }
}

struct ClientNameRef: Codable, Hashable, Sendable {
    let denumire: String
    var cui: String?
    var adresa: String?
}

struct ClientPayment: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let clientId: UUID
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
        case clientId = "client_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
}

struct ClientPaymentRow: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let clientId: UUID
    var invoiceId: UUID?
    var dataPlata: Date
    @SupabaseDecimal var suma: Decimal
    var metodaPlata: PaymentMethod
    var referinta: String?
    var observatii: String?
    let createdAt: Date?
    var client: ClientNameRef?
    var invoice: InvoiceNumberRef?

    enum CodingKeys: String, CodingKey {
        case id, suma, referinta, observatii, client, invoice
        case clientId = "client_id"
        case invoiceId = "invoice_id"
        case dataPlata = "data_plata"
        case metodaPlata = "metoda_plata"
        case createdAt = "created_at"
    }

    var clientName: String {
        client?.denumire ?? "—"
    }

    var invoiceNumber: String? {
        invoice?.numarFactura
    }
}
