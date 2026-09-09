import SwiftUI

struct ZettaScanImportView: View {
    @StateObject private var model = ZettaScanImportViewModel()

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
                                Text("• \(report.firma) · Z \(report.zNumber) · \(SupplierFormatting.date(report.date)) · \(CashRegisterJournalFormatting.amount(report.totalVanzari))")
                                    .font(.caption)
                            }
                        }
                    }

                    if model.hasGeneratedFiles {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.tr("utilities.zetta_scan.save_options"))
                                .font(.headline)

                            if let combined = model.generatedCombinedPDFURL {
                                Text("• \(combined.lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            ForEach(model.generatedPDFURLs, id: \.self) { url in
                                Text("• \(url.lastPathComponent)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            ForEach(model.generatedExcelURLs, id: \.self) { url in
                                Text("• \(url.lastPathComponent)")
                                    .font(.caption)
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
}
