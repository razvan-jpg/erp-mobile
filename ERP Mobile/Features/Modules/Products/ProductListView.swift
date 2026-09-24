import SwiftUI

enum ProductListScope {
    case catalog
    case articles
    case recipes

    var emptyTitleKey: String {
        switch self {
        case .catalog: return "module.products.catalog_empty"
        case .articles: return "module.products.articles_empty"
        case .recipes: return "module.products.recipes_empty"
        }
    }

    var emptyHintKey: String {
        switch self {
        case .catalog: return "module.products.catalog_empty_hint"
        case .articles: return "module.products.articles_empty_hint"
        case .recipes: return "module.products.recipes_empty_hint"
        }
    }
}

struct ProductListView: View {
    let scope: ProductListScope
    let canEdit: Bool
    var canCreate: Bool = false
    var canDelete: Bool = false

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var products: [Product] = []
    @State private var stockByProductId: [UUID: Decimal] = [:]
    @State private var productionCostByProductId: [UUID: Decimal] = [:]
    @State private var purchasePriceByProductId: [UUID: Decimal] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var pendingDetailProduct: Product?
    @State private var showScanner = false
    @State private var showCreate = false

    private var allowsCreate: Bool {
        scope == .articles && canCreate
    }

    private var usesTileLayout: Bool {
        scope == .catalog || scope == .articles
    }

    private let tileColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var filteredProducts: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = ProductSorting.sortedByName(products)
        guard !query.isEmpty else { return base }
        return base.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    var body: some View {
        Group {
            if filteredProducts.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr(scope.emptyTitleKey),
                    systemImage: "cube.box",
                    description: Text(L10n.tr(allowsCreate ? "module.products.articles_empty_create" : scope.emptyHintKey))
                )
            } else if usesTileLayout {
                ScrollView {
                    LazyVGrid(columns: tileColumns, spacing: 8) {
                        ForEach(filteredProducts) { product in
                            ProductTileView(
                                product: product,
                                stockQuantity: stockByProductId[product.id] ?? 0,
                                productionCost: productionCostByProductId[product.id],
                                purchasePrice: purchasePriceByProductId[product.id],
                                showsExtendedMetrics: true
                            ) {
                                selectedProduct = product
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .searchableWithBarcodeScanner(
                    text: $searchText,
                    prompt: L10n.tr("inventory.search_prompt"),
                    isScannerPresented: $showScanner,
                    onScanned: handleBarcodeScan
                )
                .appScrollBottomPadding()
            } else {
                List(filteredProducts) { product in
                    ProductRowView(product: product) {
                        selectedProduct = product
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
        .floatingBottomTrailing {
            if allowsCreate {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
                }
            }
        }
        .appTask { await loadProducts() }
        .appRefreshable {
            await loadProducts()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(
                product: product,
                canEdit: canEdit,
                canDelete: canDelete,
                onSaved: {
                    Task {
                        await loadProducts()
                    }
                },
                onDeleted: {
                    selectedProduct = nil
                    Task {
                        await loadProducts()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showCreate) {
            ProductCreateView(isPresented: $showCreate) {
                await loadProducts()
            } onCreatedFromScan: { product in
                pendingDetailProduct = product
            }
        }
        .onChangeCompat(of: showCreate) { wasOpen, isOpen in
            guard wasOpen, !isOpen else { return }
            if pendingDetailProduct != nil {
                openPendingDetail()
            } else {
                Task { await loadProducts() }
            }
        }
    }

    @MainActor
    private func openPendingDetail() {
        guard let product = pendingDetailProduct else { return }
        pendingDetailProduct = nil
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if let fresh = try? await ProductService.fetchProduct(id: product.id) {
                selectedProduct = fresh
            } else {
                selectedProduct = product
            }
        }
    }

    private func loadProducts() async {
        guard let companyId = companyManager.currentCompany?.id else {
            products = []
            stockByProductId = [:]
            productionCostByProductId = [:]
            purchasePriceByProductId = [:]
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            switch scope {
            case .catalog:
                products = try await ProductService.fetchProducts(companyId: companyId, inCatalog: true)
            case .articles:
                products = try await ProductService.fetchProducts(companyId: companyId)
            case .recipes:
                products = try await ProductService.fetchProducts(companyId: companyId, hasRecipe: true)
            }
            products = ProductSorting.sortedByName(products)
            if usesTileLayout {
                let stockRows = try await InventoryService.fetchStockRows(companyId: companyId)
                stockByProductId = Dictionary(uniqueKeysWithValues: stockRows.map { ($0.productId, $0.cantitate) })
                productionCostByProductId = try await ProductRecipeService.fetchProductionCosts(companyId: companyId)
                purchasePriceByProductId = try await ProductRecipeService.fetchLatestPurchasePrices(companyId: companyId)
            } else {
                stockByProductId = [:]
                productionCostByProductId = [:]
                purchasePriceByProductId = [:]
            }
        } catch {
            products = []
            stockByProductId = [:]
            productionCostByProductId = [:]
            purchasePriceByProductId = [:]
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleBarcodeScan(_ code: String) {
        if let product = products.first(where: { BarcodeMatching.exactMatch(productBarcode: $0.codBare, scanned: code) }) {
            selectedProduct = product
        }
    }
}

private struct ProductRowView: View {
    let product: Product
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.denumire)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    if let cod = product.cod, !cod.isEmpty {
                        Label(cod, systemImage: "number")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(product.tip.label)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }

                HStack(spacing: 8) {
                    if product.inCatalog {
                        badge(L10n.tr("products.field_in_catalog"), systemImage: "books.vertical")
                    }
                    if product.hasRecipe {
                        badge(L10n.tr("products.field_has_recipe"), systemImage: "list.bullet.rectangle")
                    }
                    if let barcode = product.codBare, !barcode.isEmpty {
                        Label(barcode, systemImage: "barcode")
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func badge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }
}
