import SwiftUI

private struct ZettaScanPDFPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

private struct ZettaScanExcelPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let rows: [NotaContabilaRow]
}

struct ZettaScanImportView: View {
    @StateObject private var model = ZettaScanImportViewModel()
    @State private var pdfPreview: ZettaScanPDFPreviewItem?
    @State private var excelPreview: ZettaScanExcelPreviewItem?

    var body: some View {
        ZStack {
            AdaptiveCenteredContent(maxWidth: 760) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("utilities.zetta_scan.hint"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)

                    UtilityFileDropZoneView(
                        title: L10n.tr("utilities.zetta_scan.drop_title"),
                        subtitle: L10n.tr("utilities.zetta_scan.drop_subtitle"),
                        buttonTitle: L10n.tr("utilities.common.upload"),
                        contentTypes: UtilityFilePickerSupport.zReportScanTypes,
                        dropTypes: UtilityFilePickerSupport.zReportScanDropTypes,
                        onImportURLs: { model.importFiles($0) }
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("utilities.zetta_import.first_nc_number"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        TextField(
                            L10n.tr("utilities.zetta_import.first_nc_number_placeholder"),
                            text: $model.firstNCNumberText
                        )
                        .textFieldStyle(.roundedBorder)
                        Text(L10n.tr("utilities.zetta_import.first_nc_number_hint"))
                            .font(.caption2)
                            .foregroundColor(AppColors.secondary)
                    }

                    if !model.importedFileNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.zetta_scan.loaded_files"))
                                .font(.headline)
                            ForEach(Array(model.importedFileNames.enumerated()), id: \.offset) { _, name in
                                Text("• \(name)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(L10n.tr("utilities.zetta_scan.generate")) {
                                Task { await model.generateImportFile() }
                            }
                            .buttonStyle(AppButtonStyles.borderedProminent)
                            .disabled(model.isProcessing)

                            Button(L10n.tr("utilities.common.clear")) {
                                model.clearAll()
                            }
                            .buttonStyle(AppButtonStyles.bordered)
                        }
                    }

                    if !model.reports.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.zetta_scan.reports_count", model.reports.count))
                                .font(.headline)
                            ForEach(model.reports) { report in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(reportListLine(report))
                                        .font(.caption)
                                    Spacer(minLength: 8)
                                    if ZettaScanPageReader.isWeak(report), model.canReread(report) {
                                        Button(L10n.tr("utilities.zetta_scan.reread")) {
                                            Task { await model.reread(report) }
                                        }
                                        .buttonStyle(.borderless)
                                        .font(.caption)
                                        .disabled(model.isProcessing)
                                    }
                                }
                            }
                        }
                    }

                    if model.hasGeneratedFiles {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("utilities.zetta_scan.save_options"))
                                .font(.headline)

                            if let combined = model.generatedCombinedPDFURL {
                                generatedFileRow(title: combined.lastPathComponent) {
                                    openPDFPreview(url: combined)
                                }
                            }
                            ForEach(model.generatedPDFURLs, id: \.self) { url in
                                generatedFileRow(title: url.lastPathComponent) {
                                    openPDFPreview(url: url)
                                }
                            }
                            ForEach(model.generatedExcelURLs, id: \.self) { url in
                                generatedFileRow(title: url.lastPathComponent) {
                                    openExcelPreview(title: url.lastPathComponent)
                                }
                            }

                            Button(L10n.tr("utilities.zetta_scan.save_combined_pdf")) {
                                model.export(.combinedPDF)
                            }
                            .buttonStyle(AppButtonStyles.borderedProminent)
                            .disabled(model.generatedCombinedPDFURL == nil)

                            Button(L10n.tr("utilities.zetta_scan.save_individual_pdfs")) {
                                model.export(.individualPDFs)
                            }
                            .buttonStyle(AppButtonStyles.bordered)
                            .disabled(model.generatedPDFURLs.isEmpty)

                            Button(L10n.tr("utilities.zetta_scan.save_excel")) {
                                model.export(.excel)
                            }
                            .buttonStyle(AppButtonStyles.borderedProminent)
                            .disabled(model.generatedExcelURLs.isEmpty)
                        }
                    }

                    if let status = model.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    if let error = model.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .appScrollBottomPadding()
            .navigationTitle(L10n.tr("utilities.zetta_scan.title"))
            .navigationBarTitleDisplayMode(.inline)
            .appFullOverlay { LoadingOverlay(isLoading: model.isProcessing) }
            .sheet(item: $pdfPreview) { item in
                PDFDocumentPreviewSheet(
                    title: item.title,
                    pdfData: item.data,
                    onClose: { pdfPreview = nil }
                )
            }
            .sheet(item: $excelPreview) { item in
                NavigationView {
                    ScrollView {
                        RowsPreview(rows: item.rows)
                            .padding()
                    }
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.tr("module.clients.z_reports.preview_close")) {
                                excelPreview = nil
                            }
                        }
                    }
                }
                .navigationViewStyle(.stack)
            }
            #if os(iOS) || targetEnvironment(macCatalyst)
            .sheet(item: $model.pendingExport) { item in
                #if targetEnvironment(macCatalyst)
                LocalSaveDocumentPicker(sourceURLs: item.urls) {
                    model.completePendingExport()
                }
                .ignoresSafeArea()
                #else
                ActivityShareSheet(items: item.urls, excludedActivityTypes: nil) {
                    model.completePendingExport()
                }
                #endif
            }
            #endif
        }
    }

    private func generatedFileRow(title: String, preview: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("• \(title)")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Spacer(minLength: 8)
            Button(L10n.tr("utilities.zetta_scan.preview")) {
                preview()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private func openPDFPreview(url: URL) {
        guard let data = model.pdfData(from: url) else {
            model.errorMessage = L10n.tr("utilities.zetta_scan.error_preview")
            return
        }
        pdfPreview = ZettaScanPDFPreviewItem(title: url.lastPathComponent, data: data)
    }

    private func openExcelPreview(title: String) {
        guard !model.generatedExcelRows.isEmpty else {
            model.errorMessage = L10n.tr("utilities.zetta_scan.error_preview")
            return
        }
        excelPreview = ZettaScanExcelPreviewItem(title: title, rows: model.generatedExcelRows)
    }

    private func reportListLine(_ report: ZReportData) -> String {
        let zPart = report.zNumber > 0
            ? "Z \(report.zNumber)"
            : L10n.tr("utilities.zetta_scan.unread_mark")
        return "• \(report.firma) · \(zPart) · \(SupplierFormatting.date(report.date)) · \(CashRegisterJournalFormatting.amount(report.totalVanzari))"
    }
}
