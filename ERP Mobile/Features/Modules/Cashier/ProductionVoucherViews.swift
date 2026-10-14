import SwiftUI

struct ProductionVoucherListView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var vouchers: [ProductionVoucher] = []
    @State private var isLoading = false
    @State private var didLoadOnce = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var voucherToShow: ProductionVoucher?
    @State private var voucherToEdit: ProductionVoucher?
    @State private var voucherToDelete: ProductionVoucher?
    @State private var locations: [CompanyWorkLocation] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var selectedLocationId: UUID?
    @State private var asOf = Date()

    private var filteredVouchers: [ProductionVoucher] {
        vouchers.filter { voucher in
            Calendar.current.isDate(voucher.dataBon, inSameDayAs: asOf)
                && matchesLocation(voucher.warehouseId)
        }
    }

    var body: some View {
        Group {
            List {
                filterSection
                Section {
                    if filteredVouchers.isEmpty && !isLoading {
                        Text(vouchers.isEmpty
                             ? L10n.tr("cashier.production_list_empty")
                             : "Nu există bonuri de producție pentru filtrul ales.")
                            .foregroundColor(AppColors.secondary)
                    }
                    ForEach(filteredVouchers) { voucher in
                        HStack(alignment: .center, spacing: 12) {
                            Button {
                                voucherToShow = voucher
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.tr("cashier.production_number", voucher.numar))
                                        .font(.headline)
                                        .foregroundColor(AppColors.primary)
                                    Text(SupplierFormatting.date(voucher.dataBon))
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.secondary)
                                    Text(productLabel(voucher))
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if ListRowActions.prefersExplicitDeleteButton {
                                Button {
                                    voucherToDelete = voucher
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .appControlHint(L10n.tr("common.delete"))
                            }
                        }
                        .contextMenu {
                            Button {
                                voucherToShow = voucher
                            } label: {
                                Label(L10n.tr("cashier.production_open"), systemImage: "eye")
                                    .appHoverTip(L10n.tr("cashier.production_open"))
                            }
                            Button(role: .destructive) {
                                voucherToDelete = voucher
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash").appHoverTip(L10n.tr("common.delete"))
                            }
                        }
                        .appSwipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                voucherToDelete = voucher
                            } label: {
                                Label(L10n.tr("common.delete"), systemImage: "trash").appHoverTip(L10n.tr("common.delete"))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("module.cashier.production_note"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .appControlHint(L10n.tr("common.add"))
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading && !didLoadOnce) }
        .safeAreaInset(edge: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
        .appTask(id: companyManager.currentCompany?.id) { await load() }
        .fullScreenCover(isPresented: $showCreate) {
            ProductionVoucherCreateView {
                await load()
            }
            .environmentObject(companyManager)
        }
        .fullScreenCover(item: $voucherToShow) { voucher in
            ProductionVoucherDetailView(voucher: voucher) {
                voucherToShow = nil
                voucherToEdit = voucher
            }
            .environmentObject(companyManager)
        }
        .fullScreenCover(item: $voucherToEdit) { voucher in
            ProductionVoucherCreateView(existing: voucher) {
                await load()
            }
            .environmentObject(companyManager)
        }
        .alert(
            L10n.tr("cashier.production_delete_title"),
            isPresented: Binding(
                get: { voucherToDelete != nil },
                set: { if !$0 { voucherToDelete = nil } }
            ),
            presenting: voucherToDelete
        ) { voucher in
            Button(L10n.tr("common.delete"), role: .destructive) {
                Task { await delete(voucher) }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: { voucher in
            Text(L10n.tr("cashier.production_delete_confirm", voucher.numar))
        }
    }

    private var filterSection: some View {
        Section {
            Picker(L10n.tr("stock_sheet.filter_location"), selection: $selectedLocationId) {
                Text(L10n.tr("stock_sheet.filter_location_all")).tag(Optional<UUID>.none)
                ForEach(locations) { location in
                    Text(location.denumire).tag(Optional(location.id))
                }
            }
            DatePicker(L10n.tr("stock_sheet.filter_date"), selection: $asOf, displayedComponents: .date)
        }
    }

    private func matchesLocation(_ warehouseId: UUID) -> Bool {
        guard let selectedLocationId else { return true }
        return warehouses.first { $0.id == warehouseId }?.workLocationId == selectedLocationId
    }

    private func productLabel(_ voucher: ProductionVoucher) -> String {
        let name = voucher.product?.denumire ?? "—"
        let qty = SupplierFormatting.amountString(voucher.cantitate)
        let unit = voucher.unitateMasura
        let warehouse = voucher.warehouse?.denumire
        if let warehouse, !warehouse.isEmpty {
            return "\(name) · \(qty) \(unit) · \(warehouse)"
        }
        return "\(name) · \(qty) \(unit)"
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            didLoadOnce = true
        }
        do {
            async let loadedVouchers = ProductionVoucherService.fetchVouchers(companyId: companyId)
            async let loadedLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            vouchers = try await loadedVouchers
            locations = try await loadedLocations
            warehouses = try await loadedWarehouses
        } catch {
            vouchers = []
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ voucher: ProductionVoucher) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ProductionVoucherService.deleteVoucher(id: voucher.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProductionVoucherCreateView: View {
    var existing: ProductionVoucher? = nil
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var warehouses: [CompanyWarehouse] = []
    @State private var products: [Product] = []
    @State private var dataBon = Date()
    @State private var warehouseId: UUID?
    @State private var productId: UUID?
    @State private var quantityText = ""
    @State private var observatii = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    private var selectedProduct: Product? {
        products.first { $0.id == productId }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DateInputField(title: L10n.tr("cashier.production_field_date"), date: $dataBon)
                    Picker(L10n.tr("cashier.production_field_warehouse"), selection: $warehouseId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(activeWarehouses) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }
                    Picker(L10n.tr("cashier.production_field_product"), selection: $productId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(products) { product in
                            Text(product.denumire).tag(Optional(product.id))
                        }
                    }
                    HStack {
                        Text(L10n.tr("cashier.production_field_quantity"))
                        Spacer()
                        TextField("0", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text(selectedProduct?.unitateMasura ?? "")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                            .frame(minWidth: 28, alignment: .leading)
                    }
                }
                Section(header: Text(L10n.tr("inventory.physical_field_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("inventory.physical_notes_placeholder"), text: $observatii)
                }
                Section {
                    Text(L10n.tr("cashier.production_create_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(existing == nil ? L10n.tr("cashier.production_create_title") : L10n.tr("cashier.production_number", existing?.numar ?? ""))
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
        }
        .navigationViewStyle(.stack)
    }

    private func loadOptions() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            async let loadedProducts = ProductionVoucherService.fetchFinishedGoodsWithRecipe(companyId: companyId)
            let (nextWarehouses, nextProducts) = try await (loadedWarehouses, loadedProducts)
            warehouses = nextWarehouses
            products = nextProducts
            if let existing {
                dataBon = existing.dataBon
                warehouseId = existing.warehouseId
                productId = existing.productId
                quantityText = SupplierFormatting.amountString(existing.cantitate)
                observatii = existing.observatii ?? ""
            } else if warehouseId == nil {
                warehouseId = nextWarehouses.first(where: \.isActive)?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        guard let warehouseId else {
            errorMessage = L10n.tr("cashier.production_error_warehouse")
            return
        }
        guard let productId else {
            errorMessage = L10n.tr("cashier.production_error_product")
            return
        }
        guard let qty = SupplierFormatting.parseAmount(quantityText, maxFractionDigits: 4), qty > 0 else {
            errorMessage = L10n.tr("cashier.production_error_quantity")
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let existing {
                try await ProductionVoucherService.updateVoucher(
                    id: existing.id,
                    dataBon: dataBon,
                    warehouseId: warehouseId,
                    productId: productId,
                    cantitate: qty,
                    observatii: observatii
                )
            } else {
                _ = try await ProductionVoucherService.postVoucher(
                    companyId: companyId,
                    dataBon: dataBon,
                    warehouseId: warehouseId,
                    productId: productId,
                    cantitate: qty,
                    observatii: observatii
                )
            }
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProductionVoucherDetailView: View {
    let voucher: ProductionVoucher
    var onEdit: () -> Void = {}

    @Environment(\.presentationMode) private var presentationMode
    @State private var lines: [ProductionVoucherLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditWarning = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    LabeledContent(L10n.tr("cashier.production_field_number"), value: voucher.numar)
                    LabeledContent(L10n.tr("cashier.production_field_date"), value: SupplierFormatting.date(voucher.dataBon))
                    LabeledContent(
                        L10n.tr("cashier.production_field_warehouse"),
                        value: voucher.warehouse?.denumire ?? "—"
                    )
                    LabeledContent(
                        L10n.tr("cashier.production_field_product"),
                        value: voucher.product?.denumire ?? "—"
                    )
                    LabeledContent(
                        L10n.tr("cashier.production_field_quantity"),
                        value: "\(SupplierFormatting.amountString(voucher.cantitate)) \(voucher.unitateMasura)"
                    )
                    if let notes = voucher.observatii, !notes.isEmpty {
                        LabeledContent(L10n.tr("inventory.physical_field_notes"), value: notes)
                    }
                }
                Section(header: Text(L10n.tr("cashier.production_consumption"))) {
                    if lines.isEmpty && !isLoading {
                        Text(errorMessage ?? L10n.tr("cashier.production_consumption_empty"))
                            .foregroundColor(AppColors.secondary)
                    } else {
                        ForEach(lines) { line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.product?.denumire ?? "—")
                                        .font(.body.weight(.semibold))
                                    if let tip = line.product?.tip {
                                        Text(tip.label)
                                            .font(.caption)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(SupplierFormatting.amountString(line.cantitate)) \(line.unitateMasura)")
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("cashier.production_number", voucher.numar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.edit")) { showEditWarning = true }
                }
            }
            .alert(L10n.tr("inventory.edit_recalc_title"), isPresented: $showEditWarning) {
                Button(L10n.tr("inventory.edit_recalc_continue")) {
                    onEdit()
                }
                Button(L10n.tr("common.cancel"), role: .cancel) {}
            } message: {
                Text(L10n.tr("inventory.edit_recalc_message"))
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appTask { await loadLines() }
        }
        .navigationViewStyle(.stack)
    }

    private func loadLines() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lines = try await ProductionVoucherService.fetchLines(voucherId: voucher.id)
        } catch {
            lines = []
            errorMessage = error.localizedDescription
        }
    }
}
