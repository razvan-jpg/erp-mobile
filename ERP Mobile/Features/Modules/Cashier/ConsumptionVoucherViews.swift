import SwiftUI

struct ConsumptionVoucherListView: View {
    var review = false

    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @State private var vouchers: [ConsumptionVoucher] = []
    @State private var locations: [CompanyWorkLocation] = []
    @State private var selectedLocationId: UUID?
    @State private var allDates = true
    @State private var asOf = Date()
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false

    var body: some View {
        List {
            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
            if shownVouchers.isEmpty && !isLoading {
                Text(L10n.tr("cashier.consumption_list_empty"))
                    .foregroundColor(AppColors.secondary)
            }
            if review {
                Section("De aprobat") {
                    ForEach(shownVouchers.filter { !$0.isApproved }) { voucher in
                        voucherLink(voucher)
                    }
                }
                Section("Finalizate") {
                    ForEach(shownVouchers.filter(\.isApproved)) { voucher in
                        voucherLink(voucher)
                    }
                }
            } else {
                ForEach(shownVouchers) { voucher in
                    voucherLink(voucher)
                }
            }
        }
        .navigationTitle(L10n.tr("module.cashier.consumption_note"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Caută număr, gestiune sau motiv")
        .safeAreaInset(edge: .top) {
            if review {
                VStack(spacing: 8) {
                    Picker("Punct de lucru", selection: $selectedLocationId) {
                        Text("Toate punctele").tag(Optional<UUID>.none)
                        ForEach(locations) { location in
                            Text(location.denumire).tag(Optional(location.id))
                        }
                    }
                    Picker("Data", selection: $allDates) {
                        Text("Toate").tag(true)
                        Text("O zi").tag(false)
                    }
                    if !allDates {
                        DatePicker("Data", selection: $asOf, displayedComponents: .date)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
        .toolbar {
            if !review {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .appHoverTip(L10n.tr("cashier.consumption_create_title"))
            }
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await load() }
        .sheet(isPresented: $showCreate) {
            ConsumptionVoucherEditorView(existing: nil, lines: []) {
                await load()
            }
            .environmentObject(companyManager)
            .environmentObject(session)
        }
    }

    private func voucherLink(_ voucher: ConsumptionVoucher) -> some View {
        NavigationLink {
            ConsumptionVoucherDetailView(voucher: voucher) {
                Task { await load() }
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.tr("cashier.consumption_number", voucher.numar))
                        .font(.body.weight(.semibold))
                    Spacer()
                    Text(voucher.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(voucher.isDraft ? AppColors.secondary : AppColors.primary)
                }
                Text(voucher.motiv)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(SupplierFormatting.date(voucher.dataBon) + ConsumptionShift.suffix(voucher.shiftNo) + " · " + (voucher.warehouse?.denumire ?? ""))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var shownVouchers: [ConsumptionVoucher] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return vouchers.filter { voucher in
            if review {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Bucharest") ?? .current
                if !allDates && !calendar.isDate(voucher.dataBon, inSameDayAs: asOf) { return false }
                if let selectedLocationId, voucher.warehouse?.workLocationId != selectedLocationId { return false }
            }
            guard !text.isEmpty else { return true }
            return voucher.numar.localizedCaseInsensitiveContains(text)
                || voucher.motiv.localizedCaseInsensitiveContains(text)
                || (voucher.warehouse?.denumire ?? "").localizedCaseInsensitiveContains(text)
        }
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            vouchers = try await ConsumptionVoucherService.fetchVouchers(companyId: companyId)
            if review {
                locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
                    .filter(\.isActive)
                    .sorted { $0.denumire.localizedCaseInsensitiveCompare($1.denumire) == .orderedAscending }
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ConsumptionVoucherDetailView: View {
    let voucher: ConsumptionVoucher
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @Environment(\.presentationMode) private var presentationMode
    @State private var lines: [ConsumptionVoucherLine] = []
    @State private var approved: Set<UUID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var recalcAction: String?

    private var isManager: Bool { !session.isStationCashier }
    private var isCreator: Bool { voucher.createdBy == session.currentProfile?.id }
    private var canEdit: Bool { voucher.isDraft && (isManager || isCreator) }

    var body: some View {
        List {
            Section {
                LabeledContent(L10n.tr("cashier.consumption_field_number"), value: voucher.numar)
                LabeledContent(L10n.tr("cashier.consumption_field_date"), value: SupplierFormatting.date(voucher.dataBon))
                if let shift = ConsumptionShift.label(voucher.shiftNo) {
                    LabeledContent(L10n.tr("cashier.consumption_field_shift"), value: shift)
                }
                LabeledContent(L10n.tr("cashier.consumption_field_warehouse"), value: voucher.warehouse?.denumire ?? "")
                LabeledContent(L10n.tr("cashier.consumption_field_motiv"), value: voucher.motiv)
                LabeledContent(L10n.tr("cashier.consumption_field_status"), value: voucher.statusLabel)
            }
            Section(header: Text(L10n.tr("cashier.consumption_lines"))) {
                ForEach(lines) { line in
                    HStack(alignment: .top) {
                        if isManager {
                            Button {
                                if approved.contains(line.id) {
                                    approved.remove(line.id)
                                } else {
                                    approved.insert(line.id)
                                }
                            } label: {
                                Image(systemName: approved.contains(line.id) ? "checkmark.square.fill" : "square")
                            }
                            .buttonStyle(.borderless)
                        } else if line.aprobat {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.productName)
                            Text(SupplierFormatting.stockQuantityString(line.cantitate) + " " + line.unitateMasura)
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                        Spacer()
                        if !isManager {
                            Text(line.aprobat ? L10n.tr("cashier.consumption_line_yes") : L10n.tr("cashier.consumption_line_no"))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
            }
            if isManager {
                Section {
                    Button(L10n.tr("cashier.consumption_approve_all")) {
                        recalcAction = "approve"
                    }
                    Button(L10n.tr("cashier.consumption_approve_lines")) {
                        recalcAction = "lines"
                    }
                    if !voucher.isDraft {
                        Button(L10n.tr("cashier.consumption_reopen")) {
                            recalcAction = "reopen"
                        }
                    }
                } footer: {
                    Text(L10n.tr("cashier.consumption_approve_hint"))
                }
            }
            if canEdit {
                Section {
                    Button(L10n.tr("common.edit")) { showEditor = true }
                    Button(L10n.tr("common.delete"), role: .destructive) {
                        if voucher.isDraft { confirmDelete = true } else { recalcAction = "delete" }
                    }
                }
            } else if isManager {
                Section {
                    Button(L10n.tr("common.delete"), role: .destructive) { recalcAction = "delete" }
                }
            } else if !voucher.isDraft {
                Section {
                    Text(L10n.tr("cashier.consumption_locked_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
            }
        }
        .navigationTitle(L10n.tr("cashier.consumption_number", voucher.numar))
        .navigationBarTitleDisplayMode(.inline)
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadLines() }
        .sheet(isPresented: $showEditor) {
            ConsumptionVoucherEditorView(existing: voucher, lines: lines) {
                await onChanged()
                presentationMode.wrappedValue.dismiss()
            }
            .environmentObject(companyManager)
            .environmentObject(session)
        }
        .alert(L10n.tr("inventory.edit_recalc_title"), isPresented: Binding(
            get: { recalcAction != nil },
            set: { if !$0 { recalcAction = nil } }
        )) {
            Button(L10n.tr("inventory.edit_recalc_continue")) {
                let action = recalcAction
                recalcAction = nil
                Task {
                    switch action {
                    case "approve": await approveAll()
                    case "lines": await approveSelected()
                    case "reopen": await reopen()
                    case "delete": await delete()
                    default: break
                    }
                }
            }
            Button(L10n.tr("common.cancel"), role: .cancel) { recalcAction = nil }
        } message: {
            Text(L10n.tr("cashier.consumption_recalc_message"))
        }
        .alert(L10n.tr("cashier.consumption_delete_title"), isPresented: $confirmDelete) {
            Button(L10n.tr("common.delete"), role: .destructive) { Task { await delete() } }
            Button(L10n.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("cashier.consumption_delete_confirm", voucher.numar))
        }
    }

    private func loadLines() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lines = try await ConsumptionVoucherService.fetchLines(voucherId: voucher.id)
            approved = Set(lines.filter(\.aprobat).map(\.id))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func approveAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ConsumptionVoucherService.approveAll(id: voucher.id)
            await onChanged()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func approveSelected() async {
        guard !approved.isEmpty else {
            errorMessage = L10n.tr("cashier.consumption_error_approve_none")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await ConsumptionVoucherService.approve(id: voucher.id, lineIds: Array(approved))
            await onChanged()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reopen() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ConsumptionVoucherService.reopen(id: voucher.id)
            await onChanged()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ConsumptionVoucherService.delete(id: voucher.id)
            await onChanged()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConsumptionDraftLine: Identifiable {
    let id = UUID()
    var product: Product
    var quantityText: String
}

struct ConsumptionVoucherEditorView: View {
    let existing: ConsumptionVoucher?
    let lines: [ConsumptionVoucherLine]
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var products: [Product] = []
    @State private var dataBon = Date()
    @State private var shiftNo = ConsumptionShift.current
    @State private var warehouseId: UUID?
    @State private var motiv = ""
    @State private var drafts: [ConsumptionDraftLine] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showProducts = false

    private var sourceWarehouses: [CompanyWarehouse] {
        let active = warehouses.filter(\.isActive)
        guard session.isStationCashier else { return active }
        return active.filter { warehouse in
            guard let locationId = warehouse.workLocationId else { return false }
            return session.stationLocationIds.contains(locationId)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    DateInputField(title: L10n.tr("cashier.consumption_field_date"), date: $dataBon)
                    Picker(L10n.tr("cashier.consumption_field_shift"), selection: $shiftNo) {
                        Text(L10n.tr("cashier.consumption_shift_day")).tag(1)
                        Text(L10n.tr("cashier.consumption_shift_night")).tag(2)
                    }
                    Text(L10n.tr("cashier.consumption_shift_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    Picker(L10n.tr("cashier.consumption_field_warehouse"), selection: $warehouseId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(sourceWarehouses) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }
                    TextField(L10n.tr("cashier.consumption_field_motiv"), text: $motiv)
                    Text(L10n.tr("cashier.consumption_required_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                Section(header: Text(L10n.tr("cashier.consumption_lines"))) {
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(draft.product.denumire)
                                        .lineLimit(2)
                                    Text(draft.product.tip.label)
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondary)
                                }
                                Spacer(minLength: 8)
                                Button {
                                    drafts.removeAll { $0.id == draft.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .appControlHint(L10n.tr("common.delete"))
                            }
                            HStack {
                                Text(L10n.tr("cashier.consumption_field_quantity"))
                                    .foregroundColor(AppColors.secondary)
                                TextField("0", text: $draft.quantityText)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                Text(draft.product.unitateMasura)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { drafts.remove(atOffsets: $0) }
                    Button {
                        showProducts = true
                    } label: {
                        Label(L10n.tr("cashier.consumption_add_line"), systemImage: "plus")
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(existing == nil ? L10n.tr("cashier.consumption_create_title") : L10n.tr("cashier.consumption_edit_title"))
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
            .appTask { await load() }
            .sheet(isPresented: $showProducts) {
                ConsumptionProductPicker(products: availableProducts) { product in
                    drafts.append(ConsumptionDraftLine(product: product, quantityText: ""))
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var availableProducts: [Product] {
        let used = Set(drafts.map(\.product.id))
        return products
            .filter { $0.isActive && !used.contains($0.id) }
            .sorted { $0.denumire.localizedStandardCompare($1.denumire) == .orderedAscending }
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            warehouses = try await WarehouseService.fetchWarehouses(companyId: companyId)
            products = try await ProductService.fetchProducts(companyId: companyId)
            if let existing {
                dataBon = existing.dataBon
                shiftNo = existing.shiftNo ?? ConsumptionShift.current
                warehouseId = existing.warehouseId
                motiv = existing.motiv
                drafts = lines.compactMap { line in
                    guard let product = products.first(where: { $0.id == line.productId }) else { return nil }
                    return ConsumptionDraftLine(
                        product: product,
                        quantityText: SupplierFormatting.stockQuantityString(line.cantitate)
                    )
                }
            } else if warehouseId == nil {
                warehouseId = sourceWarehouses.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        let reason = motiv.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = L10n.tr("cashier.consumption_error_motiv")
            return
        }
        guard let warehouseId else {
            errorMessage = L10n.tr("cashier.consumption_error_warehouse")
            return
        }
        guard let companyId = companyManager.currentCompany?.id else { return }
        guard !drafts.isEmpty else {
            errorMessage = L10n.tr("cashier.consumption_error_lines")
            return
        }
        var payload: [(productId: UUID, quantity: Decimal)] = []
        for draft in drafts {
            guard let quantity = SupplierFormatting.parseAmount(draft.quantityText, maxFractionDigits: SupplierFormatting.stockQuantityMaxFractionDigits),
                  quantity > 0 else {
                errorMessage = L10n.tr("cashier.consumption_error_quantity")
                return
            }
            payload.append((draft.product.id, quantity))
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if let existing {
                try await ConsumptionVoucherService.update(
                    id: existing.id,
                    dataBon: dataBon,
                    shiftNo: shiftNo,
                    warehouseId: warehouseId,
                    motiv: reason,
                    lines: payload
                )
            } else {
                _ = try await ConsumptionVoucherService.post(
                    companyId: companyId,
                    dataBon: dataBon,
                    shiftNo: shiftNo,
                    warehouseId: warehouseId,
                    motiv: reason,
                    lines: payload
                )
            }
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ConsumptionProductPicker: View {
    let products: [Product]
    let onPick: (Product) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var query = ""
    @State private var category = ""

    private var categories: [ProductKind] {
        let present = Set(products.map(\.tip))
        return ProductKind.allCases.filter { present.contains($0) }
    }

    private var filtered: [Product] {
        products.filter { product in
            if !category.isEmpty, product.tip.rawValue != category {
                return false
            }
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return true }
            return product.denumire.localizedCaseInsensitiveContains(text)
                || (product.cod?.localizedCaseInsensitiveContains(text) ?? false)
                || (product.codBare?.localizedCaseInsensitiveContains(text) ?? false)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker(L10n.tr("module.products.filter_categories_all"), selection: $category) {
                    Text(L10n.tr("module.products.filter_categories_all")).tag("")
                    ForEach(categories) { kind in
                        Text(kind.label).tag(kind.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                List(filtered) { product in
                    Button {
                        onPick(product)
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.denumire)
                            Text([product.cod, product.tip.label].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $query, prompt: L10n.tr("inventory.search_prompt"))
            .navigationTitle(L10n.tr("cashier.consumption_add_line"))
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
