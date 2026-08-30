import Foundation

enum UtilityTemplateKey: String, Codable, Sendable {
    case zReportModel = "z_report_model"
    case mt940Model = "mt940_model"
    case registruCasaModel = "registru_casa_model"
}

struct AppUtilityTemplate: Codable, Identifiable, Sendable {
    let templateKey: String
    let displayName: String
    let fileName: String
    let contentText: String?
    let bundleAssetName: String?
    let updatedAt: Date?

    var id: String { templateKey }

    enum CodingKeys: String, CodingKey {
        case templateKey = "template_key"
        case displayName = "display_name"
        case fileName = "file_name"
        case contentText = "content_text"
        case bundleAssetName = "bundle_asset_name"
        case updatedAt = "updated_at"
    }
}
