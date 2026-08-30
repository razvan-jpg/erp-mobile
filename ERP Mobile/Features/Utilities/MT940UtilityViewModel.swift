import Combine
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS) || targetEnvironment(macCatalyst)
struct MT940PendingExport: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif

@MainActor
final class MT940UtilityViewModel: ObservableObject {
    @Published var importedFiles: [ImportedBankFile] = []
    @Published var dailyFiles: [MT940DailyGenerator.DailyFile] = []
    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var lastExportURL: URL?
    @Published private(set) var exportCompanyName = ""
    #if os(iOS) || targetEnvironment(macCatalyst)
    @Published var pendingExport: MT940PendingExport?
    #endif

    struct ImportedBankFile: Identifiable {
        let id = UUID()
        let name: String
        let data: Data
    }

    func importFiles(_ urls: [URL]) {
        errorMessage = nil
        statusMessage = nil
        guard !urls.isEmpty else { return }

        var loadedCount = 0
        for url in urls {
            do {
                let data = try UtilityFilePickerSupport.readData(from: url)
                guard !data.isEmpty else {
                    errorMessage = L10n.tr("utilities.mt940.error_empty_file", url.lastPathComponent)
                    continue
                }
                importedFiles.append(ImportedBankFile(name: url.lastPathComponent, data: data))
                loadedCount += 1
            } catch {
                errorMessage = L10n.tr("utilities.mt940.error_read_file", url.lastPathComponent, error.localizedDescription)
            }
        }
        if loadedCount > 0 {
            statusMessage = L10n.tr("utilities.mt940.files_loaded", importedFiles.count)
        } else if errorMessage == nil {
            errorMessage = L10n.tr("utilities.mt940.error_no_files")
        }
    }

    func clearAll() {
        importedFiles = []
        dailyFiles = []
        exportCompanyName = ""
        statusMessage = nil
        errorMessage = nil
        lastExportURL = nil
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = nil
        #endif
    }

    func generateDailyFiles() async {
        guard !importedFiles.isEmpty else {
            errorMessage = L10n.tr("utilities.mt940.error_no_files")
            return
        }

        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        dailyFiles = []
        exportCompanyName = ""

        do {
            let templateText = try await UtilityTemplateService.templateText(.mt940Model)
            var allTransactions: [MT940Transaction] = []
            var metadata = MT940StatementMetadata()

            for file in importedFiles {
                do {
                    let parsed = try MT940Parser.parseUploadedFile(data: file.data, fileName: file.name)
                    if metadata.field25.isEmpty {
                        metadata = parsed.metadata
                    } else if metadata.accountHolderName.isEmpty,
                              !parsed.metadata.accountHolderName.isEmpty {
                        metadata.accountHolderName = parsed.metadata.accountHolderName
                    }
                    allTransactions.append(contentsOf: parsed.transactions)
                } catch {
                    throw NSError(
                        domain: "MT940Utility",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "\(file.name): \(error.localizedDescription)"]
                    )
                }
            }

            exportCompanyName = MT940StatementLabelExtractor.resolveCompanyName(
                metadata: metadata,
                sourceTexts: [],
                fileNames: importedFiles.map(\.name)
            )

            let merged = MT940ParsedStatement(metadata: metadata, transactions: allTransactions)
            dailyFiles = MT940DailyGenerator.generateDailyFiles(
                statement: merged,
                templateText: templateText,
                companyName: exportCompanyName
            )
            guard !dailyFiles.isEmpty else {
                throw MT940UtilityError.noTransactions
            }
            statusMessage = L10n.tr("utilities.mt940.generated", dailyFiles.count)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func exportGeneratedFiles() {
        guard !dailyFiles.isEmpty else {
            errorMessage = L10n.tr("utilities.mt940.error_generate_first")
            return
        }

        do {
            let urls = try prepareExportFileURLs()
            lastExportURL = urls.last
            let message = L10n.tr("utilities.mt940.save_message", dailyFiles.count)
            #if os(macOS) && !targetEnvironment(macCatalyst)
            exportMac(urls: urls, message: message)
            #else
            exportMobile(urls: urls, message: message)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
    func completePendingExport() {
        pendingExport = nil
    }
    #endif

    private func prepareExportFileURLs() throws -> [URL] {
        let exportDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mt940-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

        var urls: [URL] = []
        for file in dailyFiles {
            let url = exportDir.appendingPathComponent(file.fileName)
            try Data(file.content.utf8).write(to: url, options: .atomic)
            urls.append(url)
        }

        let archiveName = MT940DailyGenerator.suggestedArchiveName(
            companyName: exportCompanyName,
            files: dailyFiles
        )
        let zipURL = exportDir.appendingPathComponent(archiveName)
        try MT940ArchiveExporter.writeArchive(dailyFiles: dailyFiles, to: zipURL)
        urls.append(zipURL)
        return urls
    }

    #if os(macOS) && !targetEnvironment(macCatalyst)
    private func exportMac(urls: [URL], message: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L10n.tr("utilities.mt940.choose_folder")
        panel.message = message
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            var saved: [URL] = []
            for source in urls {
                let target = folder.appendingPathComponent(source.lastPathComponent)
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.copyItem(at: source, to: target)
                saved.append(target)
            }
            lastExportURL = saved.last
            statusMessage = L10n.tr(
                "utilities.mt940.saved_files",
                dailyFiles.count,
                folder.lastPathComponent
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    private func exportMobile(urls: [URL], message: String) {
        statusMessage = message
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = MT940PendingExport(urls: urls)
        #endif
    }
}
