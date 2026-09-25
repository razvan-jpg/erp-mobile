import SwiftUI
import UniformTypeIdentifiers

private struct HRPayrollNCPreviewItem: Identifiable {
    let id = UUID()
    let title: String
    let data: Data
}

struct HRPayrollNCImportView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @StateObject private var model = HRPayrollNCImportViewModel()
    @State private var journalPreview: HRPayrollNCPreviewItem?

    var body: some View {
        ZStack {
            AdaptiveCenteredContent(maxWidth: 760) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("utilities.payroll_nc.hint"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)

                    UtilityFileDropZoneView(
                        title: L10n.tr("utilities.payroll_nc.drop_title"),
                        subtitle: L10n.tr("utilities.payroll_nc.drop_subtitle"),
                        buttonTitle: L10n.tr("utilities.common.upload"),
                        contentTypes: [.pdf],
                        onImportURLs: { model.importFiles($0) }
                    )

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("utilities.zetta_import.first_nc_number"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            TextField(
                                L10n.tr("utilities.zetta_import.first_nc_number_placeholder"),
                                text: $model.firstNoteNumberText
                            )
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            Text(L10n.tr("utilities.payroll_nc.first_note_hint"))
                                .font(.caption2)
                                .foregroundColor(AppColors.secondary)
                        }
                        .frame(maxWidth: 260)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.tr("utilities.payroll_nc.style"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            Picker(L10n.tr("utilities.payroll_nc.style"), selection: $model.noteStyle) {
                                ForEach(HRPayrollNCNoteStyle.allCases) { style in
                                    Text(style.label).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            Text(L10n.tr("utilities.payroll_nc.style_hint"))
                                .font(.caption2)
                                .foregroundColor(AppColors.secondary)
                        }
                    }

                    if !model.importedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.payroll_nc.loaded_files"))
                                .font(.headline)
                            ForEach(model.importedFiles) { file in
                                Text("• \(file.name)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }

                            HStack(spacing: 12) {
                                Button(L10n.tr("utilities.payroll_nc.generate")) {
                                    Task { await model.generate(companyName: companyManager.currentCompany?.denumire) }
                                }
                                .buttonStyle(AppButtonStyles.borderedProminent)
                                .disabled(model.isProcessing)

                                Button(L10n.tr("utilities.common.clear")) {
                                    model.clearAll()
                                }
                                .buttonStyle(AppButtonStyles.bordered)
                            }
                        }
                    }

                    if !model.exportEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.payroll_nc.rows_count", model.exportEntries.count))
                                .font(.headline)
                            if !model.detectedCompany.isEmpty {
                                Text(L10n.tr("utilities.payroll_nc.detected_company", model.detectedCompany))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            ForEach(model.exportEntries.prefix(8)) { entry in
                                Text("• \(entry.account) \(entry.debitCredit) \(SupplierFormatting.currency(entry.amount)) \(entry.employeeCode)")
                                    .font(.caption)
                            }
                            if model.exportEntries.count > 8 {
                                Text(L10n.tr("utilities.payroll_nc.more_rows", model.exportEntries.count - 8))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }

                            HStack(spacing: 12) {
                                Button(L10n.tr("utilities.payroll_nc.preview")) {
                                    openJournalPreview()
                                }
                                .buttonStyle(AppButtonStyles.bordered)

                                Button(L10n.tr("utilities.payroll_nc.export_save")) {
                                    model.exportExcel(companyName: companyManager.currentCompany?.denumire ?? model.detectedCompany)
                                }
                                .buttonStyle(AppButtonStyles.borderedProminent)
                            }
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
            .navigationTitle(L10n.tr("utilities.payroll_nc.title"))
            .navigationBarTitleDisplayMode(.inline)
            .appFullOverlay { LoadingOverlay(isLoading: model.isProcessing) }
            .sheet(item: $journalPreview) { item in
                PDFDocumentPreviewSheet(
                    title: item.title,
                    pdfData: item.data,
                    onClose: { journalPreview = nil }
                )
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

    private func openJournalPreview() {
        guard let data = model.previewPDF(company: companyManager.currentCompany) else { return }
        journalPreview = HRPayrollNCPreviewItem(
            title: L10n.tr("utilities.payroll_nc.preview_title"),
            data: data
        )
    }
}
