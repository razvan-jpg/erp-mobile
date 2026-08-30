import Foundation

struct CompanyZReportRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let companyId: UUID
    let dedupKey: String
    let zNumber: Int
    let reportDate: Date
    @SupabaseDecimal var totalVanzari: Decimal
    @SupabaseDecimal var numerar: Decimal
    @SupabaseDecimal var card: Decimal
    @SupabaseDecimal var plataModerna: Decimal
    let payload: ZReportSnapshot
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case dedupKey = "dedup_key"
        case zNumber = "z_number"
        case reportDate = "report_date"
        case totalVanzari = "total_vanzari"
        case numerar, card
        case plataModerna = "plata_moderna"
        case payload
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var reportData: ZReportData { payload.toReport() }

    /// Data NC (ca în Zetta): ziua vânzărilor; tura noapte = ziua precedentă tipăririi.
    var accountingDate: Date { reportData.date }

    var canPreviewPDF: Bool {
        !reportData.ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CompanyZReportUpsert: Encodable, Sendable {
    let companyId: UUID
    let dedupKey: String
    let zNumber: Int
    let reportDate: String
    let totalVanzari: String
    let numerar: String
    let card: String
    let plataModerna: String
    let payload: ZReportSnapshot

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case dedupKey = "dedup_key"
        case zNumber = "z_number"
        case reportDate = "report_date"
        case totalVanzari = "total_vanzari"
        case numerar, card
        case plataModerna = "plata_moderna"
        case payload
    }

    init(companyId: UUID, report: ZReportData) {
        self.companyId = companyId
        dedupKey = report.importDedupKey ?? UUID().uuidString
        zNumber = report.zNumber
        reportDate = SupabaseDecoding.dateOnlyString(from: report.date)
        totalVanzari = NSDecimalNumber(decimal: report.totalVanzari).stringValue
        numerar = NSDecimalNumber(decimal: report.numerar).stringValue
        card = NSDecimalNumber(decimal: report.card).stringValue
        plataModerna = NSDecimalNumber(decimal: report.plataModerna).stringValue
        payload = ZReportSnapshot(from: report)
    }
}

extension Notification.Name {
    static let clientZReportsDidChange = Notification.Name("clientZReportsDidChange")
    static let clientZettaOpenSituationZReports = Notification.Name("clientZettaOpenSituationZReports")
}

enum ZReportCollectionType: String, Codable, Sendable, CaseIterable {
    case numerar
    case card
    case plataModerna = "plata_moderna"

    var localizationKey: String {
        switch self {
        case .numerar: return "module.clients.z_reports.collection_cash"
        case .card: return "module.clients.z_reports.collection_bank"
        case .plataModerna: return "module.clients.z_reports.collection_modern"
        }
    }

    var label: String { L10n.tr(localizationKey) }
}

struct CompanyZReportCollectionRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let companyId: UUID
    let zReportId: UUID
    let collectionType: ZReportCollectionType
    @SupabaseDecimal var amount: Decimal
    let reportDate: Date
    let zNumber: Int
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case zReportId = "z_report_id"
        case collectionType = "collection_type"
        case amount
        case reportDate = "report_date"
        case zNumber = "z_number"
        case createdAt = "created_at"
    }
}

struct CompanyZReportCollectionUpsert: Encodable, Sendable {
    let companyId: UUID
    let zReportId: UUID
    let collectionType: String
    let amount: String
    let reportDate: String
    let zNumber: Int

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case zReportId = "z_report_id"
        case collectionType = "collection_type"
        case amount
        case reportDate = "report_date"
        case zNumber = "z_number"
    }

    init(record: CompanyZReportRecord, type: ZReportCollectionType, amount: Decimal) {
        companyId = record.companyId
        zReportId = record.id
        collectionType = type.rawValue
        self.amount = NSDecimalNumber(decimal: amount).stringValue
        reportDate = SupabaseDecoding.dateOnlyString(from: record.reportDate)
        zNumber = record.zNumber
    }
}
