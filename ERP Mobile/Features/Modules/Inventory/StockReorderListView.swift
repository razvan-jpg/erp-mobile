import SwiftUI

/// Listă necesar de comandat: articole cu stoc minim pe fișă, unde stocul < minim (și dacă e negativ).
struct StockReorderListView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var rows: [StockReorderRow] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var selectedWarehouseId: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var exportURL: URL?
    @State private var showExportPicker = false
    @State private var showAdd = false
    @State private var orderDrafts: [UUID: String] = [:]

    private var filteredRows: [StockReorderRow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty ? rows : rows.filter { row in
            row.denumire.localizedCaseInsensitiveContains(query)
                || (row.cod?.localizedCaseInsensitiveContains(query) ?? false)
                || row.tip.label.localizedCaseInsensitiveContains(query)
        }
        return base.sorted { lhs, rhs in
            let left = categoryRank(lhs.tip)
            let right = categoryRank(rhs.tip)
            if left != right { return left < right }
            return lhs.denumire.localizedStandardCompare(rhs.denumire) == .orderedAscending
        }
    }

    private var groupedRows: [(ProductKind, [StockReorderRow])] {
        var order: [ProductKind] = []
        var buckets: [ProductKind: [StockReorderRow]] = [:]
        for row in filteredRows {
            if buckets[row.tip] == nil {
                order.append(row.tip)
            }
            buckets[row.tip, default: []].append(row)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    private func categoryRank(_ tip: ProductKind) -> Int {
        ProductKind.articleCategories.firstIndex(of: tip) ?? (ProductKind.allCases.count + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !warehouses.isEmpty {
                Picker(L10n.tr("inventory.field_warehouse"), selection: $selectedWarehouseId) {
                    Text(L10n.tr("inventory.warehouse_all")).tag(Optional<UUID>.none)
                    ForEach(warehouses.filter(\.isActive)) { warehouse in
                        Text(warehouse.denumire).tag(Optional(warehouse.id))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(spacing: 8) {
                Button {
                    Task { await printList() }
                } label: {
                    Label(L10n.tr("inventory.reorder_print"), systemImage: "printer")
                }
                .disabled(filteredRows.isEmpty || isLoading)
                Button {
                    Task { await exportPDF() }
                } label: {
                    Label(L10n.tr("inventory.reorder_export"), systemImage: "square.and.arrow.down")
                }
                .disabled(filteredRows.isEmpty || isLoading)
                Button {
                    showAdd = true
                } label: {
                    Label(L10n.tr("inventory.reorder_add"), systemImage: "plus")
                }
                .disabled(isLoading || companyManager.currentCompany == nil)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text(L10n.tr("inventory.reorder_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 6)

            Group {
                if filteredRows.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("inventory.reorder_empty"),
                        systemImage: "cart.badge.plus",
                        description: Text(L10n.tr("inventory.reorder_empty_hint"))
                    )
                } else {
                    List {
                        ForEach(groupedRows, id: \.0) { kind, items in
                            Section(kind.label) {
                                ForEach(items) { row in
                                    reorderRow(row)
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: L10n.tr("inventory.search_prompt"))
                    .appScrollBottomPadding()
                }
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
        .appTask { await load() }
        .appRefreshable { await load() }
        .onChange(of: selectedWarehouseId) { _, _ in
            Task { await load() }
        }
        .onChange(of: companyManager.currentCompany?.id) { _, _ in
            Task { await load() }
        }
        .sheet(isPresented: $showExportPicker, onDismiss: { exportURL = nil }) {
            if let exportURL {
                LocalSaveDocumentPicker(sourceURL: exportURL) {
                    showExportPicker = false
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            if let companyId = companyManager.currentCompany?.id {
                ReorderAddProductSheet(
                    companyId: companyId,
                    warehouseId: selectedWarehouseId,
                    warehouses: warehouses,
                    existingIds: Set(rows.map(\.productId))
                ) { row in
                    rows.append(row)
                    orderDrafts[row.productId] = SupplierFormatting.amountString(row.cantitateNecesara)
                    showAdd = false
                }
            }
        }
    }

    private func reorderRow(_ row: StockReorderRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.denumire)
                    .font(.headline)
                Spacer()
                Button {
                    remove(row)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.tr("inventory.reorder_remove"))
            }
            if let cod = row.cod, !cod.isEmpty {
                Text(cod)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("inventory.reorder_current"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text("\(SupplierFormatting.amountString(row.cantitateCurenta)) \(row.unitateMasura)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(row.cantitateCurenta < 0 ? .red : .primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.tr("inventory.reorder_minimum"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text("\(SupplierFormatting.amountString(row.cantitateMinima)) \(row.unitateMasura)")
                        .font(.subheadline.monospacedDigit())
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.tr("inventory.reorder_optimal"))
                        .font(.caption2)
                        .foregroundColor(AppColors.tertiary)
                    Text("\(SupplierFormatting.amountString(row.cantitateOptima)) \(row.unitateMasura)")
                        .font(.subheadline.monospacedDigit())
                }
            }
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.tr("inventory.reorder_needed"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.secondary)
                    Text(L10n.tr("inventory.reorder_editable"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(red: 0.55, green: 0.38, blue: 0.12))
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(red: 0.55, green: 0.38, blue: 0.12))
                    TextField(L10n.tr("inventory.reorder_needed"), text: orderDraft(row))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.monospacedDigit().bold())
                        .frame(minWidth: 64)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 1, green: 0.965, blue: 0.88))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(red: 0.78, green: 0.63, blue: 0.35), lineWidth: 1.5)
                )
                Text(row.unitateMasura)
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                remove(row)
            } label: {
                Label(L10n.tr("inventory.reorder_remove"), systemImage: "trash")
            }
        }
    }

    private func orderDraft(_ row: StockReorderRow) -> Binding<String> {
        Binding(
            get: { orderDrafts[row.productId] ?? SupplierFormatting.amountString(row.cantitateNecesara) },
            set: { orderDrafts[row.productId] = $0 }
        )
    }

    private func orderAmount(_ row: StockReorderRow) -> Decimal {
        if let text = orderDrafts[row.productId],
           let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 4) {
            return max(0, value)
        }
        return max(0, row.cantitateNecesara)
    }

    private func remove(_ row: StockReorderRow) {
        rows.removeAll { $0.productId == row.productId }
        orderDrafts.removeValue(forKey: row.productId)
    }

    private func printableRows() -> [StockReorderRow] {
        filteredRows.map { row in
            var copy = row
            copy.cantitateNecesara = orderAmount(row)
            return copy
        }
    }

    private func exportPDF() async {
        guard !filteredRows.isEmpty else { return }
        errorMessage = nil
        do {
            let url = try pdfURL()
#if targetEnvironment(macCatalyst)
            let suggested = url.deletingPathExtension().lastPathComponent + ".pdf"
            if !DocumentExportSupport.saveOnMac(from: url, suggestedName: suggested) {
                errorMessage = L10n.tr("inventory.reorder_save_failed")
            }
#else
            exportURL = url
            showExportPicker = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printList() async {
        guard !filteredRows.isEmpty else { return }
        errorMessage = nil
        do {
            let url = try pdfURL()
            try DocumentExportSupport.printPDF(url: url, jobName: L10n.tr("module.inventory.tab_reorder"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pdfURL() throws -> URL {
        let warehouse = warehouses.first { $0.id == selectedWarehouseId }?.denumire
            ?? L10n.tr("inventory.warehouse_all")
        return try ReorderNeedPDFBuilder.writeTemporaryPDF(
            companyName: companyManager.currentCompany?.denumire ?? L10n.tr("common.unknown_company"),
            warehouseName: warehouse,
            rows: printableRows(),
            generatedAt: Date()
        )
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            rows = []
            warehouses = []
            orderDrafts = [:]
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            warehouses = try await loadedWarehouses
            orderDrafts = [:]
            rows = try await InventoryService.fetchReorderNeededRows(
                companyId: companyId,
                warehouseId: selectedWarehouseId,
                warehouses: warehouses
            )
        } catch {
            rows = []
            orderDrafts = [:]
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ReorderAddProductSheet: View {
    let companyId: UUID
    let warehouseId: UUID?
    let warehouses: [CompanyWarehouse]
    let existingIds: Set<UUID>
    let onAdd: (StockReorderRow) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var query = ""
    @State private var results: [StockReorderRow] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var visibleResults: [StockReorderRow] {
        results
            .filter { !existingIds.contains($0.productId) }
            .sorted { lhs, rhs in
                let left = ProductKind.articleCategories.firstIndex(of: lhs.tip) ?? 99
                let right = ProductKind.articleCategories.firstIndex(of: rhs.tip) ?? 99
                if left != right { return left < right }
                return lhs.denumire.localizedStandardCompare(rhs.denumire) == .orderedAscending
            }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                TextField(L10n.tr("inventory.reorder_add_prompt"), text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: query) { _, _ in
                        searchTask?.cancel()
                        searchTask = Task { await search() }
                    }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                if visibleResults.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("inventory.reorder_add_empty"),
                        systemImage: "magnifyingglass",
                        description: Text(L10n.tr("inventory.reorder_add_prompt"))
                    )
                } else {
                    List(visibleResults) { row in
                        Button {
                            onAdd(row)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.denumire)
                                    .foregroundColor(.primary)
                                HStack {
                                    if let cod = row.cod, !cod.isEmpty {
                                        Text(cod)
                                    }
                                    Text(row.tip.label)
                                    Spacer()
                                    Text("\(SupplierFormatting.amountString(row.cantitateCurenta)) \(row.unitateMasura)")
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("inventory.reorder_add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 1 else {
            results = []
            return
        }
        do {
            try await Task.sleep(nanoseconds: 250_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        isLoading = true
        errorMessage = nil
        do {
            let found = try await InventoryService.searchReorderRows(
                companyId: companyId,
                warehouseId: warehouseId,
                warehouses: warehouses,
                query: text
            )
            guard !Task.isCancelled else { return }
            results = found
        } catch {
            if !Task.isCancelled {
                results = []
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
}
