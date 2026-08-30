import SwiftUI

struct ProductRecipeIngredientPickerView: View {
    let productId: UUID
    let companyId: UUID
    let existingIngredientIds: Set<UUID>
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var quantityText = ""
    @State private var unitText = ""

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
                    ingredientList
                } else {
                    quantityForm
                }
            }
            .navigationTitle(selectedProduct == nil
                ? L10n.tr("products.recipe_select_ingredient")
                : L10n.tr("products.recipe_add_line"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectedProduct == nil ? L10n.tr("common.cancel") : L10n.tr("common.back")) {
                        if selectedProduct == nil {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            selectedProduct = nil
                            quantityText = ""
                            unitText = ""
                            errorMessage = nil
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedProduct != nil {
                        Button(L10n.tr("common.save")) {
                            Task { await saveLine() }
                        }
                        .disabled(isSaving || parsedQuantity == nil || normalizedUnitText.isEmpty)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
            .appTask { await loadProducts() }
        }
    }

    @ViewBuilder
    private var ingredientList: some View {
        Group {
            if filteredProducts.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("products.recipe_no_ingredients"),
                    systemImage: "leaf",
                    description: Text(L10n.tr("products.recipe_no_ingredients_hint"))
                )
            } else {
                List(filteredProducts) { product in
                    Button {
                        selectedProduct = product
                        quantityText = ""
                        unitText = product.unitateMasura
                        errorMessage = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.denumire)
                                .font(.headline)
                                .foregroundColor(AppColors.primary)
                            HStack(spacing: 8) {
                                Text(product.tip.label)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondary)
                                if let cod = product.cod, !cod.isEmpty {
                                    Text(cod)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                Text(product.unitateMasura)
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
            }
        }
    }

    @ViewBuilder
    private var quantityForm: some View {
        Form {
            if let selectedProduct {
                Section {
                    Text(selectedProduct.denumire)
                    if let cod = selectedProduct.cod, !cod.isEmpty {
                        Text(cod)
                            .foregroundColor(AppColors.secondary)
                    }
                    Text(selectedProduct.tip.label)
                        .foregroundColor(AppColors.secondary)
                } header: {
                    Text(L10n.tr("products.recipe_select_ingredient"))
                }

                Section {
                    FormTextField(
                        title: L10n.tr("products.recipe_field_quantity_plain"),
                        text: $quantityText,
                        keyboardType: .decimalPad,
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )
                    FormTextField(
                        title: L10n.tr("products.recipe_field_unit"),
                        text: $unitText,
                        autocapitalization: .never,
                        autocorrectionDisabled: true
                    )
                } footer: {
                    Text(SupplierFormatting.invoiceAmountHint)
                }
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

    private var normalizedUnitText: String {
        ProductRecipeService.normalizedUnit(unitText)
    }

    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await ProductRecipeService.fetchIngredientCandidates(
                companyId: companyId,
                productId: productId,
                existingIngredientIds: existingIngredientIds
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLine() async {
        guard let selectedProduct, let cantitate = parsedQuantity else { return }
        let unit = normalizedUnitText
        guard !unit.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await ProductRecipeService.addLine(
                companyId: companyId,
                productId: productId,
                ingredientProductId: selectedProduct.id,
                cantitate: cantitate,
                unitateMasura: unit
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProductRecipeLineEditView: View {
    let productId: UUID
    let companyId: UUID
    let line: ProductRecipeLine
    let occupiedIngredientIds: Set<UUID>
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedIngredient: Product?
    @State private var quantityText: String
    @State private var unitText: String
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isLoadingCandidates = false
    @State private var showIngredientPicker = false
    @State private var showDeleteConfirm = false
    @State private var candidateProducts: [Product] = []
    @State private var searchText = ""
    @State private var errorMessage: String?

    init(
        productId: UUID,
        companyId: UUID,
        line: ProductRecipeLine,
        occupiedIngredientIds: Set<UUID>,
        onSaved: @escaping () async -> Void
    ) {
        self.productId = productId
        self.companyId = companyId
        self.line = line
        self.occupiedIngredientIds = occupiedIngredientIds
        self.onSaved = onSaved
        _quantityText = State(initialValue: SupplierFormatting.amountString(line.cantitate))
        _unitText = State(initialValue: line.unitateMasura)
    }

    private var pickerBlockedIngredientIds: Set<UUID> {
        occupiedIngredientIds.subtracting([line.ingredientProductId])
    }

    private var filteredCandidates: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidateProducts }
        return candidateProducts.filter { product in
            product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(product.cod, query: query)
                || BarcodeMatching.matchesField(product.codBare, query: query)
        }
    }

    private var normalizedUnitText: String {
        ProductRecipeService.normalizedUnit(unitText)
    }

    private var parsedQuantity: Decimal? {
        SupplierFormatting.parseAmount(
            quantityText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }

    private var canSave: Bool {
        selectedIngredient != nil
            && parsedQuantity != nil
            && !normalizedUnitText.isEmpty
            && !isSaving
            && !isDeleting
    }

    var body: some View {
        NavigationView {
            Group {
                if showIngredientPicker {
                    ingredientPickerContent
                } else {
                    editFormContent
                }
            }
            .navigationTitle(showIngredientPicker
                ? L10n.tr("products.recipe_select_ingredient")
                : L10n.tr("products.recipe_edit_line"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(showIngredientPicker ? L10n.tr("common.back") : L10n.tr("common.cancel")) {
                        if showIngredientPicker {
                            showIngredientPicker = false
                            searchText = ""
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !showIngredientPicker {
                        Button(L10n.tr("common.save")) {
                            Task { await saveLine() }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isSaving || isDeleting || isLoadingCandidates) }
            .appTask {
                await loadCurrentIngredient()
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text(L10n.tr("products.recipe_delete_line_title")),
                    message: Text(L10n.tr("products.recipe_delete_line_message")),
                    primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                        Task { await deleteLine() }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    @ViewBuilder
    private var editFormContent: some View {
        Form {
            Section {
                if let selectedIngredient {
                    Text(selectedIngredient.denumire)
                    Text(selectedIngredient.tip.label)
                        .foregroundColor(AppColors.secondary)
                    if let cod = selectedIngredient.cod, !cod.isEmpty {
                        Text(cod)
                            .foregroundColor(AppColors.secondary)
                    }
                } else {
                    Text(line.ingredient?.denumire ?? L10n.tr("products.recipe_unknown_ingredient"))
                }

                Button(L10n.tr("products.recipe_change_ingredient")) {
                    Task { await openIngredientPicker() }
                }
            } header: {
                Text(L10n.tr("products.recipe_select_ingredient"))
            }

            Section {
                FormTextField(
                    title: L10n.tr("products.recipe_field_quantity_plain"),
                    text: $quantityText,
                    keyboardType: .decimalPad,
                    autocapitalization: .never,
                    autocorrectionDisabled: true
                )
                FormTextField(
                    title: L10n.tr("products.recipe_field_unit"),
                    text: $unitText,
                    autocapitalization: .never,
                    autocorrectionDisabled: true
                )
            } footer: {
                Text(SupplierFormatting.invoiceAmountHint)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(L10n.tr("products.recipe_delete_line"))
                }
                .disabled(isSaving || isDeleting)
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

    @ViewBuilder
    private var ingredientPickerContent: some View {
        Group {
            if filteredCandidates.isEmpty && !isLoadingCandidates {
                AppEmptyStateView(
                    L10n.tr("products.recipe_no_ingredients"),
                    systemImage: "leaf",
                    description: Text(L10n.tr("products.recipe_no_ingredients_hint"))
                )
            } else {
                List(filteredCandidates) { product in
                    Button {
                        selectedIngredient = product
                        if unitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            unitText = product.unitateMasura
                        }
                        showIngredientPicker = false
                        searchText = ""
                        errorMessage = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.denumire)
                                .font(.headline)
                                .foregroundColor(AppColors.primary)
                            HStack(spacing: 8) {
                                Text(product.tip.label)
                                    .font(.caption2)
                                    .foregroundColor(AppColors.secondary)
                                if let cod = product.cod, !cod.isEmpty {
                                    Text(cod)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                Text(product.unitateMasura)
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
            }
        }
    }

    private func loadCurrentIngredient() async {
        if let ingredient = line.ingredient {
            selectedIngredient = try? await ProductService.fetchProduct(id: ingredient.id)
        }
        if selectedIngredient == nil {
            selectedIngredient = try? await ProductService.fetchProduct(id: line.ingredientProductId)
        }
    }

    private func openIngredientPicker() async {
        isLoadingCandidates = true
        errorMessage = nil
        defer { isLoadingCandidates = false }

        do {
            candidateProducts = try await ProductRecipeService.fetchIngredientCandidates(
                companyId: companyId,
                productId: productId,
                existingIngredientIds: pickerBlockedIngredientIds,
                additionallyAllowedIngredientIds: [line.ingredientProductId]
            )
            showIngredientPicker = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLine() async {
        guard let selectedIngredient, let cantitate = parsedQuantity else { return }
        let unit = normalizedUnitText
        guard !unit.isEmpty else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await ProductRecipeService.updateLine(
                lineId: line.id,
                productId: productId,
                companyId: companyId,
                ingredientProductId: selectedIngredient.id,
                cantitate: cantitate,
                unitateMasura: unit
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteLine() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await ProductRecipeService.deleteLine(lineId: line.id, productId: productId)
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
