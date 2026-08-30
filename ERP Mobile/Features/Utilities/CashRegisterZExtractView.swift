import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct CashRegisterZExtractView: View {
    @StateObject private var model = CashRegisterZExtractViewModel()

    var body: some View {
        ZStack {
            AdaptiveCenteredContent(maxWidth: 760) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.tr("utilities.cash_register.hint"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)

                    connectionForm

                    if model.isBinaProvider && model.hasAvailableReports {
                        availableReportsSection
                    }

                    uploadSection

                    if !model.extractedReports.isEmpty {
                        resultsSection
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
            .navigationTitle(L10n.tr("utilities.cash_register.title"))
            .navigationBarTitleDisplayMode(.inline)
            .appFullOverlay { LoadingOverlay(isLoading: model.isProcessing || model.isLoadingSettings) }
            .appTask {
                await model.loadSettings()
                _ = try? await UtilityTemplateService.fetchTemplate(.zReportModel)
            }
            #if os(iOS) || targetEnvironment(macCatalyst)
            .sheet(item: $model.pendingShare) { share in
                CashRegisterShareSheet(items: share.urls)
            }
            .sheet(isPresented: $model.showExportDirectoryPicker) {
                CashRegisterExportDirectorySheet(model: model)
            }
            #endif
        }
    }

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("utilities.cash_register.connection_section"))
                .font(.headline)

            Picker(L10n.tr("utilities.cash_register.provider"), selection: $model.provider) {
                ForEach(CashRegisterProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("utilities.cash_register.base_url"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                TextField(L10n.tr("utilities.cash_register.base_url_placeholder"), text: $model.baseURL)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    #endif
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("utilities.cash_register.username"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                TextField(L10n.tr("utilities.cash_register.username_placeholder"), text: $model.username)
                    .textFieldStyle(.roundedBorder)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("utilities.cash_register.password"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                SecureField(L10n.tr("utilities.cash_register.password_placeholder"), text: $model.password)
                    .textFieldStyle(.roundedBorder)
            }

            Text(L10n.tr("utilities.cash_register.period_section"))
                .font(.headline)
                .padding(.top, 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("utilities.cash_register.from_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    AppDatePicker(selection: $model.fromDate)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("utilities.cash_register.to_date"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    AppDatePicker(selection: $model.toDate)
                }
            }

            Picker(L10n.tr("utilities.cash_register.export_mode"), selection: $model.exportMode) {
                ForEach(CashRegisterZExportMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if model.provider == .binaSmartBusiness {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("utilities.cash_register.bina_location"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Picker(L10n.tr("utilities.cash_register.bina_location"), selection: $model.binaLocationFilter) {
                        Text(L10n.tr("utilities.cash_register.bina_location_all")).tag("")
                        ForEach(CashRegisterZExtractViewModel.binaLocationPresets.filter { !$0.isEmpty }, id: \.self) { location in
                            Text(location).tag(location)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("utilities.cash_register.export_folder"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(model.exportDirectory.isEmpty ? model.resolvedExportDirectory.path : model.exportDirectory)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(2)
                    Button(L10n.tr("utilities.cash_register.choose_export_folder")) {
                        model.chooseExportDirectory()
                    }
                    .buttonStyle(AppButtonStyles.bordered)
                }
            }

            HStack(spacing: 12) {
                if model.isBinaProvider {
                    Button(L10n.tr("utilities.cash_register.list_reports")) {
                        Task { await model.listReportsInPeriod() }
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .disabled(model.isProcessing)

                    Button(L10n.tr("utilities.cash_register.download_selected", model.selectedReportsCount)) {
                        Task { await model.downloadSelectedReports() }
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .disabled(!model.canDownloadSelected)
                } else {
                    Button(L10n.tr("utilities.cash_register.extract")) {
                        Task { await model.listReportsInPeriod() }
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .disabled(model.isProcessing)
                }

                if !model.extractedReports.isEmpty || model.hasAvailableReports {
                    Button(L10n.tr("utilities.common.clear")) {
                        model.clearResults()
                    }
                    .buttonStyle(AppButtonStyles.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("utilities.cash_register.upload_section"))
                .font(.headline)
            Text(L10n.tr("utilities.cash_register.upload_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)

            UtilityFileImportButton(
                title: L10n.tr("utilities.cash_register.upload_button"),
                contentTypes: [.pdf, .plainText, .data, .item],
                onImportURLs: { model.registerImportedFiles($0) }
            )
            .buttonStyle(AppButtonStyles.bordered)

            if !model.importedFiles.isEmpty {
                ForEach(model.importedFiles) { file in
                    Text("• \(file.name)")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }

                Button(L10n.tr("utilities.cash_register.process_uploads")) {
                    Task { await model.importUploadedFiles() }
                }
                .buttonStyle(AppButtonStyles.borderedProminent)
                .disabled(model.isProcessing)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var availableReportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("utilities.cash_register.available_section", model.availableReports.count))
                    .font(.headline)
                Spacer()
                Button(L10n.tr("utilities.cash_register.select_all")) {
                    model.selectAllReports()
                }
                .font(.caption)
                Button(L10n.tr("utilities.cash_register.deselect_all")) {
                    model.deselectAllReports()
                }
                .font(.caption)
            }

            ForEach(model.availableReports) { report in
                Toggle(isOn: Binding(
                    get: { model.selectedReportIDs.contains(report.remoteID) },
                    set: { isOn in
                        if isOn {
                            model.selectedReportIDs.insert(report.remoteID)
                        } else {
                            model.selectedReportIDs.remove(report.remoteID)
                        }
                    }
                )) {
                    Text(previewLabel(for: report))
                        .font(.caption)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func previewLabel(for report: CashRegisterZReportPreviewItem) -> String {
        let date = SupplierFormatting.date(report.reportDate)
        let number = report.reportNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = report.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let number, !number.isEmpty {
            if location.isEmpty {
                return L10n.tr("utilities.cash_register.report_line", number, date)
            }
            return L10n.tr("utilities.cash_register.report_line_location", number, date, location)
        }
        if location.isEmpty {
            return date
        }
        return L10n.tr("utilities.cash_register.report_line_location_short", date, location)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("utilities.cash_register.results_section", model.extractedReports.count))
                .font(.headline)

            ForEach(model.extractedReports) { report in
                Text("• \(reportLabel(for: report))")
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }

            Button(L10n.tr("utilities.cash_register.save_pdfs")) {
                model.exportReports()
            }
            .buttonStyle(AppButtonStyles.borderedProminent)
        }
    }

    private func reportLabel(for report: ExtractedCashRegisterZReport) -> String {
        let date = SupplierFormatting.date(report.reportDate)
        if let number = report.reportNumber, !number.isEmpty {
            return L10n.tr("utilities.cash_register.report_line", number, date)
        }
        return date
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
private struct CashRegisterShareSheet: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
