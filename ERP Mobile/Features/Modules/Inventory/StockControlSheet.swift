import SwiftUI

struct StockControlSheet: View {
    let warehouses: [CompanyWarehouse]
    let initialWarehouseId: UUID?

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var allWarehouses = false
    @State private var selectedWarehouseIds: Set<UUID> = []
    @State private var selectedKinds: Set<ProductKind> = Set(ProductKind.articleCategories)
    @State private var groupByCategory = true
    @State private var rowsByWarehouse: [(warehouseId: UUID?, warehouseName: String, rows: [ProductStockRow])] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showExportShare = false
    @State private var showPrintSheet = false
    @State private var exportShareItems: [Any] = []
    @State private var pdfAttachmentURL: URL?

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    private var hasWarehouseSelection: Bool {
        allWarehouses || !selectedWarehouseIds.isEmpty
    }

    private var warehouseLabel: String {
        if allWarehouses {
            return L10n.tr("inventory.warehouse_all")
        }
        let names = activeWarehouses
            .filter { selectedWarehouseIds.contains($0.id) }
            .map(\.denumire)
        if names.isEmpty { return L10n.tr("common.select") }
        if names.count == 1 { return names[0] }
        return L10n.tr("inventory.stock_control_warehouses_selected", names.count)
    }

    private var filteredSections: [(warehouseId: UUID?, warehouseName: String, rows: [ProductStockRow])] {
        rowsByWarehouse.compactMap { section in
            let filtered = section.rows.filter { row in
                guard let tip = row.product?.tip else { return selectedKinds.contains(.marfa) }
                return selectedKinds.contains(tip)
            }
            guard !filtered.isEmpty || !selectedKinds.isEmpty else { return nil }
            return (section.warehouseId, section.warehouseName, filtered)
        }
        .filter { !$0.rows.isEmpty || rowsByWarehouse.count == 1 }
    }

    private var flatFilteredRows: [ProductStockRow] {
        filteredSections.flatMap(\.rows)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        Toggle(L10n.tr("inventory.warehouse_all"), isOn: $allWarehouses)
                            .onChangeCompat(of: allWarehouses) { _, isOn in
                                if isOn { selectedWarehouseIds = [] }
                                Task { await loadRows() }
                            }

                        if !allWarehouses {
                            ForEach(activeWarehouses) { warehouse in
                                Button {
                                    toggleWarehouse(warehouse.id)
                                } label: {
                                    HStack {
                                        Text(warehouse.denumire)
                                            .foregroundColor(AppColors.primary)
                                        Spacer()
                                        if selectedWarehouseIds.contains(warehouse.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppColors.accent)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(AppColors.tertiary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(L10n.tr("inventory.field_warehouse"))
                    } footer: {
                        Text(L10n.tr("inventory.stock_control_hint"))
                    }

                    Section(header: Text(L10n.tr("inventory.stock_control_categories"))) {
                        ForEach(ProductKind.articleCategories) { kind in
                            Button {
                                toggleKind(kind)
                            } label: {
                                HStack {
                                    Text(kind.label)
                                        .foregroundColor(AppColors.primary)
                                    Spacer()
                                    if selectedKinds.contains(kind) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(AppColors.tertiary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            Button(L10n.tr("common.select_all")) {
                                selectedKinds = Set(ProductKind.articleCategories)
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                            Button(L10n.tr("common.deselect_all")) {
                                selectedKinds = []
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Section {
                        Toggle(L10n.tr("inventory.stock_control_group_by_category"), isOn: $groupByCategory)
                    }

                    Section {
                        Button {
                            Task { await exportPDF() }
                        } label: {
                            Label(L10n.tr("account.export_pdf"), systemImage: "doc.fill")
                                .appHoverTip(L10n.tr("account.export_pdf"))
                        }
                        .disabled(!canExport)

                        Button {
                            Task { await printPDF() }
                        } label: {
                            Label(L10n.tr("account.print"), systemImage: "printer.fill")
                                .appHoverTip(L10n.tr("account.print"))
                        }
                        .disabled(!canExport)
                    }
                }
                .frame(maxHeight: 360)

                previewList
            }
            .navigationTitle(L10n.tr("inventory.stock_control_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
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
            .onAppear {
                if !allWarehouses, selectedWarehouseIds.isEmpty {
                    if let initialWarehouseId {
                        selectedWarehouseIds = [initialWarehouseId]
                    } else if let first = activeWarehouses.first {
                        selectedWarehouseIds = [first.id]
                    }
                }
            }
            .appTask { await loadRows() }
            .sheet(isPresented: $showExportShare) {
                ActivityShareSheet(
                    items: exportShareItems,
                    excludedActivityTypes: nil,
                    onFinish: { showExportShare = false }
                )
            }
            .sheet(isPresented: $showPrintSheet) {
                if let pdfAttachmentURL,
                   let data = try? Data(contentsOf: pdfAttachmentURL) {
                    PrintDocumentView(
                        pdfData: data,
                        jobName: L10n.tr("inventory.stock_control_print_job", warehouseLabel),
                        onFinish: { showPrintSheet = false }
                    )
                }
            }
        }
    }

    private var canExport: Bool {
        hasWarehouseSelection && !selectedKinds.isEmpty && !isLoading
    }

    @ViewBuilder
    private var previewList: some View {
        if !hasWarehouseSelection {
            AppEmptyStateView(
                L10n.tr("inventory.stock_control_select_warehouse"),
                systemImage: "building.2",
                description: Text(L10n.tr("inventory.stock_control_hint"))
            )
        } else if selectedKinds.isEmpty {
            AppEmptyStateView(
                L10n.tr("inventory.stock_control_select_category"),
                systemImage: "line.3.horizontal.decrease.circle",
                description: Text(L10n.tr("inventory.stock_control_categories_hint"))
            )
        } else if flatFilteredRows.isEmpty && !isLoading {
            AppEmptyStateView(
                L10n.tr("inventory.stocks_empty"),
                systemImage: "shippingbox",
                description: Text(L10n.tr("inventory.stocks_empty_hint"))
            )
        } else if groupByCategory {
            List {
                ForEach(filteredSections, id: \.warehouseName) { section in
                    if filteredSections.count > 1 {
                        Section(header: Text(section.warehouseName)) {
                            groupedSections(for: section.rows)
                        }
                    } else {
                        groupedSections(for: section.rows)
                    }
                }
            }
            .listStyle(.insetGrouped)
        } else {
            List {
                ForEach(filteredSections, id: \.warehouseName) { section in
                    if filteredSections.count > 1 {
                        Section(header: Text(section.warehouseName)) {
                            ForEach(sorted(section.rows)) { row in
                                stockRow(row)
                            }
                        }
                    } else {
                        ForEach(sorted(section.rows)) { row in
                            stockRow(row)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func groupedSections(for rows: [ProductStockRow]) -> some View {
        ForEach(StockControlPDFBuilder.groupedRows(from: rows), id: \.group.id) { entry in
            Section(header: Text(L10n.tr("inventory.physical_category_section", entry.group.label, entry.rows.count))) {
                ForEach(entry.rows) { row in
                    stockRow(row)
                }
            }
        }
    }

    private func sorted(_ rows: [ProductStockRow]) -> [ProductStockRow] {
        rows.sorted {
            ($0.product?.denumire ?? "").localizedStandardCompare($1.product?.denumire ?? "") == .orderedAscending
        }
    }

    private func stockRow(_ row: ProductStockRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.product?.denumire ?? L10n.tr("inventory.unknown_product"))
                    .font(.subheadline.weight(.semibold))
                if let cod = row.product?.cod, !cod.isEmpty {
                    Text(cod)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            Spacer()
            Text("\(SupplierFormatting.amountString(row.cantitate)) \(row.product?.unitateMasura ?? "buc")")
                .font(.subheadline.monospacedDigit().bold())
                .foregroundColor(row.cantitate < 0 ? .red : .primary)
        }
        .padding(.vertical, 2)
    }

    private func toggleWarehouse(_ id: UUID) {
        if selectedWarehouseIds.contains(id) {
            selectedWarehouseIds.remove(id)
        } else {
            selectedWarehouseIds.insert(id)
        }
        allWarehouses = false
        Task { await loadRows() }
    }

    private func toggleKind(_ kind: ProductKind) {
        if selectedKinds.contains(kind) {
            selectedKinds.remove(kind)
        } else {
            selectedKinds.insert(kind)
        }
    }

    private func loadRows() async {
        guard let companyId = companyManager.currentCompany?.id, hasWarehouseSelection else {
            rowsByWarehouse = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            if allWarehouses {
                let rows = try await InventoryService.fetchStockRows(companyId: companyId, warehouseId: nil)
                rowsByWarehouse = [(nil, L10n.tr("inventory.warehouse_all"), rows)]
            } else {
                var sections: [(UUID?, String, [ProductStockRow])] = []
                for warehouse in activeWarehouses where selectedWarehouseIds.contains(warehouse.id) {
                    let rows = try await InventoryService.fetchStockRows(
                        companyId: companyId,
                        warehouseId: warehouse.id
                    )
                    sections.append((warehouse.id, warehouse.denumire, rows))
                }
                rowsByWarehouse = sections
            }
        } catch {
            rowsByWarehouse = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func makeSnapshot() -> StockControlSnapshot {
        let sections = filteredSections.map {
            StockControlWarehouseSection(
                warehouseId: $0.warehouseId,
                warehouseName: $0.warehouseName,
                rows: $0.rows
            )
        }
        return StockControlSnapshot(
            company: companyManager.currentCompany,
            warehouseName: warehouseLabel,
            sections: sections,
            generatedAt: Date(),
            groupByCategory: groupByCategory
        )
    }

    private func exportPDF() async {
        guard canExport else { return }
        errorMessage = nil
        do {
            if rowsByWarehouse.isEmpty { await loadRows() }
            let url = try StockControlPDFBuilder.writeTemporaryPDF(from: makeSnapshot())
#if targetEnvironment(macCatalyst)
            let suggested = url.deletingPathExtension().lastPathComponent + ".pdf"
            if !DocumentExportSupport.saveOnMac(from: url, suggestedName: suggested) {
                errorMessage = L10n.tr("inventory.stock_control_save_failed")
            }
#else
            exportShareItems = [url]
            showExportShare = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func printPDF() async {
        guard canExport else { return }
        errorMessage = nil
        do {
            if rowsByWarehouse.isEmpty { await loadRows() }
            let url = try StockControlPDFBuilder.writeTemporaryPDF(from: makeSnapshot())
#if targetEnvironment(macCatalyst)
            try DocumentExportSupport.printPDF(
                url: url,
                jobName: L10n.tr("inventory.stock_control_print_job", warehouseLabel)
            )
#else
            pdfAttachmentURL = url
            showPrintSheet = true
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
