import SwiftUI

struct StockListView: View {
    let canEdit: Bool
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var rows: [ProductStockRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedCard: ProductWarehouseCardContext?
    @State private var showScanner = false

    private var filteredRows: [ProductStockRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = rows.sorted {
            ($0.product?.denumire ?? "").localizedStandardCompare($1.product?.denumire ?? "") == .orderedAscending
        }
        guard !query.isEmpty else { return base }
        return base.filter { row in
            let name = row.product?.denumire ?? ""
            let cod = row.product?.cod ?? ""
            let barcode = row.product?.codBare ?? ""
            return name.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(cod, query: query)
                || BarcodeMatching.matchesField(barcode, query: query)
        }
    }

    var body: some View {
        Group {
            if filteredRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("inventory.stocks_empty"),
                    systemImage: "shippingbox",
                    description: Text(L10n.tr("inventory.stocks_empty_hint"))
                )
            } else {
                List(filteredRows) { row in
                    StockRowView(row: row) {
                        selectedCard = ProductWarehouseCardContext(row: row, canEdit: canEdit)
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
        .appSafeAreaInsetBottom {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadRows() }
        .appRefreshable {
            await loadRows()
            await onChanged()
        }
        .fullScreenCover(item: $selectedCard) { card in
            ProductWarehouseCardView(context: card)
        }
    }

    private func loadRows() async {
        guard let companyId = companyManager.currentCompany?.id else {
            rows = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            rows = try await InventoryService.fetchStockRows(companyId: companyId)
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleBarcodeScan(_ code: String) {
        if let row = rows.first(where: { BarcodeMatching.exactMatch(productBarcode: $0.product?.codBare, scanned: code) }) {
            selectedCard = ProductWarehouseCardContext(row: row, canEdit: canEdit)
        }
    }
}

private struct StockRowView: View {
    let row: ProductStockRow
    let onOpenCard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onOpenCard) {
                Text(row.product?.denumire ?? L10n.tr("inventory.unknown_product"))
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            HStack {
                if let cod = row.product?.cod, !cod.isEmpty {
                    Label(cod, systemImage: "number")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                if let tip = row.product?.tip {
                    Text(tip.label)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            HStack {
                Text(L10n.tr("inventory.field_quantity"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Text(quantityLabel)
                    .font(.subheadline.bold())
                    .foregroundColor(row.cantitate < 0 ? .red : .primary)
            }
            if let updatedAt = row.updatedAt {
                Text(L10n.tr("inventory.updated_at", SupplierFormatting.compactDate(updatedAt)))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var quantityLabel: String {
        let unit = row.product?.unitateMasura ?? "buc"
        return "\(SupplierFormatting.amountString(row.cantitate)) \(unit)"
    }
}
