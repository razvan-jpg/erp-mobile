import SwiftUI

struct InventarListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var inventories: [PhysicalInventory] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var selectedInventory: PhysicalInventoryContext?
    @State private var inventoryToDelete: PhysicalInventory?
    @State private var showDeleteConfirm = false
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

    var body: some View {
        Group {
            if filteredInventories.isEmpty && !isLoading {
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
                            PhysicalInventoryRowView(inventory: inventory)
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
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .appSymbolRenderingMode(.hierarchical)
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
        .appTask { await loadInventories() }
        .appRefreshable {
            await loadInventories()
        }
        .fullScreenCover(isPresented: $showCreate) {
            PhysicalInventoryCreateView(access: access) {
                await loadInventories()
            }
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
            inventories = try await PhysicalInventoryService.fetchInventories(companyId: companyId)
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
}

private struct PhysicalInventoryRowView: View {
    let inventory: PhysicalInventory

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
