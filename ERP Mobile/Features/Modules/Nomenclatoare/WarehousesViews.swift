import SwiftUI

struct WarehousesListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var warehouseToEdit: CompanyWarehouse?
    @State private var warehouseToDelete: CompanyWarehouse?
    @State private var showDeleteConfirm = false

    private var filteredWarehouses: [CompanyWarehouse] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return warehouses }
        return warehouses.filter {
            $0.denumire.localizedCaseInsensitiveContains(query)
                || $0.cod.localizedCaseInsensitiveContains(query)
                || $0.workLocationName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if filteredWarehouses.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.nomenclatoare.warehouses.empty"),
                    systemImage: "shippingbox.fill",
                    description: Text(access.canCreate
                        ? L10n.tr("module.nomenclatoare.warehouses.empty_create")
                        : L10n.tr("module.nomenclatoare.warehouses.empty_readonly"))
                )
            } else {
                List {
                    ForEach(filteredWarehouses) { warehouse in
                        Button {
                            warehouseToEdit = warehouse
                        } label: {
                            WarehouseRowView(warehouse: warehouse)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("module.nomenclatoare.warehouses.search_prompt"))
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
        .appTask(id: companyManager.currentCompany?.id) { await loadWarehouses() }
        .appRefreshable { await loadWarehouses() }
        .fullScreenCover(isPresented: $showCreate) {
            WarehouseFormView(mode: .create, access: access) {
                await loadWarehouses()
                await onChanged()
            }
        }
        .fullScreenCover(item: $warehouseToEdit) { warehouse in
            WarehouseFormView(mode: .edit(warehouse), access: access) {
                await loadWarehouses()
                await onChanged()
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text(L10n.tr("module.nomenclatoare.warehouses.delete_title")),
                message: Text(
                    warehouseToDelete.map {
                        L10n.tr("module.nomenclatoare.warehouses.delete_confirm", $0.denumire)
                    } ?? ""
                ),
                primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                    if let warehouse = warehouseToDelete {
                        Task { await deleteWarehouse(warehouse) }
                    }
                },
                secondaryButton: .cancel {
                    warehouseToDelete = nil
                }
            )
        }
    }

    private func loadWarehouses() async {
        guard let companyId = companyManager.currentCompany?.id else {
            warehouses = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            warehouses = try await WarehouseService.fetchWarehouses(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        warehouseToDelete = filteredWarehouses[index]
        showDeleteConfirm = true
    }

    private func deleteWarehouse(_ warehouse: CompanyWarehouse) async {
        isLoading = true
        errorMessage = nil
        do {
            try await WarehouseService.deleteWarehouse(id: warehouse.id)
            await loadWarehouses()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct WarehouseRowView: View {
    let warehouse: CompanyWarehouse

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(warehouse.denumire)
                    .font(.headline)
                Text(warehouse.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            Spacer(minLength: 0)
            if !warehouse.isActive {
                Text(L10n.tr("module.nomenclatoare.warehouses.badge_inactive"))
                    .font(.caption2.bold())
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

private enum WarehouseFormMode: Identifiable {
    case create
    case edit(CompanyWarehouse)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let warehouse): return warehouse.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("module.nomenclatoare.warehouses.create_title")
        case .edit: return L10n.tr("module.nomenclatoare.warehouses.edit_title")
        }
    }
}

private struct WarehouseFormView: View {
    let mode: WarehouseFormMode
    let access: ModuleAccessRights
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: FormTab = .general
    @State private var cod = ""
    @State private var denumire = ""
    @State private var warehouseType: WarehouseType = .enDetail
    @State private var selectedWorkLocationId: UUID?
    @State private var selectedPartner: WarehousePartnerLink = .none
    @State private var isCustody = false
    @State private var allowsStockReservation = false
    @State private var isLohn = false
    @State private var managerName = ""
    @State private var adresa = ""
    @State private var additionalInfo = ""
    @State private var isActive = true
    @State private var workLocations: [CompanyWorkLocation] = []
    @State private var partnerOptions: [WarehousePartnerLink] = [.none]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private enum FormTab: String, CaseIterable, Identifiable {
        case general
        case accounting
        case additional

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                return L10n.tr("module.nomenclatoare.warehouses.tab_general")
            case .accounting:
                return L10n.tr("module.nomenclatoare.warehouses.tab_accounting")
            case .additional:
                return L10n.tr("module.nomenclatoare.warehouses.tab_additional")
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: DeviceLayout.isRegularWidth(horizontalSizeClass) ? 200 : 160), spacing: 12)]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        FormTextField(
                            title: L10n.tr("module.nomenclatoare.warehouses.field_code"),
                            text: $cod,
                            isRequired: true
                        )
                        .disabled(!canSave || isEditing)

                        FormTextField(
                            title: L10n.tr("module.nomenclatoare.warehouses.field_name"),
                            text: $denumire,
                            isRequired: true
                        )
                        .disabled(!canSave)
                    }

                    Picker(L10n.tr("module.nomenclatoare.companies.section_picker"), selection: $selectedTab) {
                        ForEach(FormTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case .general:
                        generalTabContent
                    case .accounting:
                        accountingTabContent
                    case .additional:
                        additionalTabContent
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        // Placeholder pentru sabloane articole
                    } label: {
                        Label(L10n.tr("module.nomenclatoare.warehouses.article_templates"), systemImage: "square.grid.2x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyles.bordered)
                    .disabled(true)

                    HStack(spacing: 12) {
                        Button {
                            Task { await save() }
                        } label: {
                            Label(L10n.tr("common.save"), systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppButtonStyles.borderedProminent)
                        .disabled(!canSave || isLoading || !isFormValid)

                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Label(L10n.tr("common.exit"), systemImage: "xmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppButtonStyles.bordered)
                    }
                }
                .padding()
                .frame(maxWidth: DeviceLayout.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .appScrollBottomPadding()
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("module.nomenclatoare.warehouses.modification_history")) {}
                        .disabled(true)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appLegacyAlert(
                isPresented: $showValidationAlert,
                title: L10n.tr("module.nomenclatoare.companies.validation_title"),
                message: validationMessage
            )
            .appTask { await loadReferenceData() }
            .onAppear { populate() }
        }
    }

    private var isFormValid: Bool {
        !cod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var generalTabContent: some View {
        VStack(spacing: 0) {
            WarehouseSectionHeader(title: L10n.tr("module.nomenclatoare.warehouses.section_general"))
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    warehouseTypePicker
                    workLocationPicker
                    partnerPicker
                }

                HStack(spacing: 16) {
                    Toggle(isOn: $isCustody) {
                        Text(L10n.tr("module.nomenclatoare.warehouses.field_custody"))
                    }
                    .disabled(!canSave)

                    Toggle(isOn: $allowsStockReservation) {
                        Text(L10n.tr("module.nomenclatoare.warehouses.field_stock_reservation"))
                    }
                    .disabled(!canSave)
                }

                Toggle(isOn: $isLohn) {
                    Text(L10n.tr("module.nomenclatoare.warehouses.field_lohn"))
                }
                .disabled(true)

                FormTextField(
                    title: L10n.tr("module.nomenclatoare.warehouses.field_manager"),
                    text: $managerName
                )
                .disabled(!canSave)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("module.nomenclatoare.warehouses.field_address"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    MultilineTextField(
                        placeholder: L10n.tr("module.nomenclatoare.warehouses.field_address"),
                        text: $adresa
                    )
                    .disabled(!canSave)
                }

                Toggle(isOn: $isActive) {
                    Text(L10n.tr("module.nomenclatoare.warehouses.field_active"))
                }
                .disabled(!canSave)
            }
            .padding(12)
        }
    }

    private var warehouseTypePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("module.nomenclatoare.warehouses.field_type"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Picker(L10n.tr("module.nomenclatoare.warehouses.field_type"), selection: $warehouseType) {
                ForEach(WarehouseType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.menu)
            .disabled(!canSave)
        }
    }

    private var workLocationPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("module.nomenclatoare.warehouses.field_work_location"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Picker(L10n.tr("module.nomenclatoare.warehouses.field_work_location"), selection: $selectedWorkLocationId) {
                Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                ForEach(workLocations) { location in
                    Text(location.denumire).tag(Optional(location.id))
                }
            }
            .pickerStyle(.menu)
            .disabled(!canSave)
        }
    }

    private var partnerPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("module.nomenclatoare.warehouses.field_partner"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            Picker(L10n.tr("module.nomenclatoare.warehouses.field_partner"), selection: $selectedPartner) {
                ForEach(partnerOptions) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .disabled(!canSave)
        }
    }

    private var accountingTabContent: some View {
        AppEmptyStateView(
            L10n.tr("module.nomenclatoare.warehouses.tab_accounting"),
            systemImage: "list.bullet.rectangle",
            description: Text(L10n.tr("module.nomenclatoare.warehouses.accounting_placeholder"))
        )
        .frame(minHeight: 220)
    }

    private var additionalTabContent: some View {
        VStack(spacing: 0) {
            WarehouseSectionHeader(title: L10n.tr("module.nomenclatoare.warehouses.tab_additional"))
            VStack(alignment: .leading, spacing: 4) {
                MultilineTextField(
                    placeholder: L10n.tr("module.nomenclatoare.warehouses.additional_placeholder"),
                    text: $additionalInfo
                )
                .disabled(!canSave)
            }
            .padding(12)
        }
    }

    private func loadReferenceData() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        do {
            async let locationsTask = WorkLocationService.fetchWorkLocations(companyId: companyId)
            async let partnersTask = PartnerService.fetchPartnerListRows()
            let (locations, partners) = try await (locationsTask, partnersTask)
            workLocations = locations.filter(\.isActive)
            partnerOptions = WarehousePartnerLink.options(from: partners)

            if case .create = mode, cod.isEmpty {
                cod = try await WarehouseService.suggestNextCod(companyId: companyId)
            }
            if selectedWorkLocationId == nil {
                selectedWorkLocationId = workLocations.first(where: \.isDefault)?.id ?? workLocations.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func populate() {
        switch mode {
        case .create:
            warehouseType = .enDetail
            isActive = true
        case .edit(let warehouse):
            cod = warehouse.cod
            denumire = warehouse.denumire
            warehouseType = warehouse.warehouseType
            selectedWorkLocationId = warehouse.workLocationId
            selectedPartner = WarehousePartnerLink.from(warehouse: warehouse)
            isCustody = warehouse.isCustody
            allowsStockReservation = warehouse.allowsStockReservation
            isLohn = warehouse.isLohn
            managerName = warehouse.managerName ?? ""
            adresa = warehouse.adresa ?? ""
            additionalInfo = warehouse.additionalInfo ?? ""
            isActive = warehouse.isActive
        }
        errorMessage = nil
    }

    private func validate() -> Bool {
        if cod.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = L10n.tr("module.nomenclatoare.warehouses.validation_code")
            showValidationAlert = true
            return false
        }
        if denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = L10n.tr("module.nomenclatoare.warehouses.validation_name")
            showValidationAlert = true
            return false
        }
        return true
    }

    private func buildWarehouse() -> CompanyWarehouse? {
        guard let companyId = companyManager.currentCompany?.id else { return nil }

        let partnerSupplierId: UUID?
        let partnerClientId: UUID?
        switch selectedPartner {
        case .none:
            partnerSupplierId = nil
            partnerClientId = nil
        case .supplier(let id, _):
            partnerSupplierId = id
            partnerClientId = nil
        case .client(let id, _):
            partnerSupplierId = nil
            partnerClientId = id
        }

        switch mode {
        case .create:
            return CompanyWarehouse(
                id: UUID(),
                companyId: companyId,
                cod: cod.trimmingCharacters(in: .whitespacesAndNewlines),
                denumire: denumire.trimmingCharacters(in: .whitespacesAndNewlines),
                warehouseType: warehouseType,
                workLocationId: selectedWorkLocationId,
                partnerSupplierId: partnerSupplierId,
                partnerClientId: partnerClientId,
                isCustody: isCustody,
                allowsStockReservation: allowsStockReservation,
                isLohn: isLohn,
                managerName: emptyToNil(managerName),
                adresa: emptyToNil(adresa),
                additionalInfo: emptyToNil(additionalInfo),
                isActive: isActive,
                createdAt: nil,
                updatedAt: nil,
                workLocation: nil,
                partnerSupplier: nil,
                partnerClient: nil
            )
        case .edit(let existing):
            return CompanyWarehouse(
                id: existing.id,
                companyId: existing.companyId,
                cod: existing.cod,
                denumire: denumire.trimmingCharacters(in: .whitespacesAndNewlines),
                warehouseType: warehouseType,
                workLocationId: selectedWorkLocationId,
                partnerSupplierId: partnerSupplierId,
                partnerClientId: partnerClientId,
                isCustody: isCustody,
                allowsStockReservation: allowsStockReservation,
                isLohn: isLohn,
                managerName: emptyToNil(managerName),
                adresa: emptyToNil(adresa),
                additionalInfo: emptyToNil(additionalInfo),
                isActive: isActive,
                createdAt: existing.createdAt,
                updatedAt: existing.updatedAt,
                workLocation: existing.workLocation,
                partnerSupplier: existing.partnerSupplier,
                partnerClient: existing.partnerClient
            )
        }
    }

    private func save() async {
        guard validate(), let warehouse = buildWarehouse() else { return }
        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                _ = try await WarehouseService.createWarehouse(warehouse)
            case .edit:
                _ = try await WarehouseService.updateWarehouse(warehouse)
            }
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct WarehouseSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
    }
}
