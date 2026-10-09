import SwiftUI

enum ProductSaleAddonEditorSheet: Identifiable {
    case add(existingAddonIds: Set<UUID>)
    case edit(addon: ProductSaleAddon)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let addon):
            return addon.id.uuidString
        }
    }
}

struct ProductSaleAddonsEditorView: View {
    let product: Product
    let canEdit: Bool
    var reloadToken: UUID = UUID()
    var onAdd: ((Set<UUID>) -> Void)?
    var onEdit: ((ProductSaleAddon) -> Void)?

    @State private var addons: [ProductSaleAddon] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var existingAddonIds: Set<UUID> {
        Set(addons.map(\.addonProductId))
    }

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(L10n.tr("products.sale_addon_loading"))
                        .foregroundColor(AppColors.secondary)
                }
            } else {
                if addons.isEmpty {
                    Text(canEdit
                        ? L10n.tr("products.sale_addon_start_hint")
                        : L10n.tr("products.sale_addon_empty"))
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(addons) { addon in
                        Button {
                            guard canEdit else { return }
                            onEdit?(addon)
                        } label: {
                            addonRow(addon)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: canEdit ? deleteAddons : { _ in })
                }

                if canEdit {
                    Button {
                        onAdd?(existingAddonIds)
                    } label: {
                        Label(L10n.tr("products.sale_addon_add"), systemImage: "plus.circle")
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text(L10n.tr("products.section_sale_addons"))
        } footer: {
            Text(L10n.tr("products.sale_addon_footer_hint"))
        }
        .appTask { await load() }
        .onChangeCompat(of: reloadToken) { _, _ in
            Task { await load() }
        }
    }

    @ViewBuilder
    private func addonRow(_ addon: ProductSaleAddon) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(addon.addon?.denumire ?? L10n.tr("products.sale_addon_unknown"))
                .foregroundColor(.primary)
            HStack(spacing: 8) {
                Text(L10n.tr(
                    "products.sale_addon_qty_price",
                    SupplierFormatting.amountString(addon.cantitate),
                    SupplierFormatting.amountString(addon.addon?.pretVanzare ?? 0),
                    vatLabel(addon.addon?.cotaTva ?? 0)
                ))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                Spacer()
                if canEdit {
                    Text(L10n.tr("products.recipe_tap_to_edit"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
            }
        }
    }

    private func vatLabel(_ rate: Decimal) -> String {
        "\(NSDecimalNumber(decimal: rate).stringValue)%"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            addons = try await ProductSaleAddonService.fetchAddons(productId: product.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAddons(at offsets: IndexSet) {
        let targets = offsets.map { addons[$0] }
        Task {
            do {
                for addon in targets {
                    try await ProductSaleAddonService.deleteAddon(id: addon.id)
                }
                await load()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ProductSaleAddonPickerView: View {
    let productId: UUID
    let companyId: UUID
    let existingAddonIds: Set<UUID>
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var quantityText = "1"

    private var filteredProducts: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    private var parsedQuantity: Decimal? {
        SupplierFormatting.parseAmount(
            quantityText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }

    var body: some View {
        NavigationView {
            Group {
                if selectedProduct == nil {
                    candidateList
                } else {
                    quantityForm
                }
            }
            .navigationTitle(selectedProduct == nil
                ? L10n.tr("products.sale_addon_select")
                : L10n.tr("products.sale_addon_add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedProduct == nil ? L10n.tr("common.cancel") : L10n.tr("common.back")) {
                        if selectedProduct == nil {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            selectedProduct = nil
                            quantityText = "1"
                            errorMessage = nil
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedProduct != nil {
                        Button(L10n.tr("common.save")) {
                            Task { await save() }
                        }
                        .disabled(isSaving || parsedQuantity == nil || (parsedQuantity ?? 0) <= 0)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
            .appTask { await loadCandidates() }
            .searchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
        }
    }

    @ViewBuilder
    private var candidateList: some View {
        Group {
            if filteredProducts.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("products.sale_addon_no_candidates"),
                    systemImage: "plus.square.on.square",
                    description: Text(L10n.tr("products.sale_addon_no_candidates_hint"))
                )
            } else {
                List(filteredProducts) { product in
                    Button {
                        selectedProduct = product
                        quantityText = "1"
                        errorMessage = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.denumire)
                                .font(.headline)
                                .foregroundColor(AppColors.primary)
                            Text(L10n.tr(
                                "products.sale_addon_candidate_detail",
                                SupplierFormatting.amountString(product.pretVanzare),
                                "\(NSDecimalNumber(decimal: product.cotaTva).stringValue)%"
                            ))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
    }

    private var quantityForm: some View {
        Form {
            if let selectedProduct {
                Section(header: Text(L10n.tr("products.sale_addon_selected"))) {
                    Text(selectedProduct.denumire)
                    Text(L10n.tr(
                        "products.sale_addon_candidate_detail",
                        SupplierFormatting.amountString(selectedProduct.pretVanzare),
                        "\(NSDecimalNumber(decimal: selectedProduct.cotaTva).stringValue)%"
                    ))
                    .foregroundColor(AppColors.secondary)
                }
            }
            Section(header: Text(L10n.tr("products.sale_addon_field_quantity")), footer: Text(L10n.tr("products.sale_addon_qty_hint"))) {
                TextField("1", text: $quantityText)
                    .keyboardType(.decimalPad)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func loadCandidates() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await ProductSaleAddonService.fetchAddonCandidates(
                companyId: companyId,
                excludingProductId: productId,
                excludingAddonIds: existingAddonIds
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let selectedProduct, let qty = parsedQuantity, qty > 0 else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await ProductSaleAddonService.addAddon(
                companyId: companyId,
                productId: productId,
                addonProductId: selectedProduct.id,
                cantitate: qty
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProductSaleAddonEditView: View {
    let addon: ProductSaleAddon
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var quantityText: String
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    init(addon: ProductSaleAddon, onSaved: @escaping () async -> Void) {
        self.addon = addon
        self.onSaved = onSaved
        _quantityText = State(initialValue: SupplierFormatting.amountString(addon.cantitate))
    }

    private var parsedQuantity: Decimal? {
        SupplierFormatting.parseAmount(
            quantityText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(L10n.tr("products.sale_addon_selected"))) {
                    Text(addon.addon?.denumire ?? L10n.tr("products.sale_addon_unknown"))
                    if let ref = addon.addon {
                        Text(L10n.tr(
                            "products.sale_addon_candidate_detail",
                            SupplierFormatting.amountString(ref.pretVanzare),
                            "\(NSDecimalNumber(decimal: ref.cotaTva).stringValue)%"
                        ))
                        .foregroundColor(AppColors.secondary)
                    }
                }
                Section(header: Text(L10n.tr("products.sale_addon_field_quantity")), footer: Text(L10n.tr("products.sale_addon_qty_hint"))) {
                    TextField("1", text: $quantityText)
                        .keyboardType(.decimalPad)
                }
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text(L10n.tr("products.sale_addon_delete"))
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("products.sale_addon_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || parsedQuantity == nil || (parsedQuantity ?? 0) <= 0)
                }
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text(L10n.tr("products.sale_addon_delete_title")),
                    message: Text(L10n.tr("products.sale_addon_delete_message")),
                    primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                        Task { await deleteAddon() }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func save() async {
        guard let qty = parsedQuantity, qty > 0 else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await ProductSaleAddonService.updateQuantity(addonId: addon.id, cantitate: qty)
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAddon() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await ProductSaleAddonService.deleteAddon(id: addon.id)
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
