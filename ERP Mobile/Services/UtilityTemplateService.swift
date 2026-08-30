import Foundation
import Supabase

enum UtilityTemplateService {
    private static let client = SupabaseManager.client

    static func fetchTemplate(_ key: UtilityTemplateKey) async throws -> AppUtilityTemplate {
        if let remote = try await fetchRemote(key) {
            return remote
        }
        return bundledFallback(key)
    }

    static func templateData(_ key: UtilityTemplateKey) async throws -> Data {
        let template = try await fetchTemplate(key)
        if let text = template.contentText, !text.isEmpty {
            return Data(text.utf8)
        }
        return try bundledData(for: template)
    }

    static func templateText(_ key: UtilityTemplateKey) async throws -> String {
        let data = try await templateData(key)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ServiceError.invalidResponse
        }
        return text
    }

    private static func fetchRemote(_ key: UtilityTemplateKey) async throws -> AppUtilityTemplate? {
        let rows: [AppUtilityTemplate] = try await client
            .from("app_utility_templates")
            .select()
            .eq("template_key", value: key.rawValue)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private static func bundledFallback(_ key: UtilityTemplateKey) -> AppUtilityTemplate {
        switch key {
        case .zReportModel:
            AppUtilityTemplate(
                templateKey: key.rawValue,
                displayName: "Raport Z model",
                fileName: "Raport_Z_model.pdf",
                contentText: nil,
                bundleAssetName: "Raport_Z_model",
                updatedAt: nil
            )
        case .mt940Model:
            AppUtilityTemplate(
                templateKey: key.rawValue,
                displayName: "MT940 model",
                fileName: "MT940_model.txt",
                contentText: nil,
                bundleAssetName: "MT940_model",
                updatedAt: nil
            )
        case .registruCasaModel:
            AppUtilityTemplate(
                templateKey: key.rawValue,
                displayName: "Registru de casa model",
                fileName: "Registru_Casa_model.pdf",
                contentText: nil,
                bundleAssetName: "Registru_Casa_model",
                updatedAt: nil
            )
        }
    }

    private static func bundledData(for template: AppUtilityTemplate) throws -> Data {
        guard let asset = template.bundleAssetName else {
            throw ServiceError.invalidResponse
        }
        let ext = (template.fileName as NSString).pathExtension
        let resource = ext.isEmpty ? asset : (asset as NSString).deletingPathExtension
        let resourceExt = ext.isEmpty ? "txt" : ext
        guard let url = Bundle.main.url(forResource: resource, withExtension: resourceExt, subdirectory: "Templates")
            ?? Bundle.main.url(forResource: resource, withExtension: resourceExt) else {
            throw ServiceError.invalidResponse
        }
        return try Data(contentsOf: url)
    }
}
