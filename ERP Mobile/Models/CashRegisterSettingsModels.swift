import Foundation

enum CashRegisterProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case binaSmartBusiness
    case genericHttp
    case memgest
    case bocp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .binaSmartBusiness: return L10n.tr("utilities.cash_register.provider_bina")
        case .genericHttp: return L10n.tr("utilities.cash_register.provider_generic")
        case .memgest: return L10n.tr("utilities.cash_register.provider_memgest")
        case .bocp: return L10n.tr("utilities.cash_register.provider_bocp")
        }
    }
}

enum CashRegisterZExportMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case individualFiles
    case singleCombinedFile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .individualFiles: return L10n.tr("utilities.cash_register.export_individual")
        case .singleCombinedFile: return L10n.tr("utilities.cash_register.export_combined")
        }
    }
}

struct CashRegisterSettingsPayload: Codable, Equatable, Sendable {
    var provider: CashRegisterProvider = .binaSmartBusiness
    var baseURL: String = ""
    var username: String = ""
    var exportMode: CashRegisterZExportMode = .individualFiles
    var binaLocationFilter: String = ""
    var exportDirectory: String = ""
}

struct CompanyCashRegisterSettings: Codable, Identifiable, Sendable {
    var companyId: UUID
    var payload: CashRegisterSettingsPayload
    var updatedAt: Date?

    var id: UUID { companyId }

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case payload = "settings"
        case updatedAt = "updated_at"
    }

    static func defaults(companyId: UUID) -> CompanyCashRegisterSettings {
        CompanyCashRegisterSettings(companyId: companyId, payload: .init(), updatedAt: nil)
    }
}

struct ExtractedCashRegisterZReport: Identifiable, Sendable {
    let id: UUID
    let reportDate: Date
    let reportNumber: String?
    let textContent: String
    let pdfData: Data?

    init(
        id: UUID = UUID(),
        reportDate: Date,
        reportNumber: String? = nil,
        textContent: String,
        pdfData: Data? = nil
    ) {
        self.id = id
        self.reportDate = reportDate
        self.reportNumber = reportNumber
        self.textContent = textContent
        self.pdfData = pdfData
    }
}

struct CashRegisterZReportPreviewItem: Identifiable, Sendable, Equatable {
    let remoteID: String
    let reportNumber: String?
    let reportDate: Date
    let location: String?
    let posNumber: String?

    var id: String { remoteID }
}

struct CashRegisterExtractRequest: Sendable {
    let provider: CashRegisterProvider
    let baseURL: URL
    let username: String
    let password: String
    let fromDate: Date
    let toDate: Date
    let binaLocationFilter: String?
}

enum CashRegisterExtractError: LocalizedError {
    case invalidAddress
    case webLoginAddress
    case authenticationFailed
    case noReportsFound
    case unsupportedResponse
    case apiNotAvailable
    case binaCompanyNotFound(String)
    case romanianPDFUnavailable
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return L10n.tr("utilities.cash_register.error_invalid_address")
        case .webLoginAddress:
            return L10n.tr("utilities.cash_register.error_web_login_address")
        case .authenticationFailed:
            return L10n.tr("utilities.cash_register.error_auth")
        case .noReportsFound:
            return L10n.tr("utilities.cash_register.error_no_reports")
        case .unsupportedResponse:
            return L10n.tr("utilities.cash_register.error_unsupported_response")
        case .apiNotAvailable:
            return L10n.tr("utilities.cash_register.error_api_not_available")
        case .binaCompanyNotFound(let companyName):
            return L10n.tr("utilities.cash_register.error_bina_company_not_found", companyName)
        case .romanianPDFUnavailable:
            return L10n.tr("utilities.cash_register.error_romanian_pdf")
        case .network(let message):
            if message.contains("404") {
                return L10n.tr("utilities.cash_register.error_http_404")
            }
            if message.contains("403") {
                return L10n.tr("utilities.cash_register.error_http_403")
            }
            return L10n.tr("utilities.cash_register.error_network", message)
        }
    }
}
