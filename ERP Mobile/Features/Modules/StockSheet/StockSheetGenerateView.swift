import SwiftUI
import UIKit

struct StockSheetGenerateView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var rows: [StockSheetListRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showScanner = false
    @State private var selectedRow: StockSheetDetailContext?
    @State private var showPrintSheet = false
    @State private var showExportShare = false
    @State private var exportShareItems: [Any] = []
    @State private var exportExcludedActivities: [UIActivity.ActivityType]?
    @State private var pdfAttachmentURL: URL?
    @State private var exportErrorMessage: String?

    private var filteredRows: [StockSheetListRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            row.product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(row.product.cod, query: query)
                || BarcodeMatching.matchesField(row.product.codBare, query: query)
        }
    }

    private var listingSnapshot: StockSheetListingSnapshot {
        StockSheetListingSnapshot(
            company: companyManager.currentCompany,
            rows: filteredRows,
            generatedAt: Date()
        )
    }

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.stock_sheet.loading_permissions"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.stock_sheet.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.stock_sheet.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else if filteredRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("stock_sheet.empty"),
                    systemImage: "list.bullet.rectangle",
                    description: Text(L10n.tr("stock_sheet.empty_hint"))
                )
            } else {
                List {
                    Section {
                        ForEach(filteredRows) { row in
                            Button {
                                selectedRow = StockSheetDetailContext(row: row)
                            } label: {
                                StockSheetListRowView(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        if !filteredRows.isEmpty {
                            HStack {
                                Text(L10n.tr("stock_sheet.total"))
                                Spacer()
                                Text(SupplierFormatting.currency(filteredRows.reduce(0) { $0 + $1.valoare }))
                                    .font(.subheadline.bold())
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .searchableWithBarcodeScanner(
                    text: $searchText,
                    prompt: L10n.tr("inventory.search_prompt"),
                    isScannerPresented: $showScanner,
                    onScanned: handleBarcodeScan
                )
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.stock_sheet.tile_generate"))
        .navigationBarTitleDisplayMode(.inline)
        .floatingBottomTrailing {
            if access.canView && !rows.isEmpty {
                listingActionsBar
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appSafeAreaInsetBottom {
            if let message = errorMessage ?? exportErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appTask {
            await loadAccess()
            await loadRows()
        }
        .appRefreshable { await loadRows() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task {
                await loadAccess()
                await loadRows()
            }
        }
        .fullScreenCover(item: $selectedRow) { context in
            StockSheetDetailView(context: context)
        }
        .sheet(isPresented: $showExportShare) {
            ActivityShareSheet(
                items: exportShareItems,
                excludedActivityTypes: exportExcludedActivities,
                onFinish: { showExportShare = false }
            )
        }
        .sheet(isPresented: $showPrintSheet) {
            if let pdfAttachmentURL,
               let data = try? Data(contentsOf: pdfAttachmentURL) {
                PrintDocumentView(
                    pdfData: data,
                    jobName: L10n.tr("stock_sheet.print_job_list"),
                    onFinish: { showPrintSheet = false }
                )
            }
        }
    }

    private var listingActionsBar: some View {
        FloatingIconActionsBar {
            FloatingIconActionButton(
                systemImage: "printer.fill",
                label: L10n.tr("account.print")
            ) {
                Task { await performListingExport(.print) }
            }
            FloatingIconActionButton(
                systemImage: "doc.fill",
                label: L10n.tr("account.export_pdf")
            ) {
                Task { await performListingExport(.exportPDF) }
            }
            FloatingIconActionButton(
                systemImage: "tablecells.fill",
                label: L10n.tr("account.export_xls")
            ) {
                Task { await performListingExport(.exportXLS) }
            }
            FloatingIconActionButton(
                systemImage: "paperplane.fill",
                label: L10n.tr("account.send")
            ) {
                Task { await performListingExport(.sendEmailOrWhatsApp) }
            }
        }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            isLoadingAccess = false
            return
        }
        do {
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }

    private func loadRows() async {
        guard let companyId = companyManager.currentCompany?.id, access.canView else {
            rows = []
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            rows = try await StockSheetService.fetchListRows(companyId: companyId)
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleBarcodeScan(_ code: String) {
        if let row = rows.first(where: { BarcodeMatching.exactMatch(productBarcode: $0.product.codBare, scanned: code) }) {
            selectedRow = StockSheetDetailContext(row: row)
        }
    }

    private enum ExportAction {
        case print
        case exportPDF
        case exportXLS
        case sendEmailOrWhatsApp
    }

    private func performListingExport(_ action: ExportAction) async {
        exportErrorMessage = nil
        let snapshot = listingSnapshot
        do {
            switch action {
            case .print:
                pdfAttachmentURL = try StockSheetPDFBuilder.writeTemporaryListingPDF(from: snapshot)
                showPrintSheet = true
            case .exportPDF:
                let url = try StockSheetPDFBuilder.writeTemporaryListingPDF(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .exportXLS:
                let url = try StockSheetXLSBuilder.writeTemporaryListingXLS(from: snapshot)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .sendEmailOrWhatsApp:
                let url = try StockSheetPDFBuilder.writeTemporaryListingPDF(from: snapshot)
                exportShareItems = [L10n.tr("stock_sheet.share_message_list"), url]
                exportExcludedActivities = [.print, .addToReadingList, .assignToContact, .copyToPasteboard]
                showExportShare = true
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

private struct StockSheetListRowView: View {
    let row: StockSheetListRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.product.denumire)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                HStack(spacing: 8) {
                    if let cod = row.product.cod, !cod.isEmpty {
                        Text(cod)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(row.unit)
                        .font(.caption)
                        .foregroundColor(AppColors.tertiary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(SupplierFormatting.amountString(row.cantitate)) \(row.unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(row.cantitate < 0 ? .red : .primary)
                Text(SupplierFormatting.currency(row.valoare))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
