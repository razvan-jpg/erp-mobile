import SwiftUI

struct StockMovementsListView: View {
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var rows: [StockMovementRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showScanner = false

    private var filteredRows: [StockMovementRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            row.productName.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(row.product?.cod, query: query)
                || BarcodeMatching.matchesField(row.product?.codBare, query: query)
                || row.sourceLabel.localizedCaseInsensitiveContains(query)
                || (row.referinta?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredRows.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("inventory.movements_empty"),
                    systemImage: "arrow.left.arrow.right",
                    description: Text(L10n.tr("inventory.movements_empty_hint"))
                )
            } else {
                List(filteredRows) { row in
                    StockMovementRowView(row: row)
                }
                .searchableWithBarcodeScanner(
                    text: $searchText,
                    prompt: L10n.tr("inventory.search_movements_prompt"),
                    isScannerPresented: $showScanner
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
    }

    private func loadRows() async {
        guard let companyId = companyManager.currentCompany?.id else {
            rows = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            rows = try await InventoryService.fetchMovements(companyId: companyId)
        } catch {
            rows = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct StockMovementRowView: View {
    let row: StockMovementRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.productName)
                    .font(.headline)
                Spacer()
                Text(row.tip.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(row.tip.isInbound ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundColor(row.tip.isInbound ? .green : .red)
                    .clipShape(Capsule())
            }
            HStack {
                Text(quantityLabel)
                    .font(.subheadline.bold())
                Spacer()
                Text(SupplierFormatting.date(row.transactionDate))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            Text(row.sourceLabel)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            if let referinta = row.referinta, !referinta.isEmpty {
                Text(referinta)
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var quantityLabel: String {
        let sign = row.tip.isInbound ? "+" : "−"
        return "\(sign)\(SupplierFormatting.amountString(row.cantitate)) \(row.unitateMasura)"
    }
}
