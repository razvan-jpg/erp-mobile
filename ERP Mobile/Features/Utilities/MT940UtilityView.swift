import SwiftUI

struct MT940UtilityView: View {
    @StateObject private var model = MT940UtilityViewModel()

    var body: some View {
        ZStack {
            AdaptiveCenteredContent(maxWidth: 760) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("utilities.mt940.hint"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)

                    UtilityFileDropZoneView(
                        title: L10n.tr("utilities.mt940.drop_title"),
                        subtitle: L10n.tr("utilities.mt940.drop_subtitle"),
                        buttonTitle: L10n.tr("utilities.common.upload"),
                        contentTypes: UtilityFilePickerSupport.bankStatementTypes,
                        onImportURLs: { model.importFiles($0) }
                    )

                    if !model.importedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.mt940.loaded_files"))
                                .font(.headline)
                            ForEach(model.importedFiles) { file in
                                Text("• \(file.name)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(L10n.tr("utilities.mt940.generate")) {
                                Task { await model.generateDailyFiles() }
                            }
                            .buttonStyle(AppButtonStyles.borderedProminent)
                            .disabled(model.isProcessing)

                            Button(L10n.tr("utilities.common.clear")) {
                                model.clearAll()
                            }
                            .buttonStyle(AppButtonStyles.bordered)
                        }
                    }

                    if !model.dailyFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tr("utilities.mt940.daily_files", model.dailyFiles.count))
                                .font(.headline)
                            if !model.exportCompanyName.isEmpty, model.exportCompanyName != "Export" {
                                Text(L10n.tr("utilities.mt940.detected_company", model.exportCompanyName))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            ForEach(model.dailyFiles) { file in
                                Text("• \(file.fileName)")
                                    .font(.caption)
                            }

                            Button(L10n.tr("utilities.mt940.export_save")) {
                                model.exportGeneratedFiles()
                            }
                            .buttonStyle(AppButtonStyles.borderedProminent)
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
            .navigationTitle(L10n.tr("utilities.mt940.title"))
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
