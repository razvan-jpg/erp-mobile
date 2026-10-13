import SwiftUI

/// Nomenclatoare → Catalog: Grupe CM + Produse din catalogul de vânzare.
struct NomenclatoareCatalogView: View {
    let canEdit: Bool
    let canCreate: Bool
    let canDelete: Bool

    @State private var selectedTab: Tab = .groups

    enum Tab: CaseIterable, Identifiable {
        case groups
        case products

        var id: String { title }

        var title: String {
            switch self {
            case .groups: return L10n.tr("module.catalog.tab_groups")
            case .products: return L10n.tr("module.catalog.tab_products")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.catalog.section_picker"), selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Group {
                switch selectedTab {
                case .groups:
                    CMGroupsListView(
                        canEdit: canEdit,
                        canCreate: canCreate,
                        canDelete: canDelete
                    )
                case .products:
                    ProductListView(
                        scope: .catalog,
                        canEdit: canEdit,
                        canDelete: canDelete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L10n.tr("module.nomenclatoare.tile.article_catalog"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Groups list

private struct CMGroupsListView: View {
    let canEdit: Bool
    let canCreate: Bool
    let canDelete: Bool

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var items: [CMProductGroupListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var newGroupName = ""
    @State private var groupToRename: CMProductGroup?
    @State private var renameText = ""
    @State private var groupToDelete: CMProductGroup?

    var body: some View {
        Group {
            if items.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.catalog.cm.groups_empty"),
                    systemImage: "square.grid.2x2",
                    description: Text(L10n.tr("module.catalog.cm.groups_empty_hint"))
                )
            } else {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            CMGroupDetailView(
                                group: item.group,
                                canEdit: canEdit,
                                canCreate: canCreate,
                                canDelete: canDelete
                            )
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.group.name)
                                        .font(.headline)
                                    Text(groupItemCountLabel(for: item))
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                    if item.group.isSystem {
                                        Text(L10n.tr("module.catalog.cm.system_group"))
                                            .font(.caption2)
                                            .foregroundColor(AppColors.tertiary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .contextMenu {
                            if item.group.canRename && canEdit {
                                Button {
                                    groupToRename = item.group
                                    renameText = item.group.name
                                } label: {
                                    Label(L10n.tr("common.edit"), systemImage: "pencil").appHoverTip(L10n.tr("common.edit"))
                                }
                            }
                            if item.group.canDelete && canDelete {
                                Button(role: .destructive) {
                                    groupToDelete = item.group
                                } label: {
                                    Label(L10n.tr("common.delete"), systemImage: "trash").appHoverTip(L10n.tr("common.delete"))
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .appScrollBottomPadding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canCreate {
                    Button {
                        newGroupName = ""
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .appControlHint(L10n.tr("common.add"))
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .onAppear { Task { await reload() } }
        .alert(L10n.tr("module.catalog.cm.create_group_title"), isPresented: $showCreate) {
            TextField(L10n.tr("module.catalog.cm.group_name"), text: $newGroupName)
            Button(L10n.tr("common.cancel"), role: .cancel) {}
            Button(L10n.tr("common.save")) {
                Task { await createGroup() }
            }
        } message: {
            Text(L10n.tr("module.catalog.cm.create_group_hint"))
        }
        .alert(L10n.tr("module.catalog.cm.rename_group_title"), isPresented: Binding(
            get: { groupToRename != nil },
            set: { if !$0 { groupToRename = nil } }
        )) {
            TextField(L10n.tr("module.catalog.cm.group_name"), text: $renameText)
            Button(L10n.tr("common.cancel"), role: .cancel) { groupToRename = nil }
            Button(L10n.tr("common.save")) {
                Task { await renameGroup() }
            }
        }
        .alert(L10n.tr("module.catalog.cm.delete_group_title"), isPresented: Binding(
            get: { groupToDelete != nil },
            set: { if !$0 { groupToDelete = nil } }
        )) {
            Button(L10n.tr("common.cancel"), role: .cancel) { groupToDelete = nil }
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            if let groupToDelete {
                Text(L10n.tr("module.catalog.cm.delete_group_confirm", groupToDelete.name))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await CMProductGroupService.fetchGroupListItems(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func groupItemCountLabel(for item: CMProductGroupListItem) -> String {
        let count = item.itemCount
        switch item.group.kind {
        case .menus:
            return count == 1
                ? L10n.tr("module.catalog.cm.menus_count_one")
                : L10n.tr("module.catalog.cm.menus_count", count)
        case .custom, .ungrouped:
            return count == 1
                ? L10n.tr("module.catalog.cm.products_count_one")
                : L10n.tr("module.catalog.cm.products_count", count)
        }
    }

    private func createGroup() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        do {
            _ = try await CMProductGroupService.createGroup(companyId: companyId, name: newGroupName)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameGroup() async {
        guard let group = groupToRename else { return }
        do {
            _ = try await CMProductGroupService.renameGroup(id: group.id, name: renameText)
            groupToRename = nil
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteGroup() async {
        guard let group = groupToDelete else { return }
        do {
            try await CMProductGroupService.deleteGroup(id: group.id)
            groupToDelete = nil
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Group detail

private struct CMGroupDetailView: View {
    let group: CMProductGroup
    let canEdit: Bool
    let canCreate: Bool
    let canDelete: Bool

    var body: some View {
        switch group.kind {
        case .custom, .ungrouped:
            CMGroupProductsView(
                group: group,
                canEdit: canEdit,
                canDelete: canDelete
            )
        case .menus:
            CMMenusListView(
                canEdit: canEdit,
                canCreate: canCreate,
                canDelete: canDelete
            )
        }
    }
}

private struct CMGroupProductsView: View {
    let group: CMProductGroup
    let canEdit: Bool
    let canDelete: Bool

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProduct: Product?
    @State private var showAddProducts = false

    private var allowsAdd: Bool {
        canEdit && group.kind == .custom
    }

    var body: some View {
        Group {
            if products.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.catalog.cm.group_products_empty"),
                    systemImage: "cube.box",
                    description: Text(
                        group.kind == .ungrouped
                            ? L10n.tr("module.catalog.cm.ungrouped_empty_hint")
                            : L10n.tr("module.catalog.cm.group_products_empty_hint")
                    )
                )
            } else {
                List {
                    ForEach(products) { product in
                        Button {
                            selectedProduct = product
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.denumire)
                                        .foregroundColor(.primary)
                                    Text(product.tip.label)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(L10n.tr("module.products.tile_sale_price", SupplierFormatting.amountString(product.pretVanzare)))
                                    Text(L10n.tr("module.products.tile_sale_price_online", SupplierFormatting.amountString(product.pretVanzareOnline)))
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        guard group.kind == .custom, canEdit else { return }
                        removeProducts(at: offsets)
                    }
                }
                .listStyle(.plain)
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if allowsAdd {
                    Button {
                        showAddProducts = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .appControlHint(L10n.tr("common.add"))
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(
                product: product,
                canEdit: canEdit,
                canDelete: canDelete,
                onSaved: { Task { await reload() } },
                onDeleted: {
                    selectedProduct = nil
                    Task { await reload() }
                }
            )
        }
        .sheet(isPresented: $showAddProducts) {
            CMAddProductsToGroupSheet(group: group) {
                Task { await reload() }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if group.kind == .ungrouped {
                products = try await CMProductGroupService.fetchUngroupedCatalogProducts(companyId: companyId)
            } else {
                products = try await CMProductGroupService.fetchProducts(inGroupId: group.id, companyId: companyId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeProducts(at offsets: IndexSet) {
        guard group.kind == .custom else { return }
        let targets = offsets.map { products[$0] }
        Task {
            do {
                for product in targets {
                    try await CMProductGroupService.removeProduct(fromGroupId: group.id, productId: product.id)
                }
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct CMAddProductsToGroupSheet: View {
    let group: CMProductGroup
    let onDone: () -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var catalog: [Product] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var existingIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var filtered: [Product] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = catalog.filter { !existingIds.contains($0.id) }
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.denumire.localizedCaseInsensitiveContains(q)
                || ($0.codBare?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            List(filtered) { product in
                Button {
                    if selectedIds.contains(product.id) {
                        selectedIds.remove(product.id)
                    } else {
                        selectedIds.insert(product.id)
                    }
                } label: {
                    HStack {
                        Text(product.denumire)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedIds.contains(product.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
            .navigationTitle(L10n.tr("module.catalog.cm.add_products_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(selectedIds.isEmpty || isSaving)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
            .appTask { await load() }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                }
            }
        }
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            catalog = try await ProductService.fetchProducts(companyId: companyId, inCatalog: true)
            let members = try await CMProductGroupService.fetchMembers(groupId: group.id)
            existingIds = Set(members.map(\.productId))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            for id in selectedIds {
                try await CMProductGroupService.addProduct(
                    toGroupId: group.id,
                    companyId: companyId,
                    productId: id
                )
            }
            onDone()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Menus

private struct CMMenusListView: View {
    let canEdit: Bool
    let canCreate: Bool
    let canDelete: Bool

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var menus: [CMMenu] = []
    @State private var menuImages: [UUID: String] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var editingMenu: CMMenu?
    @State private var menuPendingDelete: CMMenu?

    var body: some View {
        Group {
            if menus.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.catalog.cm.menus_empty"),
                    systemImage: "list.bullet.rectangle",
                    description: Text(L10n.tr("module.catalog.cm.menus_empty_hint"))
                )
            } else {
                List {
                    ForEach(menus) { menu in
                        HStack(spacing: 10) {
                            Button {
                                editingMenu = menu
                            } label: {
                                HStack(spacing: 10) {
                                    ProductThumbnailView(imagineUrl: menuImages[menu.id], contentMode: .fit)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(menu.name)
                                            .foregroundColor(.primary)
                                        if !menu.cod.isEmpty {
                                            Text(menu.cod)
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondary)
                                        }
                                        if !menu.isActive {
                                            Text(L10n.tr("common.inactive"))
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondary)
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(L10n.tr("module.products.tile_sale_price", SupplierFormatting.amountString(menu.pretVanzare)))
                                        Text(L10n.tr("module.products.tile_sale_price_online", SupplierFormatting.amountString(menu.pretVanzareOnline)))
                                    }
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            if canDelete {
                                Button {
                                    menuPendingDelete = menu
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.borderless)
                                .appControlHint(L10n.tr("common.delete"))
                            }
                        }
                    }
                    .onDelete { offsets in
                        guard canDelete else { return }
                        deleteMenus(at: offsets)
                    }
                }
                .listStyle(.plain)
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.catalog.cm.menus_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if canCreate {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                    .appControlHint(L10n.tr("common.add"))
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CMMenuEditorView(menu: nil, canEdit: true) {
                Task { await reload() }
            }
        }
        .sheet(item: $editingMenu) { menu in
            CMMenuEditorView(menu: menu, canEdit: canEdit) {
                Task { await reload() }
            }
        }
        .confirmationDialog(
            "Ștergeți meniul?",
            isPresented: Binding(
                get: { menuPendingDelete != nil },
                set: { if !$0 { menuPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Șterge", role: .destructive) {
                if let menu = menuPendingDelete,
                   let index = menus.firstIndex(where: { $0.id == menu.id }) {
                    deleteMenus(at: IndexSet(integer: index))
                }
                menuPendingDelete = nil
            }
            Button("Renunță", role: .cancel) {
                menuPendingDelete = nil
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await reload() }
        .appRefreshable { await reload() }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            menus = try await CMProductGroupService.fetchMenus(companyId: companyId)
            menuImages = (try? await CMProductGroupService.fetchMainProductImages(menuIds: menus.map(\.id))) ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMenus(at offsets: IndexSet) {
        let targets = offsets.map { menus[$0] }
        Task {
            do {
                for menu in targets {
                    try await CMProductGroupService.deleteMenu(id: menu.id)
                }
                await reload()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CMMenuEditorView: View {
    let menu: CMMenu?
    let canEdit: Bool
    let onSaved: () -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var name: String
    @State private var priceText: String
    @State private var onlinePriceText: String
    @State private var isActive: Bool
    @State private var allowsMultiple: Bool
    @State private var catalog: [Product] = []
    @State private var mainId: UUID?
    @State private var requiredSecondaryId: UUID?
    @State private var optionalIds: [UUID] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(menu: CMMenu?, canEdit: Bool, onSaved: @escaping () -> Void) {
        self.menu = menu
        self.canEdit = canEdit
        self.onSaved = onSaved
        _name = State(initialValue: menu?.name ?? "")
        _priceText = State(initialValue: menu.map { SupplierFormatting.amountString($0.pretVanzare) } ?? "")
        _onlinePriceText = State(initialValue: menu.map { SupplierFormatting.amountString($0.pretVanzareOnline) } ?? "")
        _isActive = State(initialValue: menu?.isActive ?? true)
        _allowsMultiple = State(initialValue: menu?.permiteSecundareMultiple ?? false)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("module.catalog.cm.menu_section"))) {
                    if let existing = menu, !existing.cod.isEmpty {
                        LabeledContent("Cod produs", value: existing.cod)
                    } else {
                        Text("Codul de produs se alocă automat și este unic.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    TextField(L10n.tr("module.catalog.cm.menu_name"), text: $name)
                        .disabled(!canEdit)
                    TextField(L10n.tr("module.catalog.cm.menu_sale_price"), text: $priceText)
                        .keyboardType(.decimalPad)
                        .disabled(!canEdit)
                    TextField(L10n.tr("module.catalog.cm.menu_sale_price_online"), text: $onlinePriceText)
                        .keyboardType(.decimalPad)
                        .disabled(!canEdit)
                    Toggle(L10n.tr("common.active"), isOn: $isActive)
                        .disabled(!canEdit)
                    Toggle("La vânzare se pot alege mai multe produse secundare", isOn: $allowsMultiple)
                        .disabled(!canEdit)
                }

                Section(header: Text("Produs principal")) {
                    productPicker(selection: $mainId, empty: "Alegeți produsul principal")
                }
                Section(header: Text("Produs secundar obligatoriu")) {
                    productPicker(selection: $requiredSecondaryId, empty: "Alegeți produsul secundar")
                }
                Section(header: Text("Produse secundare opționale (cel mult 10)")) {
                    ForEach(optionalIds.indices, id: \.self) { index in
                        HStack {
                            productPicker(selection: binding(for: index), empty: "Alegeți produsul")
                            if canEdit {
                                Button {
                                    optionalIds.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .appControlHint(L10n.tr("common.delete"))
                            }
                        }
                    }
                    if canEdit && optionalIds.count < 10 {
                        Button("Adaugă produs opțional") {
                            optionalIds.append(UUID())
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
            .navigationTitle(menu == nil
                ? L10n.tr("module.catalog.cm.create_menu_title")
                : L10n.tr("module.catalog.cm.edit_menu_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canEdit {
                        Button(L10n.tr("common.save")) {
                            Task { await save() }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
            .appTask { await load() }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                }
            }
        }
    }

    private func productPicker(selection: Binding<UUID?>, empty: String) -> some View {
        Picker(empty, selection: selection) {
            Text(empty).tag(Optional<UUID>.none)
            ForEach(catalog.filter { product in
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                return q.isEmpty || product.denumire.localizedCaseInsensitiveContains(q) || product.id == selection.wrappedValue
            }) { product in
                Text(product.denumire).tag(Optional(product.id))
            }
        }
        .disabled(!canEdit)
    }

    private func binding(for index: Int) -> Binding<UUID?> {
        Binding(
            get: { optionalIds.indices.contains(index) ? optionalIds[index] : nil },
            set: { newValue in
                guard optionalIds.indices.contains(index) else { return }
                optionalIds[index] = newValue ?? UUID()
            }
        )
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            catalog = try await ProductService.fetchProducts(companyId: companyId, inCatalog: true)
            if let menu {
                let lines = try await CMProductGroupService.fetchMenuLines(menuId: menu.id)
                mainId = lines.first { $0.role == "main" }?.productId
                requiredSecondaryId = lines.first { $0.role == "secondary" && $0.isRequired }?.productId
                optionalIds = lines.filter { $0.role == "secondary" && !$0.isRequired }.map(\.productId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        guard let price = ProductService.parseSalePrice(priceText) else {
            errorMessage = ProductCreateError.invalidSalePrice.localizedDescription
            return
        }
        let onlineText = onlinePriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        let onlinePrice: Decimal
        if onlineText.isEmpty {
            onlinePrice = price
        } else if let parsed = ProductService.parseSalePrice(onlineText) {
            onlinePrice = parsed
        } else {
            errorMessage = ProductCreateError.invalidSalePrice.localizedDescription
            return
        }
        guard let mainId, let requiredSecondaryId else {
            errorMessage = CMCatalogError.menuShape.localizedDescription
            return
        }
        var ids = [mainId, requiredSecondaryId]
        for id in optionalIds where catalog.contains(where: { $0.id == id }) {
            ids.append(id)
        }
        if Set(ids).count != ids.count || ids.count < 2 || optionalIds.count > 10 {
            errorMessage = CMCatalogError.menuShape.localizedDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let menu {
                _ = try await CMProductGroupService.updateMenu(
                    menuId: menu.id,
                    companyId: companyId,
                    name: name,
                    pretVanzare: price,
                    pretVanzareOnline: onlinePrice,
                isActive: isActive,
                productIds: ids,
                permiteSecundareMultiple: allowsMultiple
            )
            } else {
                _ = try await CMProductGroupService.createMenu(
                    companyId: companyId,
                    name: name,
                pretVanzare: price,
                pretVanzareOnline: onlinePrice,
                productIds: ids,
                permiteSecundareMultiple: allowsMultiple
            )
            }
            onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
