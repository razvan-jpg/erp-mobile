import Foundation

struct PartnerListRow: Identifiable, Hashable, Sendable {
    let id: String
    let denumire: String
    let cui: String?
    let telefon: String?
    let role: PartnerRole
    let supplierRow: SupplierListRow?
    let clientRow: ClientListRow?

    var hasSupplier: Bool { supplierRow != nil }
    var hasClient: Bool { clientRow != nil }

    var supplierSold: Decimal { supplierRow?.soldRestant ?? 0 }
    var clientSold: Decimal { clientRow?.soldRestant ?? 0 }

    var netSold: Decimal {
        switch role {
        case .supplierOnly: return supplierSold
        case .clientOnly: return clientSold
        case .both: return supplierSold - clientSold
        }
    }

    var displayMoneda: String {
        supplierRow?.moneda ?? clientRow?.moneda ?? "RON"
    }

    var isActive: Bool {
        switch role {
        case .supplierOnly:
            return supplierRow?.supplier.isActive ?? true
        case .clientOnly:
            return clientRow?.client.isActive ?? true
        case .both:
            return (supplierRow?.supplier.isActive ?? false) || (clientRow?.client.isActive ?? false)
        }
    }
}

struct PartnerDetailData: Sendable {
    let row: PartnerListRow
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let supplierPaymentTermDays: Int?
    let clientPaymentTermDays: Int?
    let supplierObservatii: String?
    let clientObservatii: String?
    let supplierIsActive: Bool?
    let clientIsActive: Bool?

    init(row: PartnerListRow) {
        self.row = row
        denumire = row.denumire
        cui = row.supplierRow?.supplier.cui ?? row.clientRow?.client.cui
        nrRegCom = row.supplierRow?.supplier.nrRegCom ?? row.clientRow?.client.nrRegCom
        adresa = row.supplierRow?.supplier.adresa ?? row.clientRow?.client.adresa
        iban = row.supplierRow?.supplier.iban ?? row.clientRow?.client.iban
        email = row.supplierRow?.supplier.email ?? row.clientRow?.client.email
        telefon = row.supplierRow?.supplier.telefon ?? row.clientRow?.client.telefon
        supplierPaymentTermDays = row.supplierRow?.supplier.nrZileScadenta
        clientPaymentTermDays = row.clientRow?.client.nrZileScadenta
        supplierObservatii = row.supplierRow?.supplier.observatii
        clientObservatii = row.clientRow?.client.observatii
        supplierIsActive = row.supplierRow?.supplier.isActive
        clientIsActive = row.clientRow?.client.isActive
    }
}
