import SwiftUI

struct StockSheetInitialStockView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var lines: [InitialStockDraftLine] = []
    @State private var transactionDate = Date()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showScanner = false

    private var canEdit: Bool { access.canEdit }

    private var filteredLines: [InitialStockDraftLine] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return lines }
        return lines.filter { line in
            line.product.denumire.localizedCaseInsensitiveContains(query)
                || BarcodeMatching.matchesField(line.product.cod, query: query)
                || BarcodeMatching.matchesField(line.product.codBare, query: query)
        }
    }

    private var visibleIDs: Set<UUID> {
        Set(filteredLines.map(\.id))
    }

    private var totalValue: Decimal {
        filteredLines.reduce(0) { $0 + ($1.lineValue ?? 0) }
    }

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.stock_sheet.loading_permissions"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.stock_sheet.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.stock_sheet.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else if lines.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("stock_sheet.empty"),
                    systemImage: "arrow.down.to.line.circle",
                    description: Text(L10n.tr("stock_sheet.empty_hint"))
                )
            } else {
                List {
                    Section {
                        DatePicker(
                            L10n.tr("stock_sheet.initial.date"),
                            selection: $transactionDate,
                            displayedComponents: .date
                        )
                        .disabled(!canEdit)
                    } footer: {
                        Text(L10n.tr("stock_sheet.initial.hint"))
                    }

                    Section {
                        ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                            if visibleIDs.contains(line.id) {
                                InitialStockLineRowView(
                                    product: line.product,
                                    currentStock: line.currentStock,
                                    quantityText: $lines[index].quantityText,
                                    unitPriceText: $lines[index].unitPriceText,
                                    canEdit: canEdit
                                )
                            }
                        }
                    } footer: {
                        if !filteredLines.isEmpty {
                            HStack {
                                Text(L10n.tr("stock_sheet.total"))
                                Spacer()
                                Text(SupplierFormatting.currency(totalValue))
                                    .font(.subheadline.bold())
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .searchableWithBarcodeScanner(
                    text: $searchText,
                    prompt: L10n.tr("inventory.search_prompt"),
                    isScannerPresented: $showScanner,
                    showsScanButton: false,
                    onScanned: { code in
                        searchText = code
                    }
                )
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.stock_sheet.tile_initial"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if canEdit && !lines.isEmpty {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || isLoading)
                }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
        .appSafeAreaInsetBottom {
            if let message = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appTask {
            await loadAccess()
            await loadLines()
        }
        .appRefreshable { await loadLines() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task {
                await loadAccess()
                await loadLines()
            }
        }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            isLoadingAccess = false
            return
        }
        do {
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }

    private func loadLines() async {
        guard let companyId = companyManager.currentCompany?.id, access.canView else {
            lines = []
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await StockSheetService.fetchInitialStockDraft(companyId: companyId)
            lines = snapshot.lines
            if let date = snapshot.transactionDate {
                transactionDate = date
            }
        } catch {
            lines = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        guard canEdit, let companyId = companyManager.currentCompany?.id else { return }
        errorMessage = nil

        var payloads: [InitialStockLinePayload] = []
        payloads.reserveCapacity(lines.count)
        for line in lines {
            guard let quantity = line.parsedQuantity, quantity >= 0 else {
                errorMessage = L10n.tr("stock_sheet.initial.invalid_quantity", line.product.denumire)
                return
            }
            guard let unitPrice = line.parsedUnitPrice, unitPrice >= 0 else {
                errorMessage = L10n.tr("stock_sheet.initial.invalid_price", line.product.denumire)
                return
            }
            payloads.append(
                InitialStockLinePayload(
                    productId: line.product.id,
                    cantitate: quantity,
                    pretUnitar: unitPrice
                )
            )
        }

        isSaving = true
        do {
            _ = try await StockSheetService.saveInitialStock(
                companyId: companyId,
                transactionDate: transactionDate,
                lines: payloads
            )
            await loadLines()
        } catch {
            errorMessage = StockSheetService.mapInitialStockError(error)
        }
        isSaving = false
    }
}

private struct InitialStockLineRowView: View {
    let product: Product
    let currentStock: Decimal
    @Binding var quantityText: String
    @Binding var unitPriceText: String
    let canEdit: Bool

    private var lineValue: Decimal? {
        guard let quantity = parsedAmount(quantityText), let price = parsedAmount(unitPriceText) else {
            return nil
        }
        return quantity * price
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.denumire)
                .font(.headline)
                .foregroundColor(AppColors.primary)
            HStack(spacing: 8) {
                if let cod = product.cod, !cod.isEmpty {
                    Text(cod)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                Text(product.unitateMasura)
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
                Text(L10n.tr("stock_sheet.initial.current_stock", SupplierFormatting.amountString(currentStock)))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("stock_sheet.col_quantity"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    TextField(SupplierFormatting.amountPlaceholder, text: $quantityText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!canEdit)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("inventory.card_col_price"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    TextField(SupplierFormatting.amountPlaceholder, text: $unitPriceText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!canEdit)
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text(L10n.tr("stock_sheet.col_value"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Text(lineValue.map { SupplierFormatting.currency($0) } ?? "—")
                        .font(.subheadline.bold())
                        .frame(minWidth: 88, alignment: .trailing)
                        .padding(.top, 8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func parsedAmount(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return SupplierFormatting.parseAmount(
            trimmed,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }
}
