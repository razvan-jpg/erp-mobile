import SwiftUI

struct PhysicalInventoryProductPickerView: View {
    let inventoryId: UUID
    let existingProductIds: Set<UUID>
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var products: [Product] = []
    @State private var stockByProductId: [UUID: Decimal] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var countedText = ""
    @State private var showScanner = false

    private var availableProducts: [Product] {
        products
            .filter { !existingProductIds.contains($0.id) && $0.isActive }
            .sorted {
                $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending
            }
    }

    private var filteredProducts: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableProducts }
        return availableProducts.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    private var parsedCount: Decimal? {
        SupplierFormatting.parseAmount(
            countedText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }

    var body: some View {
        NavigationView {
            Group {
                if selectedProduct == nil {
                    productList
                } else {
                    countForm
                }
            }
            .navigationTitle(selectedProduct == nil
                ? L10n.tr("inventory.physical_add_product")
                : L10n.tr("inventory.physical_line_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedProduct == nil ? L10n.tr("common.cancel") : L10n.tr("common.back")) {
                        if selectedProduct == nil {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            selectedProduct = nil
                            countedText = ""
                            errorMessage = nil
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedProduct != nil {
                        Button(L10n.tr("common.save")) {
                            Task { await addProduct() }
                        }
                        .disabled(isLoading || parsedCount == nil)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await loadProducts() }
        }
    }

    @ViewBuilder
    private var productList: some View {
        Group {
            if filteredProducts.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("inventory.physical_no_products"),
                    systemImage: "cube.box",
                    description: Text(L10n.tr("inventory.physical_no_products_hint"))
                )
            } else {
                List(filteredProducts) { product in
                    Button {
                        selectProduct(product)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.denumire)
                                .font(.headline)
                                .foregroundColor(AppColors.primary)
                            HStack {
                                if let cod = product.cod, !cod.isEmpty {
                                    Text(cod)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                if let barcode = product.codBare, !barcode.isEmpty {
                                    Label(barcode, systemImage: "barcode")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                            }
                            if let stock = stockByProductId[product.id] {
                                Text(L10n.tr("inventory.physical_book_stock_value", SupplierFormatting.amountString(stock), product.unitateMasura))
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
                .searchableWithBarcodeScanner(
                    text: $searchText,
                    prompt: L10n.tr("inventory.search_prompt"),
                    isScannerPresented: $showScanner,
                    onScanned: handleBarcodeScan
                )
            }
        }
    }

    @ViewBuilder
    private var countForm: some View {
        Form {
            if let product = selectedProduct {
                Section {
                    AppLabeledContent(L10n.tr("inventory.physical_product"), value: product.denumire)
                    if let stock = stockByProductId[product.id] {
                        AppLabeledContent(L10n.tr("inventory.physical_book_stock")) {
                            Text("\(SupplierFormatting.amountString(stock)) \(product.unitateMasura)")
                        }
                    } else {
                        AppLabeledContent(L10n.tr("inventory.physical_book_stock")) {
                            Text("0 \(product.unitateMasura)")
                        }
                    }
                }

                Section(header: Text(L10n.tr("inventory.physical_counted_stock"))) {
                    TextField(SupplierFormatting.amountPlaceholder, text: $countedText)
                        .keyboardType(.decimalPad)
                    Text(SupplierFormatting.invoiceAmountHint)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func selectProduct(_ product: Product) {
        selectedProduct = product
        let stock = stockByProductId[product.id] ?? 0
        countedText = SupplierFormatting.amountString(stock)
    }

    private func handleBarcodeScan(_ code: String) {
        if let product = availableProducts.first(where: { BarcodeMatching.exactMatch(productBarcode: $0.codBare, scanned: code) }) {
            selectProduct(product)
        }
    }

    private func loadProducts() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let productsTask = ProductService.fetchProducts(companyId: companyId)
            async let stockTask = InventoryService.fetchStockRows(companyId: companyId)
            products = try await productsTask
            let stockRows = try await stockTask
            stockByProductId = Dictionary(uniqueKeysWithValues: stockRows.map { ($0.productId, $0.cantitate) })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addProduct() async {
        guard let product = selectedProduct, let parsedCount else { return }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await PhysicalInventoryService.upsertLine(
                inventoryId: inventoryId,
                productId: product.id,
                cantitateNumarata: parsedCount
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
