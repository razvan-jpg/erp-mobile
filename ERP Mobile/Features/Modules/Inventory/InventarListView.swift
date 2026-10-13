import SwiftUI

struct InventarListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @State private var inventories: [PhysicalInventory] = []
    @State private var reports: [InventoryDifferenceReport] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var zeroWarehouseId: UUID?
    @State private var listMode: InventoryListMode = .inventories
    @State private var selectedReport: InventoryDifferenceReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showCreate = false
    @State private var selectedInventory: PhysicalInventoryContext?
    @State private var inventoryToDelete: PhysicalInventory?
    @State private var showDeleteConfirm = false
    @State private var showZeroStockConfirm = false
    @State private var searchText = ""

    private var filteredInventories: [PhysicalInventory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return inventories }
        return inventories.filter {
            $0.numarInventar.localizedCaseInsensitiveContains(query)
                || ($0.observatii?.localizedCaseInsensitiveContains(query) ?? false)
                || $0.status.label.localizedCaseInsensitiveContains(query)
        }
    }

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    private var selectedZeroWarehouseName: String {
        activeWarehouses.first { $0.id == zeroWarehouseId }?.denumire ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("inventory.physical_list_mode"), selection: $listMode) {
                Text(L10n.tr("inventory.physical_list_inventories")).tag(InventoryListMode.inventories)
                Text(L10n.tr("inventory.physical_list_reports")).tag(InventoryListMode.reports)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            if session.isSuperAdmin, listMode == .inventories {
                superadminZeroStockBar
            }

            listContent
        }
    }

    private var superadminZeroStockBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(L10n.tr("inventory.field_warehouse"), selection: $zeroWarehouseId) {
                Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                ForEach(activeWarehouses) { warehouse in
                    Text(warehouse.denumire).tag(Optional(warehouse.id))
                }
            }
            Button {
                showZeroStockConfirm = true
            } label: {
                Text(L10n.tr("inventory.zero_stock_button"))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(zeroWarehouseId == nil || isLoading)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var listContent: some View {
        Group {
            if listMode == .reports {
                reportList
            } else if filteredInventories.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("inventory.physical_empty"),
                    systemImage: "list.clipboard",
                    description: Text(access.canCreate
                        ? L10n.tr("inventory.physical_empty_create")
                        : L10n.tr("inventory.physical_empty_readonly"))
                )
            } else {
                List {
                    ForEach(filteredInventories) { inventory in
                        Button {
                            selectedInventory = PhysicalInventoryContext(inventory: inventory, access: access)
                        } label: {
                            PhysicalInventoryRowView(
                                inventory: inventory,
                                warehouseName: warehouses.first { $0.id == inventory.warehouseId }?.denumire
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("inventory.physical_search_prompt"))
                .appScrollBottomPadding()
            }
        }
        .floatingBottomTrailing {
            if access.canCreate {
                FloatingAddIconButton { showCreate = true }
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
            } else if let successMessage {
                Text(successMessage)
                    .font(.caption)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadInventories() }
        .appRefreshable {
            await loadInventories()
        }
        .alert(isPresented: $showZeroStockConfirm) {
            Alert(
                title: Text(L10n.tr("inventory.zero_stock_title")),
                message: Text(L10n.tr("inventory.zero_stock_confirm", selectedZeroWarehouseName)),
                primaryButton: .destructive(Text(L10n.tr("inventory.zero_stock_button"))) {
                    Task { await zeroSelectedWarehouseStock() }
                },
                secondaryButton: .cancel()
            )
        }
        .fullScreenCover(isPresented: $showCreate) {
            PhysicalInventoryCreateView(access: access) {
                await loadInventories()
            }
        }
        .fullScreenCover(item: $selectedReport) { report in
            InventoryDifferenceReportView(report: report, warehouseName: warehouses.first { $0.id == report.warehouseId }?.denumire)
        }
        .fullScreenCover(item: $selectedInventory) { context in
            PhysicalInventoryDetailView(context: context) {
                await loadInventories()
            }
        }
        .alert(L10n.tr("inventory.physical_delete_title"), isPresented: $showDeleteConfirm, presenting: inventoryToDelete) { inventory in
            Button(L10n.tr("common.delete")) {
                Task { await deleteInventory(inventory) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { inventory in
            Text(L10n.tr("inventory.physical_delete_confirm", inventory.numarInventar))
        }
    }

    private func loadInventories() async {
        guard let companyId = companyManager.currentCompany?.id else {
            inventories = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedInventories = PhysicalInventoryService.fetchInventories(companyId: companyId)
            async let loadedReports = PhysicalInventoryService.fetchDifferenceReports(companyId: companyId)
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            inventories = try await loadedInventories
            reports = try await loadedReports
            warehouses = try await loadedWarehouses
        } catch {
            inventories = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let inventory = filteredInventories[index]
        guard inventory.status.isEditable else {
            errorMessage = L10n.tr("inventory.physical_error_not_open")
            return
        }
        inventoryToDelete = inventory
        showDeleteConfirm = true
    }

    @ViewBuilder
    private var reportList: some View {
        if reports.isEmpty && !isLoading {
            AppEmptyStateView(
                L10n.tr("inventory.report_empty"),
                systemImage: "doc.text.magnifyingglass",
                description: Text(L10n.tr("inventory.report_empty_hint"))
            )
        } else {
            List(reports) { report in
                Button {
                    selectedReport = report
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.tr("inventory.report_number", report.numar))
                            .font(.headline)
                        Text(SupplierFormatting.compactDate(report.dataOra))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondary)
                        if let name = warehouses.first(where: { $0.id == report.warehouseId })?.denumire {
                            Text(name)
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func deleteInventory(_ inventory: PhysicalInventory) async {
        isLoading = true
        errorMessage = nil
        do {
            try await PhysicalInventoryService.deleteInventory(id: inventory.id)
            await loadInventories()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func zeroSelectedWarehouseStock() async {
        guard session.isSuperAdmin, let warehouseId = zeroWarehouseId else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let count = try await InventoryService.zeroWarehouseStock(warehouseId: warehouseId)
            successMessage = L10n.tr("inventory.zero_stock_done", count, selectedZeroWarehouseName)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private enum InventoryListMode: Hashable {
    case inventories
    case reports
}

private struct PhysicalInventoryRowView: View {
    let inventory: PhysicalInventory
    var warehouseName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.tr("inventory.physical_number", inventory.numarInventar))
                    .font(.headline)
                Spacer()
                Text(inventory.status.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }
            Text(L10n.tr("inventory.physical_date", SupplierFormatting.date(inventory.dataInventar)))
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
            if let warehouseName, !warehouseName.isEmpty {
                Text(warehouseName)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            if let observatii = inventory.observatii, !observatii.isEmpty {
                Text(observatii)
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
                    .lineLimit(2)
            }
            if let finalizedAt = inventory.finalizedAt {
                Text(L10n.tr("inventory.physical_finalized_at", SupplierFormatting.compactDate(finalizedAt)))
                    .font(.caption2)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch inventory.status {
        case .open: return .orange
        case .finalized: return .green
        case .cancelled: return .secondary
        }
    }
}

struct InventoryDifferenceReportView: View {
    let report: InventoryDifferenceReport
    let warehouseName: String?

    @Environment(\.presentationMode) private var presentationMode
    @State private var lines: [InventoryDifferenceReportLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List(lines) { line in
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.denumire).font(.headline)
                    Text(L10n.tr(
                        "inventory.report_line",
                        SupplierFormatting.amountString(line.stocScriptic),
                        SupplierFormatting.amountString(line.cantitateFaptica),
                        SupplierFormatting.amountString(line.diferenta),
                        line.unitateMasura
                    ))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                }
            }
            .navigationTitle(L10n.tr("inventory.report_number", report.numar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                if let warehouseName {
                    Text(warehouseName)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await load() }
        }
    }

    private func load() async {
        isLoading = true
        do {
            lines = try await PhysicalInventoryService.fetchDifferenceReportLines(reportId: report.id)
                .sorted { $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
