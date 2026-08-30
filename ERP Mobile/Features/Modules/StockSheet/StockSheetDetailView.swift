import SwiftUI
import UIKit

struct StockSheetDetailView: View {
    let context: StockSheetDetailContext

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var snapshot: StockSheetSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPrintSheet = false
    @State private var showExportShare = false
    @State private var exportShareItems: [Any] = []
    @State private var exportExcludedActivities: [UIActivity.ActivityType]?
    @State private var pdfAttachmentURL: URL?
    @State private var exportErrorMessage: String?

    private var product: Product { context.row.product }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    ledgerCard
                    Color.clear.frame(height: 280)
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .appScrollBottomPadding()
            .floatingBottomTrailing {
                accountActionsBar
            }
            .navigationTitle(L10n.tr("stock_sheet.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
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
            .appTask { await loadSnapshot() }
            .appRefreshable { await loadSnapshot() }
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
                        jobName: L10n.tr("stock_sheet.print_job", product.denumire),
                        onFinish: { showPrintSheet = false }
                    )
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(product.denumire)
                .font(.title3.bold())

            if let company = companyManager.currentCompany {
                Text(company.denumire)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }

            if let cod = product.cod, !cod.isEmpty {
                labeledRow(L10n.tr("module.products.field_code"), cod)
            }
            if let barcode = product.codBare, !barcode.isEmpty {
                labeledRow(L10n.tr("inventory.physical_field_barcode"), barcode)
            }
            labeledRow(L10n.tr("inventory.field_unit"), product.unitateMasura)
            labeledRow(
                L10n.tr("inventory.field_quantity"),
                "\(SupplierFormatting.amountString(snapshot?.cantitate ?? context.row.cantitate)) \(product.unitateMasura)"
            )
            labeledRow(
                L10n.tr("inventory.weighted_average_cost"),
                (snapshot?.pretMediu ?? context.row.pretMediu).map { SupplierFormatting.amountString($0) } ?? "—"
            )
            labeledRow(
                L10n.tr("stock_sheet.col_value"),
                SupplierFormatting.currency(snapshot?.valoare ?? context.row.valoare)
            )
            labeledRow(L10n.tr("account.listing_date"), SupplierFormatting.date(snapshot?.generatedAt ?? Date()))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var ledgerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("stock_sheet.movements_title"))
                .font(.headline)
            StockSheetTableView(entries: snapshot?.entries ?? [])
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }

    private var accountActionsBar: some View {
        FloatingIconActionsBar {
            FloatingIconActionButton(
                systemImage: "printer.fill",
                label: L10n.tr("account.print")
            ) {
                Task { await performExport(.print) }
            }
            FloatingIconActionButton(
                systemImage: "doc.fill",
                label: L10n.tr("account.export_pdf")
            ) {
                Task { await performExport(.exportPDF) }
            }
            FloatingIconActionButton(
                systemImage: "tablecells.fill",
                label: L10n.tr("account.export_xls")
            ) {
                Task { await performExport(.exportXLS) }
            }
            FloatingIconActionButton(
                systemImage: "paperplane.fill",
                label: L10n.tr("account.send")
            ) {
                Task { await performExport(.sendEmailOrWhatsApp) }
            }

            FloatingIconActionDivider()

            FloatingIconActionButton(
                systemImage: "arrow.uturn.backward",
                label: L10n.tr("stock_sheet.back_to_list")
            ) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    private func labeledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(AppColors.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private func loadSnapshot() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await StockSheetService.fetchSnapshot(
                companyId: companyId,
                company: companyManager.currentCompany,
                product: product
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private enum ExportAction {
        case print
        case exportPDF
        case exportXLS
        case sendEmailOrWhatsApp
    }

    private func performExport(_ action: ExportAction) async {
        exportErrorMessage = nil
        let current: StockSheetSnapshot
        if let snapshot {
            current = snapshot
        } else if let companyId = companyManager.currentCompany?.id {
            do {
                current = try await StockSheetService.fetchSnapshot(
                    companyId: companyId,
                    company: companyManager.currentCompany,
                    product: product
                )
                snapshot = current
            } catch {
                exportErrorMessage = error.localizedDescription
                return
            }
        } else {
            return
        }

        do {
            switch action {
            case .print:
                pdfAttachmentURL = try StockSheetPDFBuilder.writeTemporaryPDF(from: current)
                showPrintSheet = true
            case .exportPDF:
                let url = try StockSheetPDFBuilder.writeTemporaryPDF(from: current)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .exportXLS:
                let url = try StockSheetXLSBuilder.writeTemporaryXLS(from: current)
                exportShareItems = [url]
                exportExcludedActivities = nil
                showExportShare = true
            case .sendEmailOrWhatsApp:
                let url = try StockSheetPDFBuilder.writeTemporaryPDF(from: current)
                exportShareItems = [L10n.tr("stock_sheet.share_message", product.denumire), url]
                exportExcludedActivities = [.print, .addToReadingList, .assignToContact, .copyToPasteboard]
                showExportShare = true
            }
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}
