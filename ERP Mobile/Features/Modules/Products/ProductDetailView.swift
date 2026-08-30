import SwiftUI

struct ProductDetailView: View {
    let product: Product
    let canEdit: Bool
    let canDelete: Bool
    let onSaved: () -> Void
    let onDeleted: () -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var denumire: String
    @State private var cod: String
    @State private var codBare: String
    @State private var unitateMasura: String
    @State private var unitateAchizitie: String
    @State private var factorConversieText: String
    @State private var tip: ProductKind
    @State private var inCatalog: Bool
    @State private var inStockSheet: Bool
    @State private var hasRecipe: Bool
    @State private var selectedVatRate: Decimal
    @State private var pretVanzareText: String
    @State private var imagineUrl: String?
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var isUploadingImage = false
    @State private var isSearchingImageOnline = false
    @State private var isLookingUpName = false
    @State private var isCheckingDelete = true
    @State private var deleteBlocker: ProductDeleteBlocker?
    @State private var showDeleteConfirm = false
    @State private var showFieldScanner = false
    @State private var recipeEditorSheet: ProductRecipeEditorSheet?
    @State private var recipeReloadToken = UUID()
    @State private var errorMessage: String?
    @State private var lookupMessage: String?

    private var isVatPayer: Bool {
        companyManager.currentCompany?.isVatPayer ?? true
    }

    private var canDeleteProduct: Bool {
        canDelete && deleteBlocker == nil
    }

    private var hasImageSearchInput: Bool {
        !denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !codBare.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        product: Product,
        canEdit: Bool,
        canDelete: Bool,
        onSaved: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.product = product
        self.canEdit = canEdit
        self.canDelete = canDelete
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _denumire = State(initialValue: product.denumire)
        _cod = State(initialValue: product.cod ?? "")
        _codBare = State(initialValue: product.codBare ?? "")
        _unitateMasura = State(initialValue: product.unitateMasura)
        _unitateAchizitie = State(initialValue: product.unitateAchizitie ?? "")
        _factorConversieText = State(initialValue: SupplierFormatting.amountString(product.factorConversie))
        _tip = State(initialValue: product.tip)
        _inCatalog = State(initialValue: product.inCatalog)
        _inStockSheet = State(initialValue: product.inStockSheet)
        _hasRecipe = State(initialValue: product.hasRecipe)
        _selectedVatRate = State(initialValue: product.cotaTva)
        _pretVanzareText = State(initialValue: product.pretVanzareInputText)
        _imagineUrl = State(initialValue: product.imagineUrl)
    }

    var body: some View {
        NavigationView {
            List {
                imageSection
                categorySection
                identitySection
                pricingSection
                catalogSection
                recipeSection

                if canDeleteProduct {
                    Section {
                        Button(L10n.tr("common.delete")) {
                            showDeleteConfirm = true
                        }
                        .disabled(isSaving)
                    }
                }

                if canDelete && !isCheckingDelete, let deleteBlocker {
                    Section {
                        Text(deleteBlocker.localizedMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }

                if isSaving || isLookingUpName || isUploadingImage || isSearchingImageOnline {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("module.products.detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canEdit {
                        Button(L10n.tr("common.save")) {
                            Task { await saveAll() }
                        }
                        .disabled(isSaving || isLookingUpName || isUploadingImage || isSearchingImageOnline || denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .appSafeAreaInsetBottom {
                VStack(spacing: 4) {
                    if let lookupMessage {
                        Text(lookupMessage)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .appBarBackground()
            }
            .onAppear {
                selectedVatRate = ProductVATRates.normalizedRate(product.cotaTva, isVatPayer: isVatPayer)
            }
            .appTask {
                await refreshDeleteStatus()
            }
            .sheet(isPresented: $showFieldScanner) {
                BarcodeScannerSheet { code in
                    codBare = BarcodeMatching.normalize(code)
                    Task { await lookupNameFromBarcode() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker(isPresented: $showCamera) { data in
                    Task { await uploadImageData(data, contentType: "image/jpeg") }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoLibraryPicker(isPresented: $showPhotoLibrary) { data, contentType in
                    Task { await uploadImageData(data, contentType: contentType) }
                }
            }
            .fullScreenCover(item: $recipeEditorSheet) { sheet in
                switch sheet {
                case .add(let existingIngredientIds):
                    ProductRecipeIngredientPickerView(
                        productId: product.id,
                        companyId: product.companyId,
                        existingIngredientIds: existingIngredientIds,
                        onSaved: {
                            recipeReloadToken = UUID()
                            if !hasRecipe {
                                hasRecipe = true
                            }
                            if let updated = try? await ProductService.fetchProduct(id: product.id) {
                                hasRecipe = updated.hasRecipe
                            }
                        }
                    )
                case .edit(let line, let occupiedIngredientIds):
                    ProductRecipeLineEditView(
                        productId: product.id,
                        companyId: product.companyId,
                        line: line,
                        occupiedIngredientIds: occupiedIngredientIds
                    ) {
                        recipeReloadToken = UUID()
                        if let updated = try? await ProductService.fetchProduct(id: product.id) {
                            hasRecipe = updated.hasRecipe
                        }
                    }
                }
            }
            .alert(isPresented: $showDeleteConfirm) {
                Alert(
                    title: Text(L10n.tr("module.products.delete_confirm_title")),
                    message: Text(L10n.tr("module.products.delete_confirm_message", denumire)),
                    primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                        Task { await deleteProduct() }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private var imageSection: some View {
        Section(header: Text(L10n.tr("module.products.section_image"))) {
            ProductThumbnailView(imagineUrl: imagineUrl)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if canEdit {
                Button {
                    showPhotoLibrary = true
                } label: {
                    Label(L10n.tr("module.products.pick_image_gallery"), systemImage: "photo.on.rectangle.angled")
                }
                .disabled(isSaving || isUploadingImage || isSearchingImageOnline)

                if CameraImagePickerSupport.isAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label(L10n.tr("module.products.take_photo"), systemImage: "camera")
                    }
                    .disabled(isSaving || isUploadingImage || isSearchingImageOnline)
                }

                if hasImageSearchInput {
                    Button {
                        Task { await findImageOnline() }
                    } label: {
                        Label(L10n.tr("module.products.find_image_online"), systemImage: "globe")
                    }
                    .disabled(isSaving || isUploadingImage || isSearchingImageOnline)
                }

                if imagineUrl != nil {
                    Button(L10n.tr("module.products.remove_image")) {
                        Task { await removeImage() }
                    }
                    .disabled(isSaving || isUploadingImage || isSearchingImageOnline)
                }
            } else if imagineUrl == nil {
                Text(L10n.tr("module.products.no_image"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
    }

    @ViewBuilder
    private var identitySection: some View {
        Section(header: Text(L10n.tr("module.products.section_identity"))) {
            if canEdit {
                FormTextField(title: L10n.tr("module.products.field_name"), text: $denumire, isRequired: true)
                FormTextField(title: L10n.tr("module.products.field_code"), text: $cod, autocapitalization: .characters)
                FormTextField(
                    title: L10n.tr("inventory.physical_field_barcode"),
                    text: $codBare,
                    keyboardType: .asciiCapable,
                    autocapitalization: .never
                )
                Button {
                    showFieldScanner = true
                } label: {
                    Label(L10n.tr("module.products.scan_fill_barcode"), systemImage: "barcode.viewfinder")
                }
                .disabled(isSaving || isLookingUpName)

                if !codBare.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        Task { await lookupNameFromBarcode() }
                    } label: {
                        Label(L10n.tr("module.products.lookup_name_from_barcode"), systemImage: "magnifyingglass")
                    }
                    .disabled(isSaving || isLookingUpName)
                }

                ProductMeasureUnitFields(
                    stockUnit: $unitateMasura,
                    purchaseUnit: $unitateAchizitie,
                    factorText: $factorConversieText,
                    canEdit: true
                )
            } else {
                AppLabeledContent(L10n.tr("module.products.field_name"), value: denumire)
                if !cod.isEmpty {
                    AppLabeledContent(L10n.tr("module.products.field_code"), value: cod)
                }
                if !codBare.isEmpty {
                    AppLabeledContent(L10n.tr("inventory.physical_field_barcode"), value: codBare)
                }
                ProductMeasureUnitFields(
                    stockUnit: $unitateMasura,
                    purchaseUnit: $unitateAchizitie,
                    factorText: $factorConversieText,
                    canEdit: false
                )
            }
        }
    }

    private var categorySection: some View {
        Section(header: Text(L10n.tr("products.section_category"))) {
            if canEdit {
                Picker(L10n.tr("products.field_category"), selection: categoryBinding) {
                    ForEach(ProductKind.articleCategories) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .disabled(isSaving)
            } else {
                AppLabeledContent(L10n.tr("products.field_category"), value: tip.label)
            }
        }
    }

    private var categoryBinding: Binding<ProductKind> {
        Binding(
            get: { tip.isArticleCategory ? tip : .materiePrima },
            set: { newValue in
                Task { await updateCategory(newValue) }
            }
        )
    }

    private var pricingSection: some View {
        Section {
            ProductPricingFields(
                unit: unitateMasura,
                isVatPayer: isVatPayer,
                canEdit: canEdit,
                selectedVatRate: $selectedVatRate,
                pretVanzareText: $pretVanzareText,
                isSaving: isSaving,
                showsSaveButton: false,
                onSave: {}
            )
        }
    }

    private var catalogSection: some View {
        Section(header: Text(L10n.tr("products.section_catalog_recipe"))) {
            Toggle(L10n.tr("products.field_in_catalog"), isOn: catalogBinding)
                .disabled(!canEdit || isSaving)
            Toggle(L10n.tr("products.field_in_stock_sheet"), isOn: stockSheetBinding)
                .disabled(!canEdit || isSaving)
            Toggle(L10n.tr("products.field_has_recipe"), isOn: recipeBinding)
                .disabled(!canEdit || isSaving)
        }
    }

    @ViewBuilder
    private var recipeSection: some View {
        if canEdit || hasRecipe || product.hasRecipe {
            ProductRecipeEditorView(
                product: product,
                canEdit: canEdit,
                reloadToken: recipeReloadToken,
                onAddLine: { existingIngredientIds in
                    recipeEditorSheet = .add(existingIngredientIds: existingIngredientIds)
                },
                onEditLine: { line, occupiedIngredientIds in
                    recipeEditorSheet = .edit(line: line, occupiedIngredientIds: occupiedIngredientIds)
                },
                onRecipeChanged: {
                    if !hasRecipe {
                        hasRecipe = true
                    }
                }
            )
        }
    }

    private var catalogBinding: Binding<Bool> {
        Binding(
            get: { inCatalog },
            set: { newValue in
                Task { await updateInCatalog(newValue) }
            }
        )
    }

    private var stockSheetBinding: Binding<Bool> {
        Binding(
            get: { inStockSheet },
            set: { newValue in
                Task { await updateInStockSheet(newValue) }
            }
        )
    }

    private var recipeBinding: Binding<Bool> {
        Binding(
            get: { hasRecipe },
            set: { newValue in
                Task { await updateHasRecipe(newValue) }
            }
        )
    }

    private func refreshDeleteStatus() async {
        guard canDelete else {
            isCheckingDelete = false
            return
        }
        isCheckingDelete = true
        deleteBlocker = try? await ProductService.deletionBlocker(productId: product.id)
        isCheckingDelete = false
    }

    private func lookupNameFromBarcode() async {
        let barcode = codBare.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !barcode.isEmpty else { return }
        isLookingUpName = true
        errorMessage = nil
        lookupMessage = nil
        defer { isLookingUpName = false }

        if let name = await ProductService.lookupName(forBarcode: barcode) {
            denumire = name
            lookupMessage = L10n.tr("module.products.lookup_name_found", name)
        } else {
            lookupMessage = L10n.tr("module.products.lookup_name_not_found")
        }

        if imagineUrl == nil,
           let lookup = await ProductService.lookup(forBarcode: barcode),
           let imageURL = lookup.imageURL {
            do {
                let updated = try await ProductService.updateImage(
                    productId: product.id,
                    imagineUrl: imageURL
                )
                imagineUrl = updated.imagineUrl
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func findImageOnline() async {
        guard canEdit else { return }

        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBarcode = codBare.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty || !trimmedBarcode.isEmpty else {
            lookupMessage = L10n.tr("module.products.find_image_online_missing_fields")
            return
        }

        isSearchingImageOnline = true
        errorMessage = nil
        lookupMessage = nil
        defer { isSearchingImageOnline = false }

        if let imageURL = await ProductService.lookupImageOnline(
            name: trimmedName,
            barcode: trimmedBarcode.isEmpty ? nil : trimmedBarcode
        ) {
            do {
                let updated = try await ProductService.updateImage(
                    productId: product.id,
                    imagineUrl: imageURL
                )
                imagineUrl = updated.imagineUrl
                lookupMessage = L10n.tr("module.products.find_image_online_found")
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            lookupMessage = L10n.tr("module.products.find_image_online_not_found")
        }
    }

    private func uploadImageData(_ data: Data, contentType: String) async {
        guard canEdit, let companyId = companyManager.currentCompany?.id else { return }
        isUploadingImage = true
        errorMessage = nil
        defer { isUploadingImage = false }

        do {
            let updated = try await ProductService.uploadImage(
                companyId: companyId,
                productId: product.id,
                imageData: data,
                contentType: contentType,
                previousImagineUrl: imagineUrl
            )
            imagineUrl = updated.imagineUrl
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeImage() async {
        guard canEdit else { return }
        isUploadingImage = true
        errorMessage = nil
        defer { isUploadingImage = false }

        do {
            let updated = try await ProductService.removeImage(
                productId: product.id,
                imagineUrl: imagineUrl
            )
            imagineUrl = updated.imagineUrl
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAll() async {
        guard canEdit, let companyId = companyManager.currentCompany?.id else { return }

        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = ProductCreateError.missingName.localizedDescription
            return
        }
        guard let pretVanzare = ProductService.parseSalePrice(pretVanzareText) else {
            errorMessage = ProductCreateError.invalidSalePrice.localizedDescription
            return
        }
        let parsedFactor = SupplierFormatting.parseAmount(
            factorConversieText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
        guard let factorConversie = parsedFactor, factorConversie > 0 else {
            errorMessage = L10n.tr("products.error_invalid_conversion_factor")
            return
        }

        let vatRate = ProductVATRates.normalizedRate(selectedVatRate, isVatPayer: isVatPayer)
        isSaving = true
        errorMessage = nil
        lookupMessage = nil
        defer { isSaving = false }

        do {
            let updatedDetails = try await ProductService.updateDetails(
                productId: product.id,
                companyId: companyId,
                input: ProductUpdateInput(
                    denumire: denumire,
                    cod: cod,
                    codBare: codBare,
                    unitateMasura: unitateMasura,
                    unitateAchizitie: unitateAchizitie,
                    factorConversie: factorConversie,
                    tip: tip
                )
            )
            applyUpdatedProduct(updatedDetails)

            if tip.impliesInCatalog && !inCatalog {
                let catalogUpdated = try await ProductService.updateCatalogSettings(
                    productId: product.id,
                    inCatalog: true
                )
                inCatalog = catalogUpdated.inCatalog
            }

            let updatedPricing = try await ProductService.updatePricing(
                productId: product.id,
                cotaTva: vatRate,
                pretVanzare: pretVanzare,
                isVatPayer: isVatPayer
            )
            selectedVatRate = ProductVATRates.normalizedRate(updatedPricing.cotaTva, isVatPayer: isVatPayer)
            pretVanzareText = updatedPricing.pretVanzareInputText

            onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateCategory(_ value: ProductKind) async {
        guard canEdit else { return }
        let previous = tip
        let previousInCatalog = inCatalog
        tip = value
        if value.impliesInCatalog {
            inCatalog = true
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await ProductService.updateArticleCategory(productId: product.id, tip: value)
            tip = updated.tip
            inCatalog = updated.inCatalog
            errorMessage = nil
            onSaved()
        } catch {
            tip = previous
            inCatalog = previousInCatalog
            errorMessage = error.localizedDescription
        }
    }

    private func updateInCatalog(_ value: Bool) async {
        guard canEdit else { return }
        let previous = inCatalog
        inCatalog = value
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await ProductService.updateCatalogSettings(
                productId: product.id,
                inCatalog: value
            )
            inCatalog = updated.inCatalog
            errorMessage = nil
            onSaved()
        } catch {
            inCatalog = previous
            errorMessage = error.localizedDescription
        }
    }

    private func updateInStockSheet(_ value: Bool) async {
        guard canEdit else { return }
        let previous = inStockSheet
        inStockSheet = value
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await ProductService.updateCatalogSettings(
                productId: product.id,
                inStockSheet: value
            )
            inStockSheet = updated.inStockSheet
            errorMessage = nil
            onSaved()
        } catch {
            inStockSheet = previous
            errorMessage = error.localizedDescription
        }
    }

    private func updateHasRecipe(_ value: Bool) async {
        guard canEdit else { return }
        let previous = hasRecipe
        hasRecipe = value
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await ProductService.updateCatalogSettings(
                productId: product.id,
                hasRecipe: value
            )
            hasRecipe = updated.hasRecipe
            errorMessage = nil
            onSaved()
        } catch {
            hasRecipe = previous
            errorMessage = error.localizedDescription
        }
    }

    private func deleteProduct() async {
        guard canDeleteProduct else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await ProductService.deleteProduct(productId: product.id)
            onDeleted()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
            await refreshDeleteStatus()
        }
    }

    private func applyUpdatedProduct(_ updated: Product) {
        denumire = updated.denumire
        cod = updated.cod ?? ""
        codBare = updated.codBare ?? ""
        unitateMasura = updated.unitateMasura
        unitateAchizitie = updated.unitateAchizitie ?? ""
        factorConversieText = SupplierFormatting.amountString(updated.factorConversie)
        tip = updated.tip
        imagineUrl = updated.imagineUrl
    }
}
