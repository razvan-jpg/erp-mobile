import Combine
import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SavedExcelContinuePrompt: Equatable {
    let firmName: String
    let cui: String
}

#if os(iOS)
struct PendingShare: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct PendingLocalSave: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif

@MainActor
final class ZettaAppViewModel: ObservableObject {
    @Published var reports: [ZReportData] = []
    @Published private(set) var previewRows: [NotaContabilaRow] = []
    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var lastExportURL: URL?
    @Published var savedExcelSessions: [SavedExcelSession] = []
    @Published var showSavedExcelWarning = false
    @Published var savedExcelContinuePrompt: SavedExcelContinuePrompt?
    private var savedExcelWarningHandled = false
    private(set) var erpContext: ZettaERPContext?
    private(set) var zettaNCConfig: ZettaNCConfig?
    var exportNamingStyle: ExcelExportNamingStyle = .accountingNote
    var utilityCompanyDisplayName: String?
    #if os(iOS)
    @Published var showXlsxPicker = false
    #endif
    #if os(iOS)
    @Published var pendingShare: PendingShare?
    @Published var pendingLocalSave: PendingLocalSave?
    private var exportFlowContinuation: CheckedContinuation<Void, Never>?
    #endif

    /// Rapoarte prelucrate cu succes — butonul „Generează Excel & Salvează” devine activ.
    var isReadyForExportAndSave: Bool {
        !isProcessing
            && !scopedReports.isEmpty
            && scopedReports.allSatisfy(isReportReadyForExportAndSave)
    }

    private func isReportReadyForExportAndSave(_ report: ZReportData) -> Bool {
        guard report.zNumber > 0, report.totalVanzari > 0 else { return false }
        if report.parseSource == .digitalPDF { return true }
        if report.isBalanced { return true }
        return ZParser.importQualityMessage(for: report, ocrText: report.ocrText) == nil
    }

    func prepareForExport(reports: [ZReportData], config: ZettaNCConfig?) {
        erpContext = nil
        self.reports = reports
        zettaNCConfig = config
        exportNamingStyle = .accountingNote
        syncPreviewRows()
    }

    func savedSession(for report: ZReportData) -> SavedExcelSession? {
        let key = FirmaRegistry.groupingKey(for: report)
        return savedExcelSessions.first { $0.firmGroupingKey == key }
    }

    func bindERPContext(_ context: ZettaERPContext) {
        if erpContext?.companyId != context.companyId {
            resetForCompanyChange()
        }
        erpContext = context
        if context.isUtilityStandalone {
            exportNamingStyle = .zettaUtility
            utilityCompanyDisplayName = nil
            return
        }
        Task { await loadZettaNCConfig(companyId: context.companyId) }
    }

    func reloadZettaNCConfig() async {
        guard let companyId = erpContext?.companyId else { return }
        await loadZettaNCConfig(companyId: companyId)
    }

    private func loadZettaNCConfig(companyId: UUID) async {
        do {
            _ = try await ZettaSettingsService.ensureWarehousesForWorkLocations(companyId: companyId)
            let locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            var settings = try await ZettaSettingsService.fetchSettings(companyId: companyId)
            settings.payload.syncLocationAccounts(with: locations)
            zettaNCConfig = ZettaNCConfig(settings: settings.payload, workLocations: locations)
            syncPreviewRows()
        } catch {
            zettaNCConfig = nil
        }
    }

    func resetForCompanyChange() {
        reports = []
        previewRows = []
        zettaNCConfig = nil
        statusMessage = nil
        errorMessage = nil
        lastExportURL = nil
        savedExcelSessions = []
        showSavedExcelWarning = false
        savedExcelContinuePrompt = nil
        savedExcelWarningHandled = false
        #if os(iOS)
        showXlsxPicker = false
        pendingShare = nil
        pendingLocalSave = nil
        exportFlowContinuation?.resume()
        exportFlowContinuation = nil
        #endif
    }

    var scopedReports: [ZReportData] {
        guard let erpContext else { return reports }
        return reports.filter { erpContext.matches(report: $0) }
    }

    func reportMatchesERP(_ report: ZReportData) -> Bool {
        erpContext?.matches(report: report) ?? true
    }

    func beginLoadSavedExcel() {
        savedExcelWarningHandled = false
        showSavedExcelWarning = true
    }

    func dismissSavedExcelWarningAndPickFile() {
        guard !savedExcelWarningHandled else { return }
        savedExcelWarningHandled = true
        showSavedExcelWarning = false
        #if os(macOS) && !targetEnvironment(macCatalyst)
        pickSavedExcelOnMac()
        #else
        showXlsxPicker = true
        #endif
    }

    func dismissSavedExcelContinue() {
        savedExcelContinuePrompt = nil
    }

    func loadSavedExcel(from url: URL) {
        Task { @MainActor in
            isProcessing = true
            errorMessage = nil
            defer { isProcessing = false }

            do {
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

                let result = try ExcelImporter.importFile(from: url)
                let importedReports = ExcelImporter.enrichReportsFromFileName(
                    result.reports,
                    fileName: url.lastPathComponent
                )
                guard let firstReport = importedReports.first else {
                    throw ExcelImporter.ImportError.incompatibleFile
                }
                if let erpContext, !erpContext.matches(report: firstReport) {
                    errorMessage = erpContext.mismatchMessage(for: firstReport)
                    return
                }
                let session = SavedExcelSession(
                    firmGroupingKey: FirmaRegistry.groupingKey(for: firstReport),
                    displayName: FirmaRegistry.displayName(for: firstReport),
                    fileURL: url
                )
                if let idx = savedExcelSessions.firstIndex(where: { $0.firmGroupingKey == session.firmGroupingKey }) {
                    savedExcelSessions[idx] = session
                } else {
                    savedExcelSessions.append(session)
                }

                let merge = reports.mergingImportedReports(importedReports)
                reports.append(contentsOf: merge.accepted)
                reports = reports.sortedForExport()
                syncPreviewRows()

                var message = "Excel încărcat: \(url.lastPathComponent) — \(importedReports.count) Z (\(merge.accepted.count) noi, \(reports.count) total)."
                message += " Z-urile noi ale firmei „\(session.displayName)” se vor adăuga în acest fișier la export."
                if !merge.skipped.isEmpty {
                    message += " Ignorate \(merge.skipped.count) duplicate."
                }
                if savedExcelSessions.count > 1 {
                    message += " \(savedExcelSessions.count) fișiere Excel active (câte unul pe firmă)."
                }
                statusMessage = message

                let parsed = ExcelExporter.parseNCFileName(url.lastPathComponent)
                let firmName = parsed?.firmName ?? result.displayName
                let cui = parsed?.cui
                    ?? FirmaRegistry.normalizeCUI(result.reports.first?.cui ?? "")
                    ?? "—"
                savedExcelContinuePrompt = SavedExcelContinuePrompt(firmName: firmName, cui: cui)
            } catch let error as ExcelImporter.ImportError where error == .incompatibleFile {
                savedExcelContinuePrompt = nil
                statusMessage = nil
                errorMessage = error.localizedDescription
            } catch {
                savedExcelContinuePrompt = nil
                errorMessage = "Import Excel eșuat: \(error.localizedDescription)"
            }
        }
    }

    var exportGroups: [ExcelExporter.FirmExportGroup] {
        ExcelExporter.groupsByFirma(from: scopedReports, config: zettaNCConfig)
    }

    var allRows: [NotaContabilaRow] {
        previewRows
    }

    /// Binding sigur pe id (nu pe index) — evită crash la Șterge când array-ul se modifică.
    func binding(for id: UUID) -> Binding<ZReportData> {
        Binding(
            get: {
                self.reports.first(where: { $0.id == id }) ?? ZReportData()
            },
            set: { newValue in
                guard let idx = self.reports.firstIndex(where: { $0.id == id }) else { return }
                var copy = self.reports
                copy[idx] = newValue
                self.reports = copy
                self.schedulePreviewSync()
            }
        )
    }

    private var previewSyncTask: Task<Void, Never>?

    /// Regenerează previzualizarea NC după editări manuale (debounce ca să nu sacadeze la tastare).
    private func schedulePreviewSync() {
        zettaNCConfig = nil
        previewSyncTask?.cancel()
        previewSyncTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            syncPreviewRows()
        }
    }

    func reportImportReadFailure() {
        errorMessage = "Nu s-au putut citi fișierele. Formate acceptate: JPG, PNG, HEIC, PDF."
        statusMessage = nil
    }

    func importImages(_ images: [ImportedImage]) {
        Task { @MainActor in
            isProcessing = true
            errorMessage = nil
            statusMessage = "Citești \(images.count) fișier(e)…"
            defer { isProcessing = false }

            var created: [ZReportData] = []
            var rejectedByCompany = 0
            for (index, item) in images.enumerated() {
                statusMessage = "OCR \(index + 1)/\(images.count): \(item.fileName)"
                await Task.yield()
                do {
                    let segments: [String]
                    if let embedded = item.embeddedText, !embedded.isEmpty {
                        let normalized = BinaPosZReportTextNormalizer.normalizeIfNeeded(embedded)
                        segments = ZParser.splitOCRTextIntoReports(normalized)
                    } else {
                        guard let cgImage = OCRService.cgImageForOCR(from: item.image) else {
                            errorMessage = "\(item.fileName): Nu s-a putut citi imaginea."
                            continue
                        }
                        segments = try await OCRService.recognizeReports(from: cgImage)
                    }
                    if segments.isEmpty {
                        errorMessage = "\(item.fileName): Nu s-a putut citi textul."
                        continue
                    }
                    for (segIndex, text) in segments.enumerated() {
                        if ZParser.isAppScreenshot(text) {
                            errorMessage = ZParser.importQualityMessage(for: ZReportData(), ocrText: text)
                            continue
                        }
                        var parsed = ZParser.parse(ocrText: text)
                        if segments.count > 1 {
                            parsed.sourceFileName = "\(item.fileName) · Z \(segIndex + 1)/\(segments.count)"
                        } else {
                            parsed.sourceFileName = item.fileName
                        }
                        if let erpContext, !erpContext.matches(report: parsed) {
                            rejectedByCompany += 1
                            errorMessage = erpContext.mismatchMessage(for: parsed)
                            continue
                        }
                        created.append(parsed)
                        if let warning = ZParser.importQualityMessage(for: parsed, ocrText: text) {
                            errorMessage = "\(parsed.sourceFileName): \(warning)"
                        }
                    }
                } catch {
                    errorMessage = "Eroare OCR la \(item.fileName): \(error.localizedDescription)"
                }
            }

            let merge = reports.mergingImportedReports(created)
            let accepted = merge.accepted
            let skipped = merge.skipped

            reports.append(contentsOf: accepted)
            reports = reports.sortedForExport()
            syncPreviewRows()
            let groupCount = ExcelExporter.groupsByFirma(from: reports).count
            if accepted.isEmpty && !created.isEmpty && !skipped.isEmpty {
                statusMessage = "Ignorate \(skipped.count) duplicate (Z deja importat): \(Self.skippedZLabels(skipped))."
            } else if accepted.isEmpty {
                statusMessage = "Nu s-au putut extrage date."
            } else {
                var message = "Extrase \(accepted.count) Z (\(reports.count) total) — export \(groupCount) Excel (câte unul pe firmă)."
                if rejectedByCompany > 0 {
                    message += " " + L10n.tr("module.clients.zetta_rejected_count", rejectedByCompany)
                }
                if !skipped.isEmpty {
                    message += " Ignorate \(skipped.count) duplicate: \(Self.skippedZLabels(skipped))."
                }
                statusMessage = message
            }
        }
    }

    private static func skippedZLabels(_ reports: [ZReportData]) -> String {
        reports.map { report in
            if report.isNectarieFirma {
                return "Z\(report.zNumber) \(report.punctLucru.shortName)"
            }
            return "Z\(report.zNumber)"
        }.joined(separator: ", ")
    }

    func removeReport(_ report: ZReportData) {
        scheduleRemoveReport(id: report.id)
    }

    func removeReport(id: UUID) {
        reports.removeAll { $0.id == id }
        syncPreviewRows()
    }

    /// Amână ștergerea după închiderea tastaturii / frame-ul curent (fix crash iOS la TextField).
    func scheduleRemoveReport(id: UUID) {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
        let targetID = id
        Task { @MainActor in
            await Task.yield()
            removeReport(id: targetID)
        }
    }

    func clearAll() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
        Task { @MainActor in
            await Task.yield()
            reports.removeAll()
            previewRows = []
            statusMessage = nil
            errorMessage = nil
            lastExportURL = nil
            savedExcelSessions = []
            savedExcelContinuePrompt = nil
            #if os(iOS)
            pendingShare = nil
            pendingLocalSave = nil
            showXlsxPicker = false
            #endif
        }
    }

    private func syncPreviewRows() {
        previewRows = NotaContabilaGenerator.generate(from: scopedReports, config: zettaNCConfig)
    }

    func exportExcel() {
        let exportReports = scopedReports
        guard !exportReports.isEmpty else {
            if !reports.isEmpty, erpContext != nil {
                errorMessage = L10n.tr("module.clients.zetta_export_no_matching")
            } else {
                errorMessage = "Nu există rapoarte de exportat."
            }
            return
        }

        syncPreviewRows()
        let groups = ExcelExporter.groupsByFirma(
            from: exportReports,
            config: zettaNCConfig,
            namingStyle: exportNamingStyle,
            companyDisplayName: utilityCompanyDisplayName
        )

        #if os(macOS) && !targetEnvironment(macCatalyst)
        exportExcelMac(groups: groups)
        #elseif targetEnvironment(macCatalyst)
        exportExcelMacCatalyst(groups: groups)
        #else
        exportExcelIOS(groups: groups)
        #endif
    }

    /// Export NC + salvare Rapoarte Z în Situație clienți (context ERP Clienți).
    func exportExcelAndSave(onCompleted: (() -> Void)? = nil) {
        Task { await performExportExcelAndSave(onCompleted: onCompleted) }
    }

    private func performExportExcelAndSave(onCompleted: (() -> Void)?) async {
        guard isReadyForExportAndSave else { return }

        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        if erpContext?.isUtilityStandalone == false {
            do {
                let saved = try await persistScopedReportsToCloud()
                guard saved > 0 else {
                    errorMessage = L10n.tr("module.clients.zetta_save_reports_none")
                    return
                }
                statusMessage = L10n.tr("module.clients.zetta_saved_to_situation", saved)
            } catch {
                errorMessage = L10n.tr("module.clients.zetta_save_reports_failed", error.localizedDescription)
                return
            }
        }

        let exportSucceeded = await exportExcelAndWaitForUserAction()
        guard exportSucceeded else { return }

        clearAllAfterSuccessfulExportAndSave()
        onCompleted?()
    }

    private func clearAllAfterSuccessfulExportAndSave() {
        reports.removeAll()
        previewRows = []
        lastExportURL = nil
        savedExcelSessions = []
        savedExcelContinuePrompt = nil
        #if os(iOS)
        pendingShare = nil
        pendingLocalSave = nil
        showXlsxPicker = false
        #endif
    }

    func completePendingExportUserAction() {
        #if os(iOS)
        pendingShare = nil
        pendingLocalSave = nil
        exportFlowContinuation?.resume()
        exportFlowContinuation = nil
        #endif
    }

    @discardableResult
    private func persistScopedReportsToCloud() async throws -> Int {
        guard let companyId = erpContext?.companyId else { return 0 }
        let saved = try await ClientZReportService.upsertReports(companyId: companyId, reports: scopedReports)
        NotificationCenter.default.post(name: .clientZReportsDidChange, object: companyId)
        return saved
    }

    private func exportExcelAndWaitForUserAction() async -> Bool {
        let exportReports = scopedReports
        guard !exportReports.isEmpty else {
            if !reports.isEmpty, erpContext != nil {
                errorMessage = L10n.tr("module.clients.zetta_export_no_matching")
            } else {
                errorMessage = "Nu există rapoarte de exportat."
            }
            return false
        }

        syncPreviewRows()
        let groups = ExcelExporter.groupsByFirma(
            from: exportReports,
            config: zettaNCConfig,
            namingStyle: exportNamingStyle,
            companyDisplayName: utilityCompanyDisplayName
        )

        #if os(macOS) && !targetEnvironment(macCatalyst)
        exportExcelMac(groups: groups)
        return errorMessage == nil
        #elseif targetEnvironment(macCatalyst)
        return await exportExcelMacCatalystAndWait(groups: groups)
        #else
        return await exportExcelIOSAndWait(groups: groups)
        #endif
    }

    #if os(macOS) && !targetEnvironment(macCatalyst)
    private func pickSavedExcelOnMac() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let xlsx = UTType(filenameExtension: "xlsx") {
            panel.allowedContentTypes = [xlsx]
        }
        panel.message = "Selectează fișierul Excel salvat anterior (NC_…xlsx)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadSavedExcel(from: url)
    }

    private func exportExcelMac(groups: [ExcelExporter.FirmExportGroup]) {
        if groups.count == 1, let group = groups.first {
            let folder = savedExcelSessions
                .first(where: { $0.firmGroupingKey == group.id })?
                .fileURL
                .deletingLastPathComponent()
            exportGroupWithSavePanel(group, suggestedDirectory: folder)
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "\(groups.reduce(0) { $0 + $1.reports.count }) Z-uri → \(groups.count) Excel (câte unul pe firmă, pentru NextUp)."
        guard panel.runModal() == .OK, let directory = panel.url else { return }

        do {
            var saved: [String] = []
            for group in groups {
                let preferredName = group.fileName
                if savedExcelSessions.contains(where: { $0.firmGroupingKey == group.id }) {
                    let url = uniqueURL(in: directory, preferredName: preferredName)
                    try ExcelExporter.export(rows: group.rows, to: url)
                    updateSavedExcelSession(for: group, fileURL: url)
                    saved.append(url.lastPathComponent)
                    lastExportURL = url
                } else {
                    let url = uniqueURL(in: directory, preferredName: preferredName)
                    try ExcelExporter.export(rows: group.rows, to: url)
                    saved.append(url.lastPathComponent)
                }
            }
            lastExportURL = lastExportURL ?? directory
            statusMessage = "Salvate \(groups.count) Excel în \(directory.lastPathComponent): \(saved.joined(separator: ", "))"
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
        }
    }

    private func exportGroupWithSavePanel(
        _ group: ExcelExporter.FirmExportGroup,
        suggestedDirectory: URL? = nil
    ) {
        let panel = NSSavePanel()
        if let xlsx = UTType(filenameExtension: "xlsx") {
            panel.allowedContentTypes = [xlsx]
        }
        panel.nameFieldStringValue = group.fileName
        panel.directoryURL = suggestedDirectory
        panel.canCreateDirectories = true
        panel.message = "\(group.reports.count) Z → Excel (\(group.rows.count) rânduri). Nume actualizat cu perioada Z-urilor."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ExcelExporter.export(rows: group.rows, to: url)
            if savedExcelSessions.contains(where: { $0.firmGroupingKey == group.id }) {
                updateSavedExcelSession(for: group, fileURL: url)
            }
            lastExportURL = url
            statusMessage = "Salvat: \(url.lastPathComponent) — \(group.reports.count) Z, \(group.rows.count) rânduri."
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
        }
    }
    #endif

    #if os(iOS)
    private func exportExcelMacCatalystAndWait(groups: [ExcelExporter.FirmExportGroup]) async -> Bool {
        do {
            let urls = try writeExportFiles(groups: groups, directory: exportScratchDirectory())
            lastExportURL = urls.first
            pendingLocalSave = PendingLocalSave(urls: urls)
            statusMessage = exportStatusMessage(for: groups, directSave: true)
            await waitForPendingExportUserAction()
            return errorMessage == nil
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
            return false
        }
    }

    private func exportExcelIOSAndWait(groups: [ExcelExporter.FirmExportGroup]) async -> Bool {
        do {
            let urls = try writeExportFiles(groups: groups, directory: exportScratchDirectory())
            lastExportURL = urls.first
            pendingShare = PendingShare(urls: urls)
            statusMessage = exportStatusMessage(for: groups, directSave: false)
            await waitForPendingExportUserAction()
            return errorMessage == nil
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
            return false
        }
    }

    private func waitForPendingExportUserAction() async {
        await withCheckedContinuation { continuation in
            exportFlowContinuation = continuation
        }
    }

    private func exportExcelMacCatalyst(groups: [ExcelExporter.FirmExportGroup]) {
        do {
            let urls = try writeExportFiles(groups: groups, directory: exportScratchDirectory())
            lastExportURL = urls.first
            pendingLocalSave = PendingLocalSave(urls: urls)
            statusMessage = exportStatusMessage(for: groups, directSave: true)
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
        }
    }

    private func exportExcelIOS(groups: [ExcelExporter.FirmExportGroup]) {
        do {
            let urls = try writeExportFiles(groups: groups, directory: exportScratchDirectory())
            lastExportURL = urls.first
            pendingShare = PendingShare(urls: urls)
            statusMessage = exportStatusMessage(for: groups, directSave: false)
        } catch {
            errorMessage = "Export eșuat: \(error.localizedDescription)"
        }
    }

    private func exportScratchDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    private func writeExportFiles(
        groups: [ExcelExporter.FirmExportGroup],
        directory: URL
    ) throws -> [URL] {
        var urls: [URL] = []
        for group in groups {
            let preferredName = group.fileName
            let url = uniqueURL(in: directory, preferredName: preferredName)
            try ExcelExporter.export(rows: group.rows, to: url)
            if savedExcelSessions.contains(where: { $0.firmGroupingKey == group.id }) {
                updateSavedExcelSession(for: group, fileURL: url)
            }
            urls.append(url)
        }
        return urls
    }

    private func exportStatusMessage(for groups: [ExcelExporter.FirmExportGroup], directSave: Bool) -> String {
        if groups.count == 1, let only = groups.first {
            if directSave {
                return "Excel: \(only.fileName) — \(only.reports.count) Z, \(only.rows.count) rânduri. Alege locația de salvare."
            }
            return "Excel: \(only.fileName) — \(only.reports.count) Z, \(only.rows.count) rânduri. Alege WhatsApp, AirDrop, e-mail sau Fișiere."
        }
        let names = groups.map(\.displayName).joined(separator: ", ")
        if directSave {
            return "\(groups.count) Excel (câte unul pe firmă: \(names)). Alege folderul de salvare."
        }
        return "\(groups.count) Excel (câte unul pe firmă: \(names)). Alege WhatsApp, AirDrop, e-mail sau Fișiere."
    }
    #endif

    private func updateSavedExcelSession(for group: ExcelExporter.FirmExportGroup, fileURL: URL) {
        let session = SavedExcelSession(
            firmGroupingKey: group.id,
            displayName: group.displayName,
            fileURL: fileURL
        )
        if let idx = savedExcelSessions.firstIndex(where: { $0.firmGroupingKey == group.id }) {
            savedExcelSessions[idx] = session
        } else {
            savedExcelSessions.append(session)
        }
    }

    /// Evită suprascrierea dacă există deja un fișier cu același nume.
    private func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        var url = directory.appendingPathComponent(preferredName)
        guard fm.fileExists(atPath: url.path) else { return url }

        let base = (preferredName as NSString).deletingPathExtension
        let ext = (preferredName as NSString).pathExtension
        var index = 2
        repeat {
            let candidate = ext.isEmpty ? "\(base)_\(index)" : "\(base)_\(index).\(ext)"
            url = directory.appendingPathComponent(candidate)
            index += 1
        } while fm.fileExists(atPath: url.path)
        return url
    }
}

#if canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers
