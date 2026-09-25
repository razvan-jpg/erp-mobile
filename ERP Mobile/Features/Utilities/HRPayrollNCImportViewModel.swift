import Combine
import Foundation
import SwiftUI

#if os(iOS) || targetEnvironment(macCatalyst)
struct HRPayrollNCPendingExport: Identifiable {
    let id = UUID()
    let urls: [URL]
}
#endif

@MainActor
final class HRPayrollNCImportViewModel: ObservableObject {
    @Published var importedFiles: [ImportedPDF] = []
    @Published var entries: [HRJournalEntry] = []
    @Published var firstNoteNumberText = "1"
    @Published var noteStyle: HRPayrollNCNoteStyle = .simple
    @Published var isProcessing = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var detectedCompany = ""
    #if os(iOS) || targetEnvironment(macCatalyst)
    @Published var pendingExport: HRPayrollNCPendingExport?
    #endif

    var exportEntries: [HRJournalEntry] {
        HRPayrollNCUniqueAccountCollector.exportEntries(entries, style: noteStyle)
    }

    struct ImportedPDF: Identifiable {
        let id = UUID()
        let name: String
        let data: Data
    }

    func importFiles(_ urls: [URL]) {
        errorMessage = nil
        statusMessage = nil
        var loaded = 0
        for url in urls {
            do {
                let data = try UtilityFilePickerSupport.readData(from: url)
                guard !data.isEmpty else { continue }
                importedFiles.append(ImportedPDF(name: url.lastPathComponent, data: data))
                loaded += 1
            } catch {
                errorMessage = L10n.tr("utilities.payroll_nc.error_read_file", url.lastPathComponent, error.localizedDescription)
            }
        }
        if loaded > 0 {
            statusMessage = L10n.tr("utilities.payroll_nc.files_loaded", importedFiles.count)
        } else if errorMessage == nil {
            errorMessage = L10n.tr("utilities.payroll_nc.error_no_files")
        }
    }

    func clearAll() {
        importedFiles = []
        entries = []
        detectedCompany = ""
        statusMessage = nil
        errorMessage = nil
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = nil
        #endif
    }

    func generate(companyName: String?) async {
        guard !importedFiles.isEmpty else {
            errorMessage = L10n.tr("utilities.payroll_nc.error_no_files")
            return
        }
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        let startingNote = max(Int(firstNoteNumberText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1, 1)
        var collected: [HRJournalEntry] = []
        var company = companyName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        do {
            for file in importedFiles {
                let parsed = try HRJournalNotePDFParser.parse(
                    pdfData: file.data,
                    defaultNoteNumber: startingNote
                )
                collected.append(contentsOf: parsed.entries)
                if company.isEmpty, let detected = parsed.companyName, !detected.isEmpty {
                    company = detected
                }
            }
            let remapped = HRJournalNotePDFParser.remapped(collected, startingAt: startingNote)
            guard !remapped.isEmpty else {
                errorMessage = L10n.tr("utilities.payroll_nc.error_no_entries")
                return
            }
            entries = remapped
            detectedCompany = company
            statusMessage = L10n.tr(
                "utilities.payroll_nc.generated",
                HRPayrollNCUniqueAccountCollector.exportEntries(remapped, style: noteStyle).count
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previewPDF(company: Company?) -> Data? {
        let rows = exportEntries
        guard !rows.isEmpty else {
            errorMessage = L10n.tr("utilities.payroll_nc.error_generate_first")
            return nil
        }
        let date = rows[0].dateYYYYMMDD
        let period = HRMonthPeriod(year: date / 10_000, month: max((date / 100) % 100, 1))
        do {
            return try HRPayrollPDFBuilder.journal(company: company, period: period, entries: rows)
        } catch {
            errorMessage = L10n.tr("utilities.payroll_nc.error_preview")
            return nil
        }
    }

    func exportExcel(companyName: String?) {
        let rows = exportEntries
        guard !rows.isEmpty else {
            errorMessage = L10n.tr("utilities.payroll_nc.error_generate_first")
            return
        }
        do {
            let firm = sanitizedFileName(companyName ?? detectedCompany)
            let date = rows.first.map { "\($0.dateYYYYMMDD)" } ?? ""
            let name = "Salarii_\(firm)_\(date).xlsx"
            let url = try HRPayrollNextUpExporter.writeTemporary(entries: rows, fileName: name)
            #if os(iOS) || targetEnvironment(macCatalyst)
            pendingExport = HRPayrollNCPendingExport(urls: [url])
            #else
            statusMessage = L10n.tr("utilities.payroll_nc.saved", url.lastPathComponent)
            #endif
        } catch {
            errorMessage = L10n.tr("utilities.payroll_nc.error_export", error.localizedDescription)
        }
    }

    func completePendingExport() {
        #if os(iOS) || targetEnvironment(macCatalyst)
        pendingExport = nil
        #endif
        statusMessage = L10n.tr("utilities.payroll_nc.saved_ok")
    }

    private func sanitizedFileName(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:.\n\t")
        let cleaned = raw.components(separatedBy: invalid).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return cleaned.isEmpty ? "Firma" : cleaned
    }
}
