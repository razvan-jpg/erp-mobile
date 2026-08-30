import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CashRegisterZExtractViewModel: ObservableObject {
    @Published var provider: CashRegisterProvider = .binaSmartBusiness
    @Published var baseURL = ""
    @Published var username = ""
    @Published var password = ""
    @Published var fromDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var toDate = Date()
    @Published var exportMode: CashRegisterZExportMode = .individualFiles
    @Published var binaLocationFilter = ""
    @Published var exportDirectory = ""

    @Published var extractedReports: [ExtractedCashRegisterZReport] = []
    @Published var availableReports: [CashRegisterZReportPreviewItem] = []
    @Published var selectedReportIDs: Set<String> = []
    @Published var isProcessing = false
    @Published var isLoadingSettings = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var lastExportURLs: [URL] = []
    @Published var importedFiles: [ImportedZFile] = []
    @Published var showExportDirectoryPicker = false
    #if os(iOS) || targetEnvironment(macCatalyst)
    @Published var pendingShare: CashRegisterPendingShare?
    #endif

    struct ImportedZFile: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
    }

    static let binaLocationPresets = ["", "PLOIESTI", "AGRONOMIEI"]
    private static let exportLabel = "Rapoarte-Z"
    private var listedBinaRows: [BinaPosZReportRow] = []
    private var binaWeb: BinaSmartBusinessSessionClient.WebSession?
    private var binaBase: URL?

    var isBinaProvider: Bool { provider == .binaSmartBusiness }
    var hasAvailableReports: Bool { !availableReports.isEmpty }
    var selectedReportsCount: Int { selectedReportIDs.count }

    var canDownloadSelected: Bool {
        hasAvailableReports && !selectedReportIDs.isEmpty && !isProcessing
    }

    private var settingsScopeId: UUID { CashRegisterSettingsService.globalScopeId }

    var resolvedExportDirectory: URL {
        CashRegisterExportDirectoryResolver.resolve(
            storedPath: exportDirectory.isEmpty ? nil : exportDirectory,
            companyName: Self.exportLabel,
            companyId: settingsScopeId
        )
    }

    func loadSettings() async {
        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            let settings = try await CashRegisterSettingsService.fetchGlobalSettings()
            provider = settings.payload.provider
            baseURL = settings.payload.baseURL
            username = settings.payload.username
            exportMode = settings.payload.exportMode
            binaLocationFilter = settings.payload.binaLocationFilter
            exportDirectory = settings.payload.exportDirectory
            password = CashRegisterSettingsService.loadGlobalPassword() ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistSettings() async {
        let payload = CashRegisterSettingsPayload(
            provider: provider,
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            exportMode: exportMode,
            binaLocationFilter: binaLocationFilter.trimmingCharacters(in: .whitespacesAndNewlines),
            exportDirectory: exportDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let settings = CompanyCashRegisterSettings(companyId: settingsScopeId, payload: payload, updatedAt: nil)
        _ = try? await CashRegisterSettingsService.saveGlobalSettings(settings, password: password)
    }

    func listReportsInPeriod() async {
        guard validateConnectionInputs() else { return }

        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        extractedReports = []
        lastExportURLs = []
        availableReports = []
        selectedReportIDs = []
        listedBinaRows = []
        binaWeb = nil
        binaBase = nil

        do {
            await persistSettings()
            let request = makeExtractRequest()
            if isBinaProvider {
                let (web, base) = try await BinaSmartBusinessSessionClient.authenticateAndPrepare(
                    loginURL: FiscalRegisterZReportClient.binaLoginURL(from: request.baseURL),
                    username: request.username,
                    password: request.password
                )
                binaWeb = web
                binaBase = base
                let rows = try await BinaPosZReportService.listReports(
                    web: web,
                    base: base,
                    from: request.fromDate,
                    to: request.toDate,
                    locationFilter: request.binaLocationFilter,
                    customerCompanyID: nil
                )
                listedBinaRows = rows
                availableReports = rows.map {
                    CashRegisterZReportPreviewItem(
                        remoteID: $0.remoteID,
                        reportNumber: $0.number,
                        reportDate: $0.date,
                        location: $0.location,
                        posNumber: $0.posNumber
                    )
                }
                selectedReportIDs = Set(rows.map(\.remoteID))
                statusMessage = L10n.tr("utilities.cash_register.listed_count", availableReports.count)
            } else {
                let raw = try await FiscalRegisterZReportClient.extractReports(request: request)
                let processed = CashRegisterZReportProcessor.normalize(raw)
                guard !processed.isEmpty else {
                    throw CashRegisterExtractError.noReportsFound
                }
                extractedReports = processed.sorted { $0.reportDate < $1.reportDate }
                statusMessage = L10n.tr("utilities.cash_register.extracted_count", processed.count)
                saveExtractedReportsToDefaultFolder()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func downloadSelectedReports() async {
        guard isBinaProvider else { return }
        guard validateConnectionInputs() else { return }
        guard canDownloadSelected else {
            errorMessage = L10n.tr("utilities.cash_register.error_no_selection")
            return
        }

        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        extractedReports = []
        lastExportURLs = []

        do {
            await persistSettings()
            let request = makeExtractRequest()
            let selected = listedBinaRows.filter { selectedReportIDs.contains($0.remoteID) }
            guard !selected.isEmpty else {
                throw CashRegisterExtractError.noReportsFound
            }

            let raw: [ExtractedCashRegisterZReport]
            if isBinaProvider {
                // Refolosește sesiunea de la listare — exact ca în browser (același tab/sesiune).
                if let web = binaWeb, let base = binaBase {
                    raw = try await BinaPosZReportService.downloadReports(
                        web: web,
                        base: base,
                        rows: selected,
                        from: request.fromDate,
                        to: request.toDate,
                        locationFilter: request.binaLocationFilter
                    )
                } else {
                    let (web, base) = try await BinaSmartBusinessSessionClient.authenticateAndPrepare(
                        loginURL: FiscalRegisterZReportClient.binaLoginURL(from: request.baseURL),
                        username: request.username,
                        password: request.password
                    )
                    raw = try await BinaPosZReportService.downloadReports(
                        web: web,
                        base: base,
                        rows: selected,
                        from: request.fromDate,
                        to: request.toDate,
                        locationFilter: request.binaLocationFilter
                    )
                }
            } else {
                raw = try await FiscalRegisterZReportClient.downloadSelectedReports(
                    request: request,
                    selectedRemoteIDs: Array(selectedReportIDs),
                    listedRows: listedBinaRows
                )
            }
            let processed = CashRegisterZReportProcessor.normalize(raw)
            guard !processed.isEmpty else {
                throw CashRegisterExtractError.noReportsFound
            }
            extractedReports = processed.sorted { $0.reportDate < $1.reportDate }
            statusMessage = L10n.tr("utilities.cash_register.extracted_count", processed.count)
            saveExtractedReportsToDefaultFolder()
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func extractReports() async {
        if isBinaProvider {
            await downloadSelectedReports()
        } else {
            await listReportsInPeriod()
        }
    }

    func toggleReportSelection(_ remoteID: String) {
        if selectedReportIDs.contains(remoteID) {
            selectedReportIDs.remove(remoteID)
        } else {
            selectedReportIDs.insert(remoteID)
        }
    }

    func selectAllReports() {
        selectedReportIDs = Set(availableReports.map(\.remoteID))
    }

    func deselectAllReports() {
        selectedReportIDs = []
    }

    private func validateConnectionInputs() -> Bool {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_missing_url")
            return false
        }
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_missing_user")
            return false
        }
        guard !password.isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_missing_password")
            return false
        }

        var normalizedURL = trimmedURL
        if provider == .binaSmartBusiness {
            if !normalizedURL.lowercased().hasPrefix("http") {
                normalizedURL = "https://" + normalizedURL
            }
        } else if !normalizedURL.lowercased().hasPrefix("http") {
            normalizedURL = "http://" + normalizedURL
        }
        guard let url = URL(string: normalizedURL), url.host != nil else {
            errorMessage = CashRegisterExtractError.invalidAddress.errorDescription
            return false
        }

        let calendar = Calendar.current
        let from = calendar.startOfDay(for: fromDate)
        let to = calendar.startOfDay(for: toDate)
        guard from <= to else {
            errorMessage = L10n.tr("utilities.cash_register.error_invalid_period")
            return false
        }
        return true
    }

    private func makeExtractRequest() -> CashRegisterExtractRequest {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalizedURL = trimmedURL
        if provider == .binaSmartBusiness {
            if !normalizedURL.lowercased().hasPrefix("http") {
                normalizedURL = "https://" + normalizedURL
            }
        } else if !normalizedURL.lowercased().hasPrefix("http") {
            normalizedURL = "http://" + normalizedURL
        }
        let url = URL(string: normalizedURL)!
        let apiBaseURL = provider == .binaSmartBusiness ? url : FiscalRegisterZReportClient.normalizeBaseURL(url)
        let calendar = Calendar.current
        let locationFilter = binaLocationFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        return CashRegisterExtractRequest(
            provider: provider,
            baseURL: apiBaseURL,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            fromDate: calendar.startOfDay(for: fromDate),
            toDate: calendar.startOfDay(for: toDate),
            binaLocationFilter: locationFilter.isEmpty ? nil : locationFilter
        )
    }

    func chooseExportDirectory() {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        guard let folder = UtilityDirectoryPicker.pickDirectory(
            prompt: L10n.tr("utilities.cash_register.choose_folder"),
            message: L10n.tr("utilities.cash_register.export_folder_message")
        ) else { return }
        applyPickedExportDirectory(folder)
        #else
        showExportDirectoryPicker = true
        #endif
    }

    func confirmExportDirectory(parent: URL, newFolderName: String) {
        errorMessage = nil
        let trimmedName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            applyPickedExportDirectory(parent)
            return
        }

        let accessed = parent.startAccessingSecurityScopedResource()
        defer {
            if accessed { parent.stopAccessingSecurityScopedResource() }
        }

        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let safeName = trimmedName.components(separatedBy: invalid).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_invalid_folder_name")
            return
        }

        let target = parent.appendingPathComponent(safeName, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            applyPickedExportDirectory(target)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPickedExportDirectory(_ folder: URL) {
        exportDirectory = folder.path
        CashRegisterExportDirectoryResolver.saveBookmark(for: folder, companyId: settingsScopeId)
        statusMessage = L10n.tr("utilities.cash_register.export_folder_set", folder.path)
        Task { await persistSettings() }
    }

    private func saveExtractedReportsToDefaultFolder() {
        guard !extractedReports.isEmpty else { return }
        do {
            let folder = resolvedExportDirectory
            let scopeId = settingsScopeId
            let accessed = CashRegisterExportDirectoryResolver.startAccess(for: folder, companyId: scopeId)
            defer {
                if accessed {
                    CashRegisterExportDirectoryResolver.stopAccess(for: folder, companyId: scopeId)
                }
            }
            try CashRegisterExportDirectoryResolver.ensureExists(folder)
            let exportDir = folder.appendingPathComponent("extrase-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

            switch exportMode {
            case .individualFiles:
                let urls = try CashRegisterZReportExporter.exportIndividualReports(
                    extractedReports,
                    to: exportDir
                )
                for source in urls {
                    let target = folder.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: target.path) {
                        try FileManager.default.removeItem(at: target)
                    }
                    try FileManager.default.copyItem(at: source, to: target)
                }
                lastExportURLs = urls
                statusMessage = L10n.tr("utilities.cash_register.saved_to_folder", folder.path, urls.count)
            case .singleCombinedFile:
                let url = try CashRegisterZReportExporter.exportCombinedReport(
                    extractedReports,
                    to: exportDir
                )
                let target = folder.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.copyItem(at: url, to: target)
                lastExportURLs = [target]
                statusMessage = L10n.tr("utilities.cash_register.saved", target.lastPathComponent)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportReports() {
        guard !extractedReports.isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_extract_first")
            return
        }

        do {
            let exportDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("cash-register-z-\(UUID().uuidString)", isDirectory: true)

            switch exportMode {
            case .individualFiles:
                let urls = try CashRegisterZReportExporter.exportIndividualReports(
                    extractedReports,
                    to: exportDir
                )
                lastExportURLs = urls
                presentExport(urls: urls, message: L10n.tr("utilities.cash_register.saved_files", urls.count))
            case .singleCombinedFile:
                let url = try CashRegisterZReportExporter.exportCombinedReport(
                    extractedReports,
                    to: exportDir
                )
                lastExportURLs = [url]
                presentExport(urls: [url], message: L10n.tr("utilities.cash_register.saved", url.lastPathComponent))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearResults() {
        extractedReports = []
        availableReports = []
        selectedReportIDs = []
        listedBinaRows = []
        binaWeb = nil
        binaBase = nil
        importedFiles = []
        statusMessage = nil
        errorMessage = nil
        lastExportURLs = []
    }

    func importUploadedFiles() async {
        guard !importedFiles.isEmpty else {
            errorMessage = L10n.tr("utilities.cash_register.error_no_uploaded_files")
            return
        }

        let calendar = Calendar.current
        let from = calendar.startOfDay(for: fromDate)
        let to = calendar.startOfDay(for: toDate)
        guard from <= to else {
            errorMessage = L10n.tr("utilities.cash_register.error_invalid_period")
            return
        }

        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        extractedReports = []

        do {
            let raw = try FiscalRegisterZReportClient.parseUploadedFiles(
                urls: importedFiles.map(\.url),
                from: from,
                to: to
            )
            let processed = CashRegisterZReportProcessor.normalize(raw)
            extractedReports = processed.sorted { $0.reportDate < $1.reportDate }
            statusMessage = L10n.tr("utilities.cash_register.extracted_count", processed.count)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func registerImportedFiles(_ urls: [URL]) {
        errorMessage = nil
        for source in urls {
            let accessed = source.startAccessingSecurityScopedResource()
            defer {
                if accessed { source.stopAccessingSecurityScopedResource() }
            }
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("z-import-\(UUID().uuidString)-\(source.lastPathComponent)")
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: source, to: destination)
                importedFiles.append(ImportedZFile(name: source.lastPathComponent, url: destination))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        if !importedFiles.isEmpty {
            statusMessage = L10n.tr("utilities.cash_register.uploaded_files", importedFiles.count)
        }
    }

    private func presentExport(urls: [URL], message: String) {
        #if os(macOS) && !targetEnvironment(macCatalyst)
        exportMac(urls: urls, message: message)
        #else
        exportMobile(urls: urls, message: message)
        #endif
    }

    #if os(macOS) && !targetEnvironment(macCatalyst)
    private func exportMac(urls: [URL], message: String) {
        if urls.count == 1, let url = urls.first {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            panel.message = message
            guard panel.runModal() == .OK, let destination = panel.url else { return }
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                statusMessage = L10n.tr("utilities.cash_register.saved", destination.lastPathComponent)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L10n.tr("utilities.cash_register.choose_folder")
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
            lastExportURLs = saved
            statusMessage = L10n.tr("utilities.cash_register.saved_files", saved.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    private func exportMobile(urls: [URL], message: String) {
        statusMessage = message
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingShare = CashRegisterPendingShare(urls: urls)
        #endif
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
struct CashRegisterPendingShare: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif
