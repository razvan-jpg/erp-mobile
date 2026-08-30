import SwiftUI
import UIKit

struct NIRMarkupAccountingView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var selectedMonth = SupplierFormatting.startOfMonth(for: Date())
    @State private var report: NIRMarkupAccountingReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var exportExcludedActivities: [UIActivity.ActivityType]?
    @State private var showPrintSheet = false
    @State private var pdfAttachmentURL: URL?
    @State private var showSavePicker = false
    @State private var saveDocumentURL: URL?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("nir.markup_accounting_month_picker"))
                        .font(.subheadline)
                    AppDatePicker(selection: $selectedMonth)
                }
                .onChange(of: selectedMonth) { newValue in
                    selectedMonth = SupplierFormatting.startOfMonth(for: newValue)
                    Task { await loadReport() }
                }
            }

            if let report {
                Section(header: Text(L10n.tr("nir.markup_accounting_section_note"))) {
                    accountingRow(
                        debit: "371",
                        credit: "378",
                        amount: report.adaosSuma
                    )
                    accountingRow(
                        debit: "371",
                        credit: "4428",
                        amount: report.tvaAfAdeaos
                    )
                }

                Section {
                    Menu {
                        Button(L10n.tr("account.print"), systemImage: "printer.fill") {
                            Task { await performExport(.print) }
                        }

                        Button(L10n.tr("nir.markup_accounting_export_pdf"), systemImage: "doc.fill") {
                            Task { await performExport(.exportPDF) }
                        }

                        Button(L10n.tr("nir.markup_accounting_export_listing"), systemImage: "doc.text") {
                            Task { await performExport(.exportListing) }
                        }

                        Button(L10n.tr("account.send"), systemImage: "paperplane.fill") {
                            Task { await performExport(.send) }
                        }
                    } label: {
                        Label(L10n.tr("nir.markup_accounting_share"), systemImage: "square.and.arrow.up")
                    }
                }

                if report.entries.isEmpty {
                    Section {
                        Text(L10n.tr("nir.markup_accounting_empty_month"))
                            .foregroundColor(AppColors.secondary)
                    }
                } else {
                    Section(header: Text(L10n.tr("nir.markup_accounting_section_nirs", report.entries.count))) {
                        ForEach(report.entries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.numarNir)
                                    .font(.headline)
                                Text(entry.invoiceNumber)
                                    .font(.subheadline)
                                Text(entry.supplierName)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                HStack {
                                    Text(SupplierFormatting.date(entry.dataNir))
                                    Spacer()
                                    Text(
                                        L10n.tr(
                                            "nir.markup_accounting_entry_amounts",
                                            SupplierFormatting.amountString(entry.adaosSuma),
                                            SupplierFormatting.amountString(entry.tvaAfAdeaos)
                                        )
                                    )
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(L10n.tr("nir.markup_accounting_title"))
        .navigationBarTitleDisplayMode(.inline)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadReport() }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(
                items: shareItems,
                excludedActivityTypes: exportExcludedActivities,
                onFinish: { showShareSheet = false }
            )
        }
        .sheet(isPresented: $showPrintSheet) {
            if let pdfAttachmentURL,
               let data = try? Data(contentsOf: pdfAttachmentURL) {
                PrintDocumentView(
                    pdfData: data,
                    jobName: printJobName,
                    onFinish: { showPrintSheet = false }
                )
            }
        }
#if targetEnvironment(macCatalyst)
        .sheet(isPresented: $showSavePicker) {
            if let saveDocumentURL {
                PDFLocalSaveDocumentPicker(
                    sourceURL: saveDocumentURL,
                    onFinish: { showSavePicker = false }
                )
                .ignoresSafeArea()
            }
        }
#endif
    }

    private var printJobName: String {
        L10n.tr(
            "nir.markup_accounting_print_job",
            SupplierFormatting.monthYear(selectedMonth)
        )
    }

    private func accountingRow(debit: String, credit: String, amount: Decimal) -> some View {
        HStack {
            Text(L10n.tr("nir.markup_accounting_accounts", debit, credit))
                .font(.headline)
            Spacer()
            Text(SupplierFormatting.amountString(amount))
                .font(.headline)
        }
        .padding(.vertical, 4)
    }

    private enum ExportAction {
        case print
        case exportPDF
        case exportListing
        case send
    }

    private func makeSnapshot() -> NIRMarkupAccountingSnapshot? {
        guard let report else { return nil }
        return NIRMarkupAccountingSnapshot(
            company: companyManager.currentCompany,
            report: report,
            generatedAt: Date()
        )
    }

    private func performExport(_ action: ExportAction) async {
        guard let report else { return }

        isLoading = true
        errorMessage = nil
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        do {
            switch action {
            case .print:
                guard let snapshot = makeSnapshot() else { return }
                let url = try NIRMarkupAccountingPDFBuilder.writeTemporaryPDF(from: snapshot)
                await MainActor.run {
                    pdfAttachmentURL = url
                    showPrintSheet = true
                }
            case .exportPDF:
                guard let snapshot = makeSnapshot() else { return }
                let url = try NIRMarkupAccountingPDFBuilder.writeTemporaryPDF(from: snapshot)
                presentExportURL(url)
            case .exportListing:
                let url = try NIRMarkupAccountingService.writeTemporaryListing(from: report)
                presentExportURL(url)
            case .send:
                guard let snapshot = makeSnapshot() else { return }
                let url = try NIRMarkupAccountingPDFBuilder.writeTemporaryPDF(from: snapshot)
                await MainActor.run {
                    shareItems = [
                        L10n.tr(
                            "nir.markup_accounting_share_message",
                            SupplierFormatting.monthYear(report.month)
                        ),
                        url
                    ]
                    exportExcludedActivities = [
                        .print,
                        .addToReadingList,
                        .assignToContact,
                        .copyToPasteboard
                    ]
                    showShareSheet = true
                }
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func presentExportURL(_ url: URL) {
#if targetEnvironment(macCatalyst)
        saveDocumentURL = url
        showSavePicker = true
#else
        shareItems = [url]
        exportExcludedActivities = nil
        showShareSheet = true
#endif
    }

    private func loadReport() async {
        guard let companyId = companyManager.currentCompany?.id else {
            await MainActor.run {
                report = nil
                errorMessage = L10n.tr("module.suppliers.no_company_selected")
            }
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await NIRMarkupAccountingService.buildReport(
                companyId: companyId,
                month: selectedMonth
            )
            await MainActor.run {
                report = loaded
                isLoading = false
            }
        } catch is CancellationError {
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
