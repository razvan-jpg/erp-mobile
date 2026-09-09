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

        var created: [ZReportData] = []
        for (index, item) in pendingImages.enumerated() {
            statusMessage = L10n.tr("utilities.zetta_scan.reading_file", index + 1, pendingImages.count, item.fileName)
            await Task.yield()
            do {
                let parsed = try await reports(from: item)
                if parsed.isEmpty {
                    errorMessage = L10n.tr("utilities.zetta_scan.error_no_text", item.fileName)
                    continue
                }
                created.append(contentsOf: parsed)
            } catch {
                errorMessage = L10n.tr("utilities.zetta_scan.error_ocr", item.fileName, error.localizedDescription)
            }
        }

        reports = created.sortedForExport()
        guard !reports.isEmpty else {
            if errorMessage == nil {
                errorMessage = L10n.tr("utilities.zetta_scan.error_no_z")
            }
            return
        }

        do {
            try writeGeneratedFiles()
            statusMessage = L10n.tr("utilities.zetta_scan.generated_choose", reports.count)
        } catch {
            errorMessage = L10n.tr("utilities.zetta_scan.error_export", error.localizedDescription)
        }
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

        let groups = ExcelExporter.groupsByFirma(
            from: reports,
            config: nil,
            namingStyle: .zettaUtility,
            companyDisplayName: nil,
            startingNrInreg: firstNCNumber
        )
        var excelURLs: [URL] = []
        for group in groups {
            let url = directory.appendingPathComponent(group.fileName)
            try ExcelExporter.export(rows: group.rows, to: url)
            excelURLs.append(url)
        }

        var usedPDFNames: Set<String> = []
        var pdfURLs: [URL] = []
        var pdfDatas: [Data] = []
        for report in reports {
            let text = ZettaModelZReportFormatter.rebuiltModelText(
                for: report,
                companyName: nil,
                addressLine: nil
            )
            let data = CashRegisterZReportPDFBuilder.makeA4PDF(text: text)
            let name = ZettaScanReportBinder.individualPDFFileName(for: report, usedNames: &usedPDFNames)
            let url = directory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            pdfURLs.append(url)
            pdfDatas.append(data)
        }

        let combinedURL = directory.appendingPathComponent(
            "\(ZettaScanReportBinder.exportBaseName(for: reports)).pdf"
        )
        let combinedData = CashRegisterZReportPDFBuilder.makeCombinedPDF(fromOriginalPDFs: pdfDatas)
        try combinedData.write(to: combinedURL, options: .atomic)

        generatedExcelURLs = excelURLs
        generatedPDFURLs = pdfURLs
        generatedCombinedPDFURL = combinedURL
    }

    private func reports(from item: ImportedImage) async throws -> [ZReportData] {
        if let embedded = item.embeddedText, !embedded.isEmpty {
            let fromText = parseSegments(
                ZParser.splitOCRTextIntoReports(BinaPosZReportTextNormalizer.normalizeIfNeeded(embedded)),
                fileName: item.fileName
            )
            if !fromText.isEmpty {
                return fromText
            }
        }
        guard let cgImage = OCRService.cgImageForOCR(from: item.image) else {
            return []
        }
        let ocrSegments = try await OCRService.recognizeReports(from: cgImage)
        return parseSegments(ocrSegments, fileName: item.fileName)
    }

    private func parseSegments(_ segments: [String], fileName: String) -> [ZReportData] {
        var created: [ZReportData] = []
        for (segIndex, text) in segments.enumerated() {
            if ZParser.isAppScreenshot(text) { continue }
            var parsed = ZParser.parse(ocrText: text)
            guard Self.isUsableReport(parsed) else { continue }
            parsed.parseSource = ZParser.isDigitalPOSZReport(text) ? .digitalPDF : parsed.parseSource
            if segments.count > 1 {
                parsed.sourceFileName = "\(fileName) · Z \(segIndex + 1)/\(segments.count)"
            } else {
                parsed.sourceFileName = fileName
            }
            created.append(parsed)
        }
        return created
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

    private static func isUsableReport(_ report: ZReportData) -> Bool {
        report.zNumber > 0
            || report.totalVanzari > 0
            || report.numerar > 0
            || report.card > 0
    }
}
