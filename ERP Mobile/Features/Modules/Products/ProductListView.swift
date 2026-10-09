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
    @State private var catalogGroups: [CMProductGroup] = []
    @State private var menus: [CMMenu] = []
    @State private var menuImages: [UUID: String] = [:]
    @State private var groupIdsByProduct: [UUID: Set<UUID>] = [:]
    @State private var selectedGroupId: UUID?
    @State private var selectedProduct: Product?
    @State private var selectedMenu: CMMenu?
    @State private var menuPendingDelete: CMMenu?
    @State private var pendingDetailProduct: Product?
    @State private var showScanner = false
    @State private var showCreate = false
    @State private var showCreateMenu = false

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

    private var showsMenus: Bool {
        guard let selectedGroupId else { return false }
        return catalogGroups.first(where: { $0.id == selectedGroupId })?.kind == .menus
    }

    private var filteredMenus: [CMMenu] {
        let base = menus.sorted {
            $0.name.compare($1.name, options: .caseInsensitive, locale: Locale(identifier: "ro")) == .orderedAscending
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var filteredProducts: [Product] {
        var base = ProductSorting.sortedByName(products)
        if let selectedGroupId {
            base = base.filter { groupIdsByProduct[$0.id]?.contains(selectedGroupId) == true }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || Self.matchesCode(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    private var selectedGroupTitle: String {
        if let selectedGroupId,
           let name = catalogGroups.first(where: { $0.id == selectedGroupId })?.name {
            return name
        }
        return L10n.tr("module.products.filter_group_all")
    }

    private var groupFilterBar: some View {
        HStack {
            Menu {
                Button(L10n.tr("module.products.filter_group_all")) {
                    selectedGroupId = nil
                }
                ForEach(catalogGroups) { group in
                    Button(group.name) {
                        selectedGroupId = group.id
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selectedGroupTitle)
                        .lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    var body: some View {
        VStack(spacing: 0) {
            if scope == .articles {
                groupFilterBar
            }
            Group {
                if showsMenus {
                    if filteredMenus.isEmpty && !isLoading {
                        AppEmptyStateView(
                            "Nu există meniuri.",
                            systemImage: "menucard",
                            description: Text("Meniurile se adaugă în Nomenclatoare → Catalog.")
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: tileColumns, spacing: 8) {
                                ForEach(filteredMenus) { menu in
                                    ArticleMenuTile(menu: menu, imageUrl: menuImages[menu.id], canDelete: canDelete || canEdit) {
                                        selectedMenu = menu
                                    } onDelete: {
                                        menuPendingDelete = menu
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .appScrollBottomPadding()
                    }
                } else if filteredProducts.isEmpty && !isLoading {
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
                    .appScrollBottomPadding()
                } else {
                    List(filteredProducts) { product in
                        ProductRowView(product: product) {
                            selectedProduct = product
                        }
                    }
                    .appScrollBottomPadding()
                }
            }
        }
        .searchableWithBarcodeScanner(
            text: $searchText,
            prompt: L10n.tr("inventory.search_prompt"),
            isScannerPresented: $showScanner,
            onScanned: handleBarcodeScan
        )
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
            if showsMenus && canCreate {
                Button { showCreateMenu = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
                }
            } else if allowsCreate {
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
        .sheet(item: $selectedMenu) { menu in
            CMMenuEditorView(menu: menu, canEdit: canEdit) {
                Task { await loadProducts() }
            }
        }
        .sheet(isPresented: $showCreateMenu) {
            CMMenuEditorView(menu: nil, canEdit: canCreate || canEdit) {
                Task { await loadProducts() }
            }
        }
        .confirmationDialog(
            "Ștergeți meniul \(menuPendingDelete?.name ?? "")?",
            isPresented: Binding(
                get: { menuPendingDelete != nil },
                set: { if !$0 { menuPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Șterge", role: .destructive) {
                guard let menu = menuPendingDelete else { return }
                menuPendingDelete = nil
                Task {
                    do {
                        try await CMProductGroupService.deleteMenu(id: menu.id)
                        await loadProducts()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Renunță", role: .cancel) { menuPendingDelete = nil }
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
            catalogGroups = []
            menus = []
            menuImages = [:]
            groupIdsByProduct = [:]
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
            if scope == .articles {
                do {
                    let groups = try await CMProductGroupService.fetchGroups(companyId: companyId)
                        .filter { $0.kind == .custom || $0.kind == .menus }
                    catalogGroups = groups.sorted {
                        $0.name.compare($1.name, options: .caseInsensitive, locale: Locale(identifier: "ro")) == .orderedAscending
                    }
                    menus = try await CMProductGroupService.fetchMenus(companyId: companyId)
                    menuImages = (try? await CMProductGroupService.fetchMainProductImages(menuIds: menus.map(\.id))) ?? [:]
                    groupIdsByProduct = try await CMProductGroupService.fetchProductGroupIds(companyId: companyId)
                    if let selectedGroupId, !catalogGroups.contains(where: { $0.id == selectedGroupId }) {
                        self.selectedGroupId = nil
                    }
                } catch {
                    catalogGroups = []
                    menus = []
            menuImages = [:]
                    groupIdsByProduct = [:]
                }
            } else {
                catalogGroups = []
                menus = []
            menuImages = [:]
                groupIdsByProduct = [:]
                selectedGroupId = nil
            }
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
            catalogGroups = []
            menus = []
            menuImages = [:]
            groupIdsByProduct = [:]
            stockByProductId = [:]
            productionCostByProductId = [:]
            purchasePriceByProductId = [:]
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private static func matchesCode(_ code: String?, query: String) -> Bool {
        guard let code else { return false }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.localizedCaseInsensitiveContains(query)
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

private struct ArticleMenuTile: View {
    let menu: CMMenu
    var imageUrl: String?
    var canDelete = false
    let onTap: () -> Void
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    ProductThumbnailView(imagineUrl: imageUrl, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(menu.name)
                        .font(.headline)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !menu.cod.isEmpty {
                        Text(menu.cod)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(SupplierFormatting.amountString(menu.pretVanzare) + " RON")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.secondary)
                    if !menu.isActive {
                        Text("Inactiv")
                            .font(.caption)
                            .foregroundColor(AppColors.tertiary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Șterge meniul")
            }
        }
    }
}
