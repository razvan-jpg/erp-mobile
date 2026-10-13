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

private enum ProductListLayoutMode: String, CaseIterable {
    case tiles
    case list

    var systemImage: String {
        switch self {
        case .tiles: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

struct ProductListView: View {
    let scope: ProductListScope
    let canEdit: Bool
    var canCreate: Bool = false
    var canDelete: Bool = false

    @EnvironmentObject private var companyManager: CompanyManager
    @AppStorage("products.list.layout") private var layoutRaw = ProductListLayoutMode.tiles.rawValue
    @State private var selectedCategoryRaws: Set<String> = []
    @State private var products: [Product] = []
    @State private var stockByProductId: [UUID: Decimal] = [:]
    @State private var locationStockByProductId: [UUID: [ProductLocationStock]] = [:]
    @State private var productionCostByProductId: [UUID: Decimal] = [:]
    @State private var purchasePriceByProductId: [UUID: Decimal] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var catalogGroups: [CMProductGroup] = []
    @State private var menus: [CMMenu] = []
    @State private var menuImages: [UUID: String] = [:]
    @State private var groupIdsByProduct: [UUID: Set<UUID>] = [:]
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var selectedProduct: Product?
    @State private var selectedMenu: CMMenu?
    @State private var menuPendingDelete: CMMenu?
    @State private var pendingDetailProduct: Product?
    @State private var showScanner = false
    @State private var showCreate = false
    @State private var showCreateMenu = false
    @State private var showGroupFilter = false
    @State private var showCategoryFilter = false

    private var allowsCreate: Bool {
        scope == .articles && canCreate
    }

    private var supportsLayoutToggle: Bool {
        scope == .catalog || scope == .articles
    }

    private var layoutMode: ProductListLayoutMode {
        ProductListLayoutMode(rawValue: layoutRaw) ?? .tiles
    }

    private var usesTileLayout: Bool {
        supportsLayoutToggle && layoutMode == .tiles
    }

    private var loadsProductMetrics: Bool {
        supportsLayoutToggle
    }

    private let tileColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var showsMenus: Bool {
        let selected = catalogGroups.filter { selectedGroupIds.contains($0.id) }
        return selected.count == 1 && selected[0].kind == .menus
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
        let productGroupIds = Set(
            catalogGroups
                .filter { selectedGroupIds.contains($0.id) && $0.kind != .menus }
                .map(\.id)
        )
        if !productGroupIds.isEmpty {
            base = base.filter { product in
                guard let groups = groupIdsByProduct[product.id] else { return false }
                return !groups.isDisjoint(with: productGroupIds)
            }
        }
        if scope == .articles, !selectedCategoryRaws.isEmpty {
            base = base.filter { selectedCategoryRaws.contains($0.tip.rawValue) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || Self.matchesCode(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    private var selectedCategoryTitle: String {
        if selectedCategoryRaws.isEmpty {
            return L10n.tr("module.products.filter_categories_all")
        }
        if selectedCategoryRaws.count == 1,
           let raw = selectedCategoryRaws.first,
           let kind = ProductKind(rawValue: raw) {
            return kind.label
        }
        return L10n.tr("module.products.filter_categories_count", selectedCategoryRaws.count)
    }

    private var selectedGroupTitle: String {
        let names = catalogGroups.filter { selectedGroupIds.contains($0.id) }.map(\.name)
        if names.isEmpty {
            return L10n.tr("module.products.filter_group_all")
        }
        if names.count == 1 {
            return names[0]
        }
        return L10n.tr("module.products.filter_groups_count", names.count)
    }

    private func groupSelection(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedGroupIds.contains(id) },
            set: { isOn in
                if isOn {
                    selectedGroupIds.insert(id)
                } else {
                    selectedGroupIds.remove(id)
                }
            }
        )
    }

    private func categorySelection(_ raw: String) -> Binding<Bool> {
        Binding(
            get: { selectedCategoryRaws.contains(raw) },
            set: { isOn in
                if isOn {
                    selectedCategoryRaws.insert(raw)
                } else {
                    selectedCategoryRaws.remove(raw)
                }
            }
        )
    }

    private func filterCapsule(_ title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .appControlHint(hint)
    }

    private var listToolbarBar: some View {
        HStack(spacing: 10) {
            if scope == .articles {
                filterCapsule(selectedGroupTitle, hint: L10n.tr("common.filter") + ": " + selectedGroupTitle) {
                    showGroupFilter = true
                }
                .popover(isPresented: $showGroupFilter, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(L10n.tr("module.products.filter_group_all")) {
                            selectedGroupIds = []
                        }
                        ForEach(catalogGroups) { group in
                            Toggle(group.name, isOn: groupSelection(group.id))
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 220)
                }
            }

            if scope == .articles, !showsMenus {
                filterCapsule(selectedCategoryTitle, hint: L10n.tr("common.filter") + ": " + selectedCategoryTitle) {
                    showCategoryFilter = true
                }
                .popover(isPresented: $showCategoryFilter, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(L10n.tr("module.products.filter_categories_all")) {
                            selectedCategoryRaws = []
                        }
                        ForEach(ProductKind.articleCategories) { kind in
                            Toggle(kind.label, isOn: categorySelection(kind.rawValue))
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 220)
                }

                Text(articlesCountLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(AppColors.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .appControlHint(articlesCountLabel)
            }

            Spacer(minLength: 8)

            if supportsLayoutToggle, !showsMenus {
                Picker(L10n.tr("module.products.layout_picker"), selection: layoutSelection) {
                    ForEach(ProductListLayoutMode.allCases, id: \.rawValue) { mode in
                        Image(systemName: mode.systemImage)
                            .tag(mode.rawValue)
                            .appControlHint(layoutAccessibilityLabel(mode))
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 120)
                .appControlHint(L10n.tr("module.products.layout_picker"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var articlesCountLabel: String {
        let total = products.count
        let visible = filteredProducts.count
        if visible != total {
            return L10n.tr("module.products.articles_count_filtered", visible, total)
        }
        return L10n.tr("module.products.articles_count", total)
    }

    private var layoutSelection: Binding<String> {
        Binding(
            get: { layoutRaw },
            set: { layoutRaw = $0 }
        )
    }

    private func layoutAccessibilityLabel(_ mode: ProductListLayoutMode) -> String {
        switch mode {
        case .tiles: return L10n.tr("module.products.layout_tiles")
        case .list: return L10n.tr("module.products.layout_list")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if scope == .articles || supportsLayoutToggle {
                listToolbarBar
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
                                    locationStocks: locationStockByProductId[product.id] ?? [],
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
                        ProductRowView(
                            product: product,
                            stockQuantity: stockByProductId[product.id] ?? 0,
                            locationStocks: locationStockByProductId[product.id] ?? []
                        ) {
                            selectedProduct = product
                        }
                    }
                    .listStyle(.plain)
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
                FloatingAddIconButton { showCreateMenu = true }
            } else if allowsCreate {
                FloatingAddIconButton { showCreate = true }
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
            locationStockByProductId = [:]
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
                    selectedGroupIds = Set(selectedGroupIds.filter { id in
                        catalogGroups.contains(where: { $0.id == id })
                    })
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
                selectedGroupIds = []
            }
            if loadsProductMetrics {
                let stockRows = try await InventoryService.fetchStockRows(companyId: companyId)
                stockByProductId = Dictionary(uniqueKeysWithValues: stockRows.map { ($0.productId, $0.cantitate) })
                locationStockByProductId = try await InventoryService.fetchLocationStocksByProduct(
                    companyId: companyId,
                    productIds: products.map(\.id)
                )
                productionCostByProductId = try await ProductRecipeService.fetchProductionCosts(companyId: companyId)
                purchasePriceByProductId = try await ProductRecipeService.fetchLatestPurchasePrices(companyId: companyId)
            } else {
                stockByProductId = [:]
                locationStockByProductId = [:]
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
            locationStockByProductId = [:]
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
    var stockQuantity: Decimal = 0
    var locationStocks: [ProductLocationStock] = []
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(product.denumire)
                    .font(.headline)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("module.products.tile_sale_price", SupplierFormatting.amountString(product.pretVanzare)))
                    Text(L10n.tr("module.products.tile_sale_price_online", SupplierFormatting.amountString(product.pretVanzareOnline)))
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(.blue)

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

                if !locationStocks.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(locationStocks) { line in
                            Text(
                                L10n.tr(
                                    "module.products.tile_stock_location",
                                    line.locationName,
                                    SupplierFormatting.amountString(line.quantity),
                                    product.unitateMasura
                                )
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.secondary)
                        }
                    }
                } else {
                    Text(
                        L10n.tr(
                            "module.products.tile_stock",
                            SupplierFormatting.amountString(stockQuantity),
                            product.unitateMasura
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.secondary)
                }

                Text(
                    L10n.tr(
                        "module.products.tile_min_stock",
                        SupplierFormatting.amountString(product.cantitateMinima),
                        product.unitateMasura
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.secondary)

                Text(
                    L10n.tr(
                        "module.products.tile_optimal_stock",
                        SupplierFormatting.amountString(product.cantitateOptima),
                        product.unitateMasura
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.secondary)

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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
                    Text(L10n.tr("module.products.tile_sale_price", SupplierFormatting.amountString(menu.pretVanzare)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.secondary)
                    Text(L10n.tr("module.products.tile_sale_price_online", SupplierFormatting.amountString(menu.pretVanzareOnline)))
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
                .appControlHint("Șterge meniul")
            }
        }
    }
}
