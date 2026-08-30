import SwiftUI

enum ProductRecipeEditorSheet: Identifiable {
    case add(existingIngredientIds: Set<UUID>)
    case edit(line: ProductRecipeLine, occupiedIngredientIds: Set<UUID>)

    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let line, _):
            return line.id.uuidString
        }
    }
}

struct ProductRecipeEditorView: View {
    let product: Product
    let canEdit: Bool
    var reloadToken: UUID = UUID()
    var onAddLine: ((Set<UUID>) -> Void)?
    var onEditLine: ((ProductRecipeLine, Set<UUID>) -> Void)?
    var onRecipeChanged: (() -> Void)?

    @State private var lines: [ProductRecipeLine] = []
    @State private var isLoading = true
    @State private var isRefreshingPrices = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    private var summary: ProductRecipeSummary {
        ProductRecipeSummary(lines: lines)
    }

    private var existingIngredientIds: Set<UUID> {
        Set(lines.map(\.ingredientProductId))
    }

    var body: some View {
        Section {
            if isLoading {
                HStack {
                    ProgressView()
                    Text(L10n.tr("products.recipe_loading"))
                        .foregroundColor(AppColors.secondary)
                }
            } else {
                if lines.isEmpty {
                    Text(canEdit
                        ? L10n.tr("products.recipe_start_hint")
                        : L10n.tr("products.recipe_empty"))
                        .foregroundColor(AppColors.secondary)
                } else {
                    ForEach(lines) { line in
                        Button {
                            guard canEdit else { return }
                            onEditLine?(line, existingIngredientIds)
                        } label: {
                            recipeLineRow(line)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: canEdit ? deleteLines : { _ in })

                    if let totalCost = summary.totalCost {
                        HStack {
                            Text(L10n.tr("products.recipe_total_cost"))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(SupplierFormatting.amountString(totalCost))
                                .fontWeight(.semibold)
                        }
                    }
                }

                if canEdit {
                    Button {
                        onAddLine?(existingIngredientIds)
                    } label: {
                        Label(L10n.tr("products.recipe_add_line"), systemImage: "plus.circle")
                    }

                    if !lines.isEmpty {
                        Button {
                            Task { await refreshLocalPrices() }
                        } label: {
                            if isRefreshingPrices {
                                ProgressView()
                            } else {
                                Text(L10n.tr("products.recipe_refresh_prices"))
                            }
                        }
                        .disabled(isRefreshingPrices || isDeleting)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        } header: {
            Text(L10n.tr("products.section_recipe"))
        } footer: {
            Text(canEdit
                ? L10n.tr("products.recipe_edit_footer_hint")
                : L10n.tr("products.recipe_footer_hint"))
        }
        .appTask {
            await loadLines()
        }
        .onChangeCompat(of: reloadToken) { _, _ in
            Task { await loadLines() }
        }
    }

    @ViewBuilder
    private func recipeLineRow(_ line: ProductRecipeLine) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(line.ingredient?.denumire ?? L10n.tr("products.recipe_unknown_ingredient"))
                .font(.subheadline)

            HStack(spacing: 12) {
                recipeMetric(
                    title: L10n.tr("products.recipe_column_quantity"),
                    value: SupplierFormatting.amountString(line.cantitate)
                )
                recipeMetric(
                    title: L10n.tr("products.recipe_field_unit"),
                    value: line.unitateMasura
                )
                if let pret = line.pretAchizitie {
                    recipeMetric(
                        title: L10n.tr("products.recipe_column_unit_price"),
                        value: SupplierFormatting.amountString(pret)
                    )
                }
                Spacer()
                if let cost = line.lineCost {
                    recipeMetric(
                        title: L10n.tr("products.recipe_column_line_cost"),
                        value: SupplierFormatting.amountString(cost)
                    )
                }
            }

            HStack(spacing: 8) {
                if let code = line.ingredient?.cod, !code.isEmpty {
                    Text(code)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                }
                if line.pretAchizitie != nil {
                    Text(line.pretAchizitieSursa.label)
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                }
            }

            if canEdit {
                Text(L10n.tr("products.recipe_tap_to_edit"))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func recipeMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
            Text(value)
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
    }

    private func deleteLines(at offsets: IndexSet) {
        let ids = offsets.map { lines[$0].id }
        Task {
            isDeleting = true
            errorMessage = nil
            defer { isDeleting = false }

            do {
                for lineId in ids {
                    try await ProductRecipeService.deleteLine(lineId: lineId, productId: product.id)
                }
                await reloadAfterChange()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func loadLines() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            lines = try await ProductRecipeService.fetchRecipeLines(productId: product.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadAfterChange() async {
        await loadLines()
        onRecipeChanged?()
    }

    private func refreshLocalPrices() async {
        isRefreshingPrices = true
        errorMessage = nil
        defer { isRefreshingPrices = false }

        do {
            lines = try await ProductRecipeService.refreshPurchasePrices(
                companyId: product.companyId,
                productId: product.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
