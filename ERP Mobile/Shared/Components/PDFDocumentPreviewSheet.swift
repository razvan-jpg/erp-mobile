import PDFKit
import SwiftUI

struct PDFDocumentPreviewSheet: View {
    let title: String
    let pdfData: Data
    let onClose: () -> Void

    @State private var showPrintSheet = false
    @State private var showShareSheet = false
    @State private var temporaryURL: URL?
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationView {
            PDFKitDocumentView(data: pdfData)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.tr("module.clients.z_reports.preview_close")) {
                            onClose()
                        }
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            printPDF()
                        } label: {
                            Label(L10n.tr("account.print"), systemImage: "printer")
                        }
                        Button {
                            savePDF()
                        } label: {
                            Label(L10n.tr("nir.export_save_pdf"), systemImage: "square.and.arrow.down")
                        }
                        Button {
                            sharePDF()
                        } label: {
                            Label(L10n.tr("account.send"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            prepareTemporaryFile()
        }
        .sheet(isPresented: $showPrintSheet) {
            PrintDocumentView(
                pdfData: pdfData,
                jobName: title,
                onFinish: { showPrintSheet = false }
            )
        }
#if !targetEnvironment(macCatalyst)
        .sheet(isPresented: $showShareSheet, onDismiss: { showShareSheet = false }) {
            ActivityShareSheet(
                items: [temporaryURL].compactMap { $0 },
                excludedActivityTypes: nil,
                onFinish: { showShareSheet = false }
            )
        }
#endif
        .alert(L10n.tr("common.error"), isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    private func prepareTemporaryFile() {
        guard temporaryURL == nil else { return }
        temporaryURL = writeTemporaryPDF(data: pdfData, preferredFileName: title)
    }

    private func writeTemporaryPDF(data: Data, preferredFileName: String) -> URL? {
        let trimmed = preferredFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName: String
        if trimmed.lowercased().hasSuffix(".pdf") {
            baseName = String(trimmed.dropLast(4))
        } else if trimmed.isEmpty {
            baseName = "Document"
        } else {
            baseName = trimmed
        }
        let safeName = baseName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-\(UUID().uuidString.prefix(8)).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func printPDF() {
        showPrintSheet = true
    }

    private func savePDF() {
        prepareTemporaryFile()
        guard let url = temporaryURL else {
            exportErrorMessage = L10n.tr("module.cash_register.preview_failed")
            return
        }
#if targetEnvironment(macCatalyst)
        let suggested = title.lowercased().hasSuffix(".pdf") ? title : "\(title).pdf"
        _ = DocumentExportSupport.saveOnMac(from: url, suggestedName: suggested)
#else
        showShareSheet = true
#endif
    }

    private func sharePDF() {
        prepareTemporaryFile()
        guard let url = temporaryURL else {
            exportErrorMessage = L10n.tr("module.cash_register.preview_failed")
            return
        }
#if targetEnvironment(macCatalyst)
        DocumentExportSupport.shareOnMac(url: url)
#else
        showShareSheet = true
#endif
    }
}

private struct PDFKitDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        pdfView.document = PDFDocument(data: data)
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.document = PDFDocument(data: data)
    }
}
