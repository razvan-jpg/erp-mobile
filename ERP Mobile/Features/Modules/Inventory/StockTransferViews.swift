import SwiftUI

struct StockTransferListView: View {
    var onChanged: () async -> Void = {}

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var transfers: [StockTransfer] = []
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var isLoading = false
    @State private var didLoadOnce = false
    @State private var errorMessage: String?
    @State private var showCreate = false
    @State private var transferToView: StockTransfer?
    @State private var transferToEdit: StockTransfer?
    @State private var transferToDelete: StockTransfer?
    @State private var pendingEdit: StockTransfer?
    @State private var showEditWarning = false
    @State private var locations: [CompanyWorkLocation] = []
    @State private var selectedLocationId: UUID?
    @State private var asOf = Date()
    @State private var avizPreview: StockTransferExportItem?

    private var filteredTransfers: [StockTransfer] {
        transfers.filter { transfer in
            Calendar.current.isDate(transfer.dataBon, inSameDayAs: asOf) && matchesLocation(transfer)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                    List {
                        Section {
                            Picker(L10n.tr("stock_sheet.filter_location"), selection: $selectedLocationId) {
                                Text(L10n.tr("stock_sheet.filter_location_all")).tag(Optional<UUID>.none)
                                ForEach(locations) { location in
                                    Text(location.denumire).tag(Optional(location.id))
                                }
                            }
                            DatePicker(L10n.tr("stock_sheet.filter_date"), selection: $asOf, displayedComponents: .date)
                        }
                        Section {
                        if filteredTransfers.isEmpty && !isLoading {
                            Text(transfers.isEmpty
                                 ? L10n.tr("inventory.transfer_empty")
                                 : "Nu există bonuri de transfer pentru filtrul ales.")
                                .foregroundColor(AppColors.secondary)
                        }
                        ForEach(filteredTransfers) { transfer in
                            HStack(alignment: .center, spacing: 12) {
                                Button {
                                    transferToView = transfer
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(L10n.tr("inventory.transfer_number", transfer.numar))
                                            .font(.headline)
                                            .foregroundColor(AppColors.primary)
                                        Text(SupplierFormatting.date(transfer.dataBon))
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.secondary)
                                        Text(routeLabel(transfer))
                                            .font(.caption)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                if ListRowActions.prefersExplicitDeleteButton {
                                    Button {
                                        transferToDelete = transfer
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .appControlHint(L10n.tr("common.delete"))
                                }
                            }
                            .contextMenu {
                                Button {
                                    transferToView = transfer
                                } label: {
                                    Label(L10n.tr("cashier.production_open"), systemImage: "eye")
                                }
                                Button {
                                    pendingEdit = transfer
                                    showEditWarning = true
                                } label: {
                                    Label(L10n.tr("common.edit"), systemImage: "pencil").appHoverTip(L10n.tr("common.edit"))
                                }
                                Button {
                                    Task { await exportAviz(transfer) }
                                } label: {
                                    Label(L10n.tr("inventory.transfer_export_aviz"), systemImage: "doc.richtext").appHoverTip(L10n.tr("inventory.transfer_export_aviz"))
                                }
                                Button(role: .destructive) {
                                    transferToDelete = transfer
                                } label: {
                                    Label(L10n.tr("common.delete"), systemImage: "trash").appHoverTip(L10n.tr("common.delete"))
                                }
                            }
                            .appSwipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    Task { await exportAviz(transfer) }
                                } label: {
                                    Label(L10n.tr("inventory.transfer_export_aviz"), systemImage: "doc.richtext").appHoverTip(L10n.tr("inventory.transfer_export_aviz"))
                                }
                                .tint(.blue)
                                Button(role: .destructive) {
                                    transferToDelete = transfer
                                } label: {
                                    Label(L10n.tr("common.delete"), systemImage: "trash").appHoverTip(L10n.tr("common.delete"))
                                }
                            }
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
                StockTransferEditorView(existing: nil) {
                    await load()
                    await onChanged()
                }
                .environmentObject(companyManager)
            }
            .fullScreenCover(item: $transferToView) { transfer in
                StockTransferDetailView(
                    transfer: transfer,
                    sourceName: warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—",
                    destinationName: warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
                ) {
                    transferToView = nil
                    pendingEdit = transfer
                    showEditWarning = true
                }
                .environmentObject(companyManager)
            }
            .alert(L10n.tr("inventory.edit_recalc_title"), isPresented: $showEditWarning) {
                Button(L10n.tr("inventory.edit_recalc_continue")) {
                    transferToEdit = pendingEdit
                }
                Button(L10n.tr("common.cancel"), role: .cancel) {
                    pendingEdit = nil
                }
            } message: {
                Text(L10n.tr("inventory.edit_recalc_message"))
            }
            .fullScreenCover(item: $transferToEdit) { transfer in
                StockTransferEditorView(existing: transfer) {
                    await load()
                    await onChanged()
                }
                .environmentObject(companyManager)
            }
            .sheet(item: $avizPreview) { item in
                PDFDocumentPreviewSheet(
                    title: item.title,
                    pdfData: item.pdfData,
                    onClose: { avizPreview = nil }
                )
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
        .navigationViewStyle(.stack)
    }

    private func matchesLocation(_ transfer: StockTransfer) -> Bool {
        guard let selectedLocationId else { return true }
        let source = warehouses.first { $0.id == transfer.sourceWarehouseId }?.workLocationId
        let destination = warehouses.first { $0.id == transfer.destinationWarehouseId }?.workLocationId
        return source == selectedLocationId || destination == selectedLocationId
    }

    private func routeLabel(_ transfer: StockTransfer) -> String {
        let source = warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—"
        let destination = warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
        return "\(source) → \(destination)"
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            transfers = []
            warehouses = []
            isLoading = false
            didLoadOnce = true
            return
        }
        if !didLoadOnce {
            isLoading = true
        }
        errorMessage = nil
        defer {
            isLoading = false
            didLoadOnce = true
        }
        do {
            async let loadedTransfers = StockTransferService.fetchTransfers(companyId: companyId)
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            async let loadedLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            let (nextTransfers, nextWarehouses, nextLocations) = try await (loadedTransfers, loadedWarehouses, loadedLocations)
            guard !Task.isCancelled else { return }
            transfers = nextTransfers
            warehouses = nextWarehouses
            locations = nextLocations
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ transfer: StockTransfer) async {
        do {
            try await StockTransferService.deleteTransfer(id: transfer.id)
            await load()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportAviz(_ transfer: StockTransfer) async {
        do {
            let lines = try await StockTransferService.fetchLines(transferId: transfer.id)
            let item = try await StockTransferService.prepareExport(
                company: companyManager.currentCompany,
                transfer: transfer,
                lines: lines,
                sourceWarehouseName: warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—",
                destinationWarehouseName: warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
            )
            avizPreview = item
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TransferDraftLine: Identifiable, Equatable {
    let id: UUID
    var product: Product
    var quantityText: String

    init(id: UUID = UUID(), product: Product, quantityText: String) {
        self.id = id
        self.product = product
        self.quantityText = quantityText
    }
}

struct StockTransferDetailView: View {
    let transfer: StockTransfer
    let sourceName: String
    let destinationName: String
    var onEdit: () -> Void = {}

    @Environment(\.presentationMode) private var presentationMode
    @State private var lines: [StockTransferLine] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                Section {
                    LabeledContent(L10n.tr("inventory.transfer_number", transfer.numar), value: SupplierFormatting.date(transfer.dataBon))
                    LabeledContent("Din", value: sourceName)
                    LabeledContent("În", value: destinationName)
                    if let notes = transfer.observatii, !notes.isEmpty {
                        LabeledContent(L10n.tr("inventory.physical_field_notes"), value: notes)
                    }
                }
                Section {
                    if lines.isEmpty {
                        Text(errorMessage ?? L10n.tr("inventory.transfer_error_no_lines"))
                            .foregroundColor(AppColors.secondary)
                    }
                    ForEach(lines) { line in
                        HStack {
                            Text(line.product?.denumire ?? "—")
                            Spacer()
                            Text("\(SupplierFormatting.stockQuantityString(line.cantitate)) \(line.unitateMasura)")
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr("inventory.transfer_number", transfer.numar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.done")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.edit")) { onEdit() }
                }
            }
            .appTask {
                do {
                    lines = try await StockTransferService.fetchLines(transferId: transfer.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct StockTransferEditorView: View {
    let existing: StockTransfer?
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var warehouses: [CompanyWarehouse] = []
    @State private var products: [Product] = []
    @State private var availableByProductId: [UUID: Decimal] = [:]
    /// Cantități pe bonul curent (la editare), ca să le adăugăm la disponibil pe gestiunea sursă originală.
    @State private var reservedOnThisTransfer: [UUID: Decimal] = [:]
    @State private var originalSourceWarehouseId: UUID?
    @State private var dataBon = Date()
    @State private var sourceWarehouseId: UUID?
    @State private var destinationWarehouseId: UUID?
    @State private var observatii = ""
    @State private var lines: [TransferDraftLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showProductPicker = false
    @State private var avizPreview: StockTransferExportItem?
    @State private var dismissAfterAviz = false

    private var activeWarehouses: [CompanyWarehouse] {
        warehouses.filter(\.isActive)
    }

    private var isEditing: Bool { existing != nil }

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
                    .onChange(of: sourceWarehouseId) { _, _ in
                        Task { await reloadAvailableStock() }
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
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(line.product.denumire)
                                    .font(.body.weight(.semibold))
                                Text(line.product.tip.label)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                HStack {
                                    Text(L10n.tr(
                                        "inventory.transfer_available",
                                        SupplierFormatting.stockQuantityString(availableQuantity(for: line.product.id)),
                                        line.product.unitateMasura
                                    ))
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                    Spacer()
                                    TextField(L10n.tr("inventory.transfer_field_quantity"), text: $line.quantityText)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 88)
                                    Text(line.product.unitateMasura)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if ListRowActions.prefersExplicitDeleteButton {
                                Button {
                                    lines.removeAll { $0.id == line.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .appControlHint(L10n.tr("common.delete"))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { lines.remove(atOffsets: $0) }
                    Button {
                        guard sourceWarehouseId != nil else {
                            errorMessage = L10n.tr("inventory.transfer_select_source_first")
                            return
                        }
                        showProductPicker = true
                    } label: {
                        Label(L10n.tr("inventory.transfer_add_line"), systemImage: "plus").appHoverTip(L10n.tr("inventory.transfer_add_line"))
                    }
                }
                Section(header: Text(L10n.tr("inventory.physical_field_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("inventory.physical_notes_placeholder"), text: $observatii)
                }
                if isEditing {
                    Section {
                        Button {
                            Task { await exportAviz() }
                        } label: {
                            Label(L10n.tr("inventory.transfer_export_aviz"), systemImage: "doc.richtext").appHoverTip(L10n.tr("inventory.transfer_export_aviz"))
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(
                isEditing
                    ? L10n.tr("inventory.transfer_edit_title")
                    : L10n.tr("inventory.transfer_create_title")
            )
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
                StockTransferProductPicker(
                    products: availableProducts,
                    availableByProductId: availableByProductIdForPicker
                ) { product in
                    let available = availableQuantity(for: product.id)
                    let suggested = available > 0 ? SupplierFormatting.stockQuantityString(available) : ""
                    lines.append(TransferDraftLine(product: product, quantityText: suggested))
                }
            }
            .sheet(item: $avizPreview) { item in
                PDFDocumentPreviewSheet(
                    title: item.title,
                    pdfData: item.pdfData,
                    onClose: {
                        avizPreview = nil
                        if dismissAfterAviz {
                            dismissAfterAviz = false
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    private var availableProducts: [Product] {
        let used = Set(lines.map(\.product.id))
        return products
            .filter { $0.isActive && StockTransferService.transferableKinds.contains($0.tip) && !used.contains($0.id) }
            .sorted { $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending }
    }

    private var availableByProductIdForPicker: [UUID: Decimal] {
        Dictionary(uniqueKeysWithValues: availableProducts.map { ($0.id, availableQuantity(for: $0.id)) })
    }

    private func availableQuantity(for productId: UUID) -> Decimal {
        let onHand = availableByProductId[productId] ?? 0
        let reserved: Decimal
        if sourceWarehouseId != nil, sourceWarehouseId == originalSourceWarehouseId {
            reserved = reservedOnThisTransfer[productId] ?? 0
        } else {
            reserved = 0
        }
        return onHand + reserved
    }

    private func loadOptions() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedWarehouses = WarehouseService.fetchWarehouses(companyId: companyId)
            async let loadedProducts = ProductService.fetchProducts(companyId: companyId)
            let (nextWarehouses, nextProducts) = try await (loadedWarehouses, loadedProducts)
            guard !Task.isCancelled else { return }
            warehouses = nextWarehouses
            products = nextProducts

            if let existing {
                dataBon = existing.dataBon
                sourceWarehouseId = existing.sourceWarehouseId
                destinationWarehouseId = existing.destinationWarehouseId
                originalSourceWarehouseId = existing.sourceWarehouseId
                observatii = existing.observatii ?? ""
                let loadedLines = try await StockTransferService.fetchLines(transferId: existing.id)
                guard !Task.isCancelled else { return }
                let productsById = Dictionary(uniqueKeysWithValues: nextProducts.map { ($0.id, $0) })
                var reserved: [UUID: Decimal] = [:]
                var drafts: [TransferDraftLine] = []
                for line in loadedLines {
                    guard let product = productsById[line.productId] else { continue }
                    reserved[line.productId, default: 0] += line.cantitate
                    drafts.append(
                        TransferDraftLine(
                            product: product,
                            quantityText: SupplierFormatting.stockQuantityString(line.cantitate)
                        )
                    )
                }
                reservedOnThisTransfer = reserved
                lines = drafts
            }
            await reloadAvailableStock()
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reloadAvailableStock() async {
        guard let companyId = companyManager.currentCompany?.id,
              let sourceWarehouseId else {
            availableByProductId = [:]
            return
        }
        do {
            availableByProductId = try await StockTransferService.fetchAvailableQuantities(
                companyId: companyId,
                warehouseId: sourceWarehouseId
            )
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id,
              let sourceWarehouseId,
              let destinationWarehouseId else {
            errorMessage = L10n.tr("inventory.transfer_error_warehouses")
            return
        }
        if sourceWarehouseId == destinationWarehouseId {
            errorMessage = L10n.tr("inventory.transfer_error_same_warehouse")
            return
        }
        var parsed: [(productId: UUID, quantity: Decimal)] = []
        for line in lines {
            let trimmedQty = line.quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedQty.isEmpty {
                continue
            }
            guard let quantity = SupplierFormatting.parseAmount(line.quantityText, maxFractionDigits: SupplierFormatting.stockQuantityMaxFractionDigits),
                  quantity > 0 else {
                errorMessage = L10n.tr("inventory.transfer_error_no_lines")
                return
            }
            let available = availableQuantity(for: line.product.id)
            if quantity > available {
                errorMessage = L10n.tr(
                    "inventory.transfer_error_exceeds_available",
                    line.product.denumire,
                    SupplierFormatting.stockQuantityString(available)
                )
                return
            }
            parsed.append((line.product.id, quantity))
        }
        if parsed.isEmpty {
            if let existing {
                // Fără linii ⇒ șterge bonul și readuce stocul pe gestiunea de plecare.
                isLoading = true
                errorMessage = nil
                do {
                    try await StockTransferService.deleteTransfer(id: existing.id)
                    await onSaved()
                    isLoading = false
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            } else {
                errorMessage = L10n.tr("inventory.transfer_error_no_lines")
            }
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let savedId: UUID
            if let existing {
                try await StockTransferService.updateTransfer(
                    id: existing.id,
                    dataBon: dataBon,
                    sourceWarehouseId: sourceWarehouseId,
                    destinationWarehouseId: destinationWarehouseId,
                    observatii: observatii,
                    lines: parsed
                )
                savedId = existing.id
            } else {
                savedId = try await StockTransferService.postTransfer(
                    companyId: companyId,
                    dataBon: dataBon,
                    sourceWarehouseId: sourceWarehouseId,
                    destinationWarehouseId: destinationWarehouseId,
                    observatii: observatii,
                    lines: parsed
                )
            }
            await onSaved()
            let transfer = try await StockTransferService.fetchTransfer(id: savedId)
            let exportLines = try await StockTransferService.fetchLines(transferId: savedId)
            let company = companyManager.currentCompany
            let sourceName = warehouses.first { $0.id == transfer.sourceWarehouseId }?.denumire ?? "—"
            let destinationName = warehouses.first { $0.id == transfer.destinationWarehouseId }?.denumire ?? "—"
            // Eliberăm UI înainte de generarea PDF (poate dura).
            isLoading = false
            let item = try await StockTransferService.prepareExport(
                company: company,
                transfer: transfer,
                lines: exportLines,
                sourceWarehouseName: sourceName,
                destinationWarehouseName: destinationName
            )
            dismissAfterAviz = true
            avizPreview = item
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func exportAviz() async {
        guard let existing else { return }
        do {
            let fresh = try await StockTransferService.fetchTransfer(id: existing.id)
            let lines = try await StockTransferService.fetchLines(transferId: existing.id)
            let item = try await StockTransferService.prepareExport(
                company: companyManager.currentCompany,
                transfer: fresh,
                lines: lines,
                sourceWarehouseName: warehouses.first { $0.id == fresh.sourceWarehouseId }?.denumire ?? "—",
                destinationWarehouseName: warehouses.first { $0.id == fresh.destinationWarehouseId }?.denumire ?? "—"
            )
            dismissAfterAviz = false
            avizPreview = item
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct StockTransferProductPicker: View {
    let products: [Product]
    let availableByProductId: [UUID: Decimal]
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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.denumire)
                            Text(product.tip.label)
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(SupplierFormatting.stockQuantityString(availableByProductId[product.id] ?? 0))
                                .font(.subheadline.weight(.semibold))
                            Text(product.unitateMasura)
                                .font(.caption2)
                                .foregroundColor(AppColors.secondary)
                        }
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
        .navigationViewStyle(.stack)
    }
}
