import SwiftUI

struct ProductWarehouseCardView: View {
    let context: ProductWarehouseCardContext

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var ledgerEntries: [ProductWarehouseLedgerEntry] = []
    @State private var weightedAverageCost: Decimal?
    @State private var inCatalog = false
    @State private var inStockSheet = false
    @State private var hasRecipe = false
    @State private var selectedVatRate: Decimal = 0
    @State private var pretVanzareText = ""
    @State private var isLoading = false
    @State private var isSavingProductOptions = false
    @State private var errorMessage: String?

    private var productName: String {
        context.row.product?.denumire ?? L10n.tr("inventory.unknown_product")
    }

    private var unit: String {
        context.row.product?.unitateMasura ?? "buc"
    }

    private var isVatPayer: Bool {
        companyManager.currentCompany?.isVatPayer ?? true
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    pricingCard
                    catalogRecipeCard
                    ledgerCard
                    Color.clear.frame(height: 80)
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .appScrollBottomPadding()
            .navigationTitle(L10n.tr("inventory.warehouse_card_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
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
            .appTask { await loadCard() }
            .appRefreshable { await loadCard() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(productName)
                .font(.title3.bold())

            if let barcode = context.row.product?.codBare, !barcode.isEmpty {
                HStack {
                    Text(L10n.tr("inventory.physical_field_barcode"))
                        .foregroundColor(AppColors.secondary)
                    Spacer()
                    Text(barcode)
                        .font(.headline)
                }
            }

            HStack {
                Text(L10n.tr("inventory.field_unit"))
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Text(unit)
                    .font(.headline)
            }

            HStack {
                Text(L10n.tr("inventory.field_quantity"))
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Text(stockLabel)
                    .font(.headline)
            }

            HStack {
                Text(L10n.tr("inventory.weighted_average_cost"))
                    .foregroundColor(AppColors.secondary)
                Spacer()
                Text(weightedAverageCostLabel)
                    .font(.headline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var pricingCard: some View {
        ProductPricingFields(
            unit: unit,
            isVatPayer: isVatPayer,
            canEdit: context.canEdit,
            selectedVatRate: $selectedVatRate,
            pretVanzareText: $pretVanzareText,
            isSaving: isSavingProductOptions,
            onSave: { Task { await savePricing() } }
        )
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var catalogRecipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("products.section_catalog_recipe"))
                .font(.headline)

            Text(L10n.tr("products.catalog_recipe_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)

            Toggle(isOn: catalogBinding) {
                Text(L10n.tr("products.field_in_catalog"))
            }
            .disabled(!context.canEdit || isSavingProductOptions)

            Toggle(isOn: stockSheetBinding) {
                Text(L10n.tr("products.field_in_stock_sheet"))
            }
            .disabled(!context.canEdit || isSavingProductOptions)

            Toggle(isOn: recipeBinding) {
                Text(L10n.tr("products.field_has_recipe"))
            }
            .disabled(!context.canEdit || isSavingProductOptions)

            if isSavingProductOptions {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private var ledgerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("inventory.warehouse_card_transactions"))
                .font(.headline)

            ProductWarehouseCardTableView(entries: ledgerEntries)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var stockLabel: String {
        "\(SupplierFormatting.amountString(context.row.cantitate)) \(unit)"
    }

    private var weightedAverageCostLabel: String {
        guard let weightedAverageCost else { return "—" }
        return L10n.tr("inventory.price_per_unit", SupplierFormatting.amountString(weightedAverageCost), unit)
    }

    private func loadCard() async {
        guard let companyId = companyManager.currentCompany?.id else {
            ledgerEntries = []
            weightedAverageCost = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            async let movementsTask = InventoryService.fetchProductMovements(
                companyId: companyId,
                productId: context.row.productId
            )
            async let productTask = ProductService.fetchProduct(id: context.row.productId)
            let movements = try await movementsTask
            let product = try await productTask
            let result = ProductWarehouseLedgerBuilder.build(movements: movements)
            ledgerEntries = result.entries
            weightedAverageCost = result.weightedAverageCost
            inCatalog = product.inCatalog
            inStockSheet = product.inStockSheet
            hasRecipe = product.hasRecipe
            selectedVatRate = ProductVATRates.normalizedRate(product.cotaTva, isVatPayer: isVatPayer)
            pretVanzareText = product.pretVanzareInputText
        } catch {
            ledgerEntries = []
            weightedAverageCost = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func savePricing() async {
        guard context.canEdit else { return }
        guard let pretVanzare = ProductService.parseSalePrice(pretVanzareText) else {
            errorMessage = ProductCreateError.invalidSalePrice.localizedDescription
            return
        }

        let vatRate = ProductVATRates.normalizedRate(selectedVatRate, isVatPayer: isVatPayer)
        let previousVat = selectedVatRate
        let previousPrice = pretVanzareText
        isSavingProductOptions = true
        defer { isSavingProductOptions = false }

        do {
            let product = try await ProductService.updatePricing(
                productId: context.row.productId,
                cotaTva: vatRate,
                pretVanzare: pretVanzare,
                isVatPayer: isVatPayer
            )
            selectedVatRate = ProductVATRates.normalizedRate(product.cotaTva, isVatPayer: isVatPayer)
            pretVanzareText = product.pretVanzareInputText
            errorMessage = nil
        } catch {
            selectedVatRate = previousVat
            pretVanzareText = previousPrice
            errorMessage = error.localizedDescription
        }
    }

    private func updateInCatalog(_ value: Bool) async {
        guard context.canEdit else { return }
        let previous = inCatalog
        inCatalog = value
        isSavingProductOptions = true
        defer { isSavingProductOptions = false }
        do {
            let product = try await ProductService.updateCatalogSettings(
                productId: context.row.productId,
                inCatalog: value
            )
            inCatalog = product.inCatalog
            errorMessage = nil
        } catch {
            inCatalog = previous
            errorMessage = error.localizedDescription
        }
    }

    private func updateInStockSheet(_ value: Bool) async {
        guard context.canEdit else { return }
        let previous = inStockSheet
        inStockSheet = value
        isSavingProductOptions = true
        defer { isSavingProductOptions = false }
        do {
            let product = try await ProductService.updateCatalogSettings(
                productId: context.row.productId,
                inStockSheet: value
            )
            inStockSheet = product.inStockSheet
            errorMessage = nil
        } catch {
            inStockSheet = previous
            errorMessage = error.localizedDescription
        }
    }

    private func updateHasRecipe(_ value: Bool) async {
        guard context.canEdit else { return }
        let previous = hasRecipe
        hasRecipe = value
        isSavingProductOptions = true
        defer { isSavingProductOptions = false }
        do {
            let product = try await ProductService.updateCatalogSettings(
                productId: context.row.productId,
                hasRecipe: value
            )
            hasRecipe = product.hasRecipe
            errorMessage = nil
        } catch {
            hasRecipe = previous
            errorMessage = error.localizedDescription
        }
    }
}
