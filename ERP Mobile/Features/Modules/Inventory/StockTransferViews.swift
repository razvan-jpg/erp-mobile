import SwiftUI

struct StockTransferListView: View {
    var onChanged: () async -> Void = {}

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var transfers: [StockTransfer] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var transferToDelete: StockTransfer?

    var body: some View {
        NavigationView {
            Group {
                if transfers.isEmpty && !isLoading {
                    AppEmptyStateView(
                        L10n.tr("inventory.transfer_empty"),
                        systemImage: "arrow.left.arrow.right",
                        description: Text(L10n.tr("inventory.transfer_empty_hint"))
                    )
                } else {
                    List {
                        ForEach(transfers) { transfer in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.tr("inventory.transfer_number", transfer.numar))
                                    .font(.headline)
                                Text(SupplierFormatting.date(transfer.dataBon))
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.secondary)
                                Text(routeLabel(transfer))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { offsets in
                            guard let index = offsets.first else { return }
                            transferToDelete = transfers[index]
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("inventory.transfer_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                }
            }
            .appTask { await load() }
            .fullScreenCover(isPresented: $showCreate) {
                StockTransferEditorView {
                    await load()
                    await onChanged()
                }
            }
            .alert(
                L10n.tr("inventory.transfer_delete_title"),
                isPresented: Binding(
                    get: { transferToDelete != nil },
                    set: { if !$0 { transferToDelete = nil } }
                ),
                presenting: transferToDelete
            ) { transfer in
                Button(L10n.tr("common.delete"), role: .destructive) {
                    Task { await delete(transfer) }
                }
                Button(L10n.tr("common.cancel"), role: .cancel) {}
            } message: { transfer in
                Text(L10n.tr("inventory.transfer_delete_confirm", transfer.numar))
            }
        }
    }

    private func routeLabel(_ transfer: StockTransfer) -> String {
        let source = warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—"
        let destination = warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
        return "\(source) → \(destination)"
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            async let loadedTransfers = StockTransferService.fetchTransfers(companyId: companyId)
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            transfers = try await loadedTransfers
            warehouses = try await loadedWarehouses
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func delete(_ transfer: StockTransfer) async {
        isLoading = true
        do {
            try await StockTransferService.deleteTransfer(id: transfer.id)
            await load()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TransferDraftLine: Identifiable, Equatable {
    let id = UUID()
    var product: Product
    var quantityText: String
}

struct StockTransferEditorView: View {
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var warehouses: [CompanyWarehouse] = []
    @State private var products: [Product] = []
    @State private var dataBon = Date()
    @State private var sourceWarehouseId: UUID?
    @State private var destinationWarehouseId: UUID?
    @State private var observatii = ""
    @State private var lines: [TransferDraftLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showProductPicker = false

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DateInputField(title: L10n.tr("inventory.transfer_field_date"), date: $dataBon)
                    Picker(L10n.tr("inventory.transfer_field_source"), selection: $sourceWarehouseId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(activeWarehouses) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }
                    Picker(L10n.tr("inventory.transfer_field_destination"), selection: $destinationWarehouseId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(activeWarehouses) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }
                }
                Section(header: Text(L10n.tr("inventory.transfer_lines"))) {
                    ForEach($lines) { $line in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(line.product.denumire)
                                Text(line.product.tip.label)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            Spacer()
                            TextField(L10n.tr("inventory.transfer_field_quantity"), text: $line.quantityText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(line.product.unitateMasura)
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                    .onDelete { lines.remove(atOffsets: $0) }
                    Button {
                        showProductPicker = true
                    } label: {
                        Label(L10n.tr("inventory.transfer_add_line"), systemImage: "plus")
                    }
                }
                Section(header: Text(L10n.tr("inventory.physical_field_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("inventory.physical_notes_placeholder"), text: $observatii)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.tr("inventory.transfer_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await loadOptions() }
            .sheet(isPresented: $showProductPicker) {
                StockTransferProductPicker(products: availableProducts) { product in
                    lines.append(TransferDraftLine(product: product, quantityText: ""))
                }
            }
        }
    }

    private var availableProducts: [Product] {
        let used = Set(lines.map(\.product.id))
        return products
            .filter { $0.isActive && StockTransferService.transferableKinds.contains($0.tip) && !used.contains($0.id) }
            .sorted { $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending }
    }

    private func loadOptions() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        do {
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            async let loadedProducts = ProductService.fetchProducts(companyId: companyId)
            warehouses = try await loadedWarehouses
            products = try await loadedProducts
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id,
              let sourceWarehouseId,
              let destinationWarehouseId else {
            errorMessage = L10n.tr("inventory.transfer_error_warehouses")
            return
        }
        let parsed: [(productId: UUID, quantity: Decimal)] = lines.compactMap { line in
            guard let quantity = SupplierFormatting.parseAmount(line.quantityText, maxFractionDigits: 4),
                  quantity > 0 else { return nil }
            return (line.product.id, quantity)
        }
        guard parsed.count == lines.count, !parsed.isEmpty else {
            errorMessage = L10n.tr("inventory.transfer_error_no_lines")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            _ = try await StockTransferService.postTransfer(
                companyId: companyId,
                dataBon: dataBon,
                sourceWarehouseId: sourceWarehouseId,
                destinationWarehouseId: destinationWarehouseId,
                observatii: observatii,
                lines: parsed
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct StockTransferProductPicker: View {
    let products: [Product]
    let onSelect: (Product) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText = ""

    private var filtered: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return products }
        return products.filter {
            $0.denumire.localizedCaseInsensitiveContains(query)
                || ($0.cod?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            List(filtered) { product in
                Button {
                    onSelect(product)
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(product.denumire)
                        Text(product.tip.label)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle(L10n.tr("inventory.transfer_add_line"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
