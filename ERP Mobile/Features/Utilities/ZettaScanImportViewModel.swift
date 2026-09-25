import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if os(iOS) || targetEnvironment(macCatalyst)
struct ZettaScanPendingExport: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif

enum ZettaScanExportKind {
    case combinedPDF
    case individualPDFs
    case excel
}

@MainActor
final class ZettaScanImportViewModel: ObservableObject {
    @Published var importedFileNames: [String] = []
    @Published var reports: [ZReportData] = []
    @Published var generatedExcelURLs: [URL] = []
    @Published var generatedPDFURLs: [URL] = []
    @Published var generatedCombinedPDFURL: URL?
    @Published var generatedExcelRows: [NotaContabilaRow] = []
    @Published var firstNCNumberText = "1"
    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    #if os(iOS) || targetEnvironment(macCatalyst)
    @Published var pendingExport: ZettaScanPendingExport?
    #endif

    private var pendingImages: [ImportedImage] = []

    var hasLoadedScans: Bool {
        !pendingImages.isEmpty
    }

    var hasGeneratedFiles: Bool {
        !generatedExcelURLs.isEmpty || !generatedPDFURLs.isEmpty || generatedCombinedPDFURL != nil
    }

    func importFiles(_ urls: [URL]) {
        errorMessage = nil
        statusMessage = nil
        var loaded: [ImportedImage] = []
        for url in urls {
            let images = ImageLoader.loadAll(from: url)
            loaded.append(contentsOf: images)
        }
        guard !loaded.isEmpty else {
            errorMessage = L10n.tr("utilities.zetta_scan.error_no_files")
            return
        }
        pendingImages.append(contentsOf: loaded)
        importedFileNames = pendingImages.map(\.fileName)
        generatedExcelURLs = []
        generatedPDFURLs = []
        generatedCombinedPDFURL = nil
        generatedExcelRows = []
        reports = []
        statusMessage = L10n.tr("utilities.zetta_scan.files_loaded", pendingImages.count)
    }

    func clearAll() {
        pendingImages = []
        importedFileNames = []
        reports = []
        generatedExcelURLs = []
        generatedPDFURLs = []
        generatedCombinedPDFURL = nil
        generatedExcelRows = []
        statusMessage = nil
        errorMessage = nil
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = nil
        #endif
    }

    func generateImportFile() async {
        guard !pendingImages.isEmpty else {
            errorMessage = L10n.tr("utilities.zetta_scan.error_no_files")
            return
        }

        isProcessing = true
        errorMessage = nil
        statusMessage = L10n.tr("utilities.zetta_scan.reading")
        defer { isProcessing = false }

        _ = try? await UtilityTemplateService.fetchTemplate(.zReportModel)

        var created: [ZReportData] = []
        var unreadNames: [String] = []
        for (index, item) in pendingImages.enumerated() {
            statusMessage = L10n.tr("utilities.zetta_scan.reading_file", index + 1, pendingImages.count, item.fileName)
            await Task.yield()
            do {
                let parsed = try await readOnePage(item)
                created.append(parsed)
                if ZettaScanPageReader.isWeak(parsed) {
                    unreadNames.append(item.fileName)
                }
            } catch {
                created.append(ZettaScanPageReader.stubPage(fileName: item.fileName))
                unreadNames.append(item.fileName)
                errorMessage = L10n.tr("utilities.zetta_scan.error_ocr", item.fileName, error.localizedDescription)
            }
        }

        reports = ZettaScanPageReader.unifyFirm(created)
        do {
            try writeGeneratedFiles()
            let readCount = reports.filter { $0.zNumber > 0 }.count
            if readCount == 0 {
                statusMessage = L10n.tr("utilities.zetta_scan.generated_pdf_only", pendingImages.count)
            } else if unreadNames.isEmpty {
                statusMessage = L10n.tr("utilities.zetta_scan.generated_choose", reports.count)
            } else {
                statusMessage = L10n.tr(
                    "utilities.zetta_scan.generated_with_unread",
                    readCount,
                    unreadNames.count,
                    unreadNames.joined(separator: ", ")
                )
            }
        } catch {
            errorMessage = L10n.tr("utilities.zetta_scan.error_export", error.localizedDescription)
        }
    }

    func canReread(_ report: ZReportData) -> Bool {
        pendingImages.contains { $0.fileName == report.sourceFileName }
    }

    func reread(_ report: ZReportData) async {
        guard let item = pendingImages.first(where: { $0.fileName == report.sourceFileName }) else {
            errorMessage = L10n.tr("utilities.zetta_scan.error_reread_missing")
            return
        }

        isProcessing = true
        errorMessage = nil
        statusMessage = L10n.tr("utilities.zetta_scan.rereading", item.fileName)
        defer { isProcessing = false }

        do {
            let parsed = try await readOnePage(item, forceOCR: true)
            var updated = reports
            if let index = updated.firstIndex(where: { $0.id == report.id }) {
                updated[index] = parsed
            } else {
                updated.append(parsed)
            }
            reports = ZettaScanPageReader.unifyFirm(updated)
            try writeGeneratedFiles()
            if ZettaScanPageReader.isWeak(parsed) {
                statusMessage = L10n.tr("utilities.zetta_scan.reread_still_unread", item.fileName)
            } else {
                statusMessage = L10n.tr("utilities.zetta_scan.reread_ok", item.fileName)
            }
        } catch {
            errorMessage = L10n.tr("utilities.zetta_scan.error_ocr", item.fileName, error.localizedDescription)
        }
    }

    func pdfData(from url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    func export(_ kind: ZettaScanExportKind) {
        let urls: [URL]
        switch kind {
        case .combinedPDF:
            urls = generatedCombinedPDFURL.map { [$0] } ?? []
        case .individualPDFs:
            urls = generatedPDFURLs
        case .excel:
            urls = generatedExcelURLs
        }
        guard !urls.isEmpty else {
            errorMessage = L10n.tr("utilities.zetta_scan.error_nothing_to_save")
            return
        }
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = ZettaScanPendingExport(urls: urls)
        #elseif os(macOS)
        saveWithAppKit(urls: urls)
        #endif
    }

    func completePendingExport() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = nil
        #endif
    }

    private var firstNCNumber: Int {
        let digits = firstNCNumberText.filter(\.isNumber)
        return max(Int(digits) ?? 1, 1)
    }

    private func writeGeneratedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zetta-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var originalPDFs: [Data] = []
        var pdfURLs: [URL] = []
        var usedPDFNames: Set<String> = []
        for item in pendingImages {
            let pagePDF: Data
            if let original = item.originalPagePDF, original.starts(with: [0x25, 0x50, 0x44, 0x46]) {
                pagePDF = original
            } else {
                pagePDF = ImageLoader.pdfDataWrappingImage(item.image)
            }
            originalPDFs.append(pagePDF)
            let report = reports.first(where: { $0.sourceFileName == item.fileName })
                ?? ZettaScanPageReader.stubPage(fileName: item.fileName)
            let name = ZettaScanReportBinder.individualPDFFileName(for: report, usedNames: &usedPDFNames)
            let url = directory.appendingPathComponent(name)
            try pagePDF.write(to: url, options: .atomic)
            pdfURLs.append(url)
        }

        let nameSource = reports.contains(where: { $0.zNumber > 0 })
            ? reports.filter { $0.zNumber > 0 }
            : reports
        let combinedURL = directory.appendingPathComponent(
            "\(ZettaScanReportBinder.exportBaseName(for: nameSource)).pdf"
        )
        let combinedData = CashRegisterZReportPDFBuilder.makeCombinedPDF(fromOriginalPDFs: originalPDFs)
        try combinedData.write(to: combinedURL, options: .atomic)

        let readable = reports.filter { $0.zNumber > 0 }.sortedForExport()
        var excelURLs: [URL] = []
        var excelRows: [NotaContabilaRow] = []
        if !readable.isEmpty {
            let firmName = FirmaRegistry.displayName(for: readable[0])
            excelRows = NotaContabilaGenerator.generate(
                from: readable,
                config: nil,
                startingNrInreg: firstNCNumber
            )
            let excelName = ExcelExporter.suggestedFileName(
                for: readable,
                style: .zettaUtility,
                companyDisplayName: firmName
            )
            let excelURL = directory.appendingPathComponent(excelName)
            try ExcelExporter.export(rows: excelRows, to: excelURL)
            excelURLs = [excelURL]
        }

        generatedExcelURLs = excelURLs
        generatedPDFURLs = pdfURLs
        generatedCombinedPDFURL = combinedURL
        generatedExcelRows = excelRows
    }

    /// O pagină / o poză = un Z. OCR pe toată pagina. Stratul de text al scannerului se ignoră dacă nu e PDF digital POS complet.
    private func readOnePage(_ item: ImportedImage, forceOCR: Bool = false) async throws -> ZReportData {
        let embeddedText = item.embeddedText.flatMap { text -> String? in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : BinaPosZReportTextNormalizer.normalizeIfNeeded(trimmed)
        }
        let embeddedParsed = embeddedText.map { ZettaScanPageReader.parsePage(text: $0, fileName: item.fileName) }

        if !forceOCR,
           let embeddedText, let embeddedParsed,
           ZettaScanPageReader.isTrustedDigitalEmbedded(embeddedText, parsed: embeddedParsed) {
            return embeddedParsed
        }

        guard let cgImage = ocrImage(for: item) else {
            return ZettaScanPageReader.stubPage(fileName: item.fileName)
        }
        let ocrText = try await OCRService.recognizeScanZPage(from: cgImage)
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ZettaScanPageReader.stubPage(fileName: item.fileName)
        }
        return ZettaScanPageReader.parsePage(text: ocrText, fileName: item.fileName)
    }

    private func ocrImage(for item: ImportedImage) -> CGImage? {
        if let pdf = item.originalPagePDF,
           let fromPDF = ImageLoader.cgImageForOCR(fromPDFPage: pdf, longestEdge: 4000) {
            return fromPDF
        }
        return OCRService.cgImageForOCR(from: item.image)
    }

    #if os(macOS) && !targetEnvironment(macCatalyst)
    private func saveWithAppKit(urls: [URL]) {
        do {
            if urls.count == 1, let url = urls.first {
                let panel = NSSavePanel()
                panel.canCreateDirectories = true
                panel.nameFieldStringValue = url.lastPathComponent
                panel.prompt = L10n.tr("utilities.zetta_scan.save_choose")
                guard panel.runModal() == .OK, let destination = panel.url else { return }
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: url, to: destination)
                statusMessage = L10n.tr("utilities.zetta_scan.saved_file", destination.lastPathComponent)
            } else {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.prompt = L10n.tr("utilities.zetta_scan.save_choose")
                guard panel.runModal() == .OK, let directory = panel.url else { return }
                for url in urls {
                    let destination = directory.appendingPathComponent(url.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: url, to: destination)
                }
                statusMessage = L10n.tr("utilities.zetta_scan.saved_folder", directory.lastPathComponent)
            }
        } catch {
            errorMessage = L10n.tr("utilities.zetta_scan.error_export", error.localizedDescription)
        }
    }
    #endif

}
