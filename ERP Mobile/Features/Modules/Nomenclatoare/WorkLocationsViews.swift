import SwiftUI

struct WorkLocationsListView: View {
    let access: ModuleAccessRights
    let onChanged: () async -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var locations: [CompanyWorkLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var locationToEdit: CompanyWorkLocation?
    @State private var locationToDelete: CompanyWorkLocation?
    @State private var showDeleteConfirm = false

    private var filteredLocations: [CompanyWorkLocation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return locations }
        return locations.filter {
            $0.denumire.localizedCaseInsensitiveContains(query)
                || ($0.city?.localizedCaseInsensitiveContains(query) ?? false)
                || ($0.county?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredLocations.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.nomenclatoare.work_locations.empty"),
                    systemImage: "mappin.and.ellipse",
                    description: Text(access.canCreate
                        ? L10n.tr("module.nomenclatoare.work_locations.empty_create")
                        : L10n.tr("module.nomenclatoare.work_locations.empty_readonly"))
                )
            } else {
                List {
                    ForEach(filteredLocations) { location in
                        Button {
                            locationToEdit = location
                        } label: {
                            WorkLocationRowView(location: location)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("module.nomenclatoare.work_locations.search_prompt"))
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
        .appTask(id: companyManager.currentCompany?.id) { await loadLocations() }
        .appRefreshable { await loadLocations() }
        .fullScreenCover(isPresented: $showCreate) {
            WorkLocationFormView(mode: .create, access: access) {
                await loadLocations()
                await onChanged()
            }
        }
        .fullScreenCover(item: $locationToEdit) { location in
            WorkLocationFormView(mode: .edit(location), access: access) {
                await loadLocations()
                await onChanged()
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text(L10n.tr("module.nomenclatoare.work_locations.delete_title")),
                message: Text(
                    locationToDelete.map {
                        L10n.tr("module.nomenclatoare.work_locations.delete_confirm", $0.denumire)
                    } ?? ""
                ),
                primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                    if let location = locationToDelete {
                        Task { await deleteLocation(location) }
                    }
                },
                secondaryButton: .cancel {
                    locationToDelete = nil
                }
            )
        }
    }

    private func loadLocations() async {
        guard let companyId = companyManager.currentCompany?.id else {
            locations = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            locations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        locationToDelete = filteredLocations[index]
        showDeleteConfirm = true
    }

    private func deleteLocation(_ location: CompanyWorkLocation) async {
        isLoading = true
        errorMessage = nil
        do {
            try await WorkLocationService.deleteWorkLocation(id: location.id)
            await loadLocations()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct WorkLocationRowView: View {
    let location: CompanyWorkLocation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.denumire)
                    .font(.headline)
                Text(location.displaySubtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if location.isDefault {
                    Text(L10n.tr("module.nomenclatoare.work_locations.badge_default"))
                        .font(.caption2.bold())
                        .foregroundColor(.blue)
                }
                if !location.isActive {
                    Text(L10n.tr("module.nomenclatoare.work_locations.badge_inactive"))
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private enum WorkLocationFormMode: Identifiable {
    case create
    case edit(CompanyWorkLocation)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let location): return location.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("module.nomenclatoare.work_locations.create_title")
        case .edit: return L10n.tr("module.nomenclatoare.work_locations.edit_title")
        }
    }
}

private struct WorkLocationFormView: View {
    let mode: WorkLocationFormMode
    let access: ModuleAccessRights
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTab: FormTab = .general
    @State private var denumire = ""
    @State private var country = "Romania"
    @State private var county = ""
    @State private var city = ""
    @State private var street = ""
    @State private var streetNumber = ""
    @State private var block = ""
    @State private var stair = ""
    @State private var floor = ""
    @State private var apartment = ""
    @State private var postalCode = ""
    @State private var telefon = ""
    @State private var telefonMobil = ""
    @State private var gln = ""
    @State private var isActive = true
    @State private var isDefault = false
    @State private var operatesAtHeadquarters = false
    @State private var isFiscalDomicile = false
    @State private var useInDeclarations = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private enum FormTab: String, CaseIterable, Identifiable {
        case general
        case accounting

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:
                return L10n.tr("module.nomenclatoare.work_locations.tab_general")
            case .accounting:
                return L10n.tr("module.nomenclatoare.work_locations.tab_accounting")
            }
        }
    }

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: DeviceLayout.isRegularWidth(horizontalSizeClass) ? 180 : 150), spacing: 12)]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    FormTextField(
                        title: L10n.tr("module.nomenclatoare.work_locations.field_name"),
                        text: $denumire,
                        isRequired: true
                    )
                    .disabled(!canSave)

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
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await save() }
                        } label: {
                            Label(L10n.tr("common.save"), systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppButtonStyles.borderedProminent)
                        .disabled(!canSave || isLoading || denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .appLegacyAlert(
                isPresented: $showValidationAlert,
                title: L10n.tr("module.nomenclatoare.companies.validation_title"),
                message: validationMessage
            )
            .onAppear {
                populate()
                if case .create = mode {
                    Task { await configureDefaultForFirstLocation() }
                }
            }
            .onChange(of: operatesAtHeadquarters) { enabled in
                if enabled {
                    applyHeadquartersAddress()
                }
            }
            .onChange(of: isFiscalDomicile) { enabled in
                if !enabled {
                    useInDeclarations = false
                }
            }
        }
    }

    private var generalTabContent: some View {
        VStack(spacing: 0) {
            WorkLocationSectionHeader(title: L10n.tr("module.nomenclatoare.work_locations.section_address"))
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_country"), text: $country)
                        .disabled(!canSave || operatesAtHeadquarters)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_county"), text: $county)
                        .disabled(!canSave || operatesAtHeadquarters)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_city"), text: $city)
                        .disabled(!canSave || operatesAtHeadquarters)
                }

                HStack(spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_street"), text: $street)
                        .disabled(!canSave || operatesAtHeadquarters)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_street_number"), text: $streetNumber)
                        .disabled(!canSave || operatesAtHeadquarters)
                }

                HStack(spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_block"), text: $block)
                        .disabled(!canSave || operatesAtHeadquarters)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_stair"), text: $stair)
                        .disabled(!canSave || operatesAtHeadquarters)
                }

                HStack(spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.work_locations.field_floor"), text: $floor)
                        .disabled(!canSave || operatesAtHeadquarters)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_apartment"), text: $apartment)
                        .disabled(!canSave || operatesAtHeadquarters)
                }

                FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_postal_code"), text: $postalCode)
                    .disabled(!canSave || operatesAtHeadquarters)

                LazyVGrid(columns: gridColumns, spacing: 12) {
                    FormTextField(title: L10n.tr("common.field_phone"), text: $telefon, keyboardType: .phonePad)
                        .disabled(!canSave)
                    FormTextField(
                        title: L10n.tr("module.nomenclatoare.work_locations.field_mobile_phone"),
                        text: $telefonMobil,
                        keyboardType: .phonePad
                    )
                    .disabled(!canSave)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_gln"), text: $gln)
                        .disabled(!canSave)
                }
            }
            .padding(12)

            WorkLocationSectionHeader(title: L10n.tr("module.nomenclatoare.work_locations.section_properties"))
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $isActive) {
                    Text(L10n.tr("module.nomenclatoare.work_locations.field_active"))
                }
                .disabled(!canSave)

                Toggle(isOn: $isDefault) {
                    Text(L10n.tr("module.nomenclatoare.work_locations.field_default"))
                }
                .disabled(!canSave)

                Toggle(isOn: $operatesAtHeadquarters) {
                    Text(L10n.tr("module.nomenclatoare.work_locations.field_operates_at_hq"))
                }
                .disabled(!canSave)

                Toggle(isOn: $isFiscalDomicile) {
                    Text(L10n.tr("module.nomenclatoare.work_locations.field_fiscal_domicile"))
                }
                .disabled(!canSave)

                Toggle(isOn: $useInDeclarations) {
                    Text(L10n.tr("module.nomenclatoare.work_locations.field_use_in_declarations"))
                }
                .disabled(!canSave || !isFiscalDomicile)
            }
            .padding(12)
        }
    }

    private var accountingTabContent: some View {
        AppEmptyStateView(
            L10n.tr("module.nomenclatoare.work_locations.tab_accounting"),
            systemImage: "list.bullet.rectangle",
            description: Text(L10n.tr("module.nomenclatoare.work_locations.accounting_placeholder"))
        )
        .frame(minHeight: 220)
    }

    private func populate() {
        switch mode {
        case .create:
            break
        case .edit(let location):
            denumire = location.denumire
            country = location.country ?? "Romania"
            county = location.county ?? ""
            city = location.city ?? ""
            street = location.street ?? ""
            streetNumber = location.streetNumber ?? ""
            block = location.block ?? ""
            stair = location.stair ?? ""
            floor = location.floor ?? ""
            apartment = location.apartment ?? ""
            postalCode = location.postalCode ?? ""
            telefon = location.telefon ?? ""
            telefonMobil = location.telefonMobil ?? ""
            gln = location.gln ?? ""
            isActive = location.isActive
            isDefault = location.isDefault
            operatesAtHeadquarters = location.operatesAtHeadquarters
            isFiscalDomicile = location.isFiscalDomicile
            useInDeclarations = location.useInDeclarations
        }
        errorMessage = nil
    }

    private func configureDefaultForFirstLocation() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        do {
            let existing = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            if existing.isEmpty {
                isDefault = true
            }
        } catch {
            // Keep current default flag.
        }
    }

    private func applyHeadquartersAddress() {
        guard let company = companyManager.currentCompany else { return }
        country = company.hqCountry ?? "Romania"
        county = company.hqCounty ?? ""
        city = company.hqCity ?? ""
        street = company.hqStreet ?? ""
        streetNumber = company.hqStreetNumber ?? ""
        block = company.hqBlock ?? ""
        stair = company.hqStair ?? ""
        apartment = company.hqApartment ?? ""
        postalCode = company.hqPostalCode ?? ""
        gln = company.hqGln ?? ""
        telefon = company.telefon ?? ""
    }

    private func validate() -> Bool {
        if denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = L10n.tr("module.nomenclatoare.work_locations.validation_name")
            showValidationAlert = true
            return false
        }
        return true
    }

    private func buildLocation() -> CompanyWorkLocation? {
        guard let companyId = companyManager.currentCompany?.id else { return nil }
        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            return CompanyWorkLocation(
                id: UUID(),
                companyId: companyId,
                denumire: trimmedName,
                country: emptyToNil(country),
                county: emptyToNil(county),
                city: emptyToNil(city),
                street: emptyToNil(street),
                streetNumber: emptyToNil(streetNumber),
                block: emptyToNil(block),
                stair: emptyToNil(stair),
                floor: emptyToNil(floor),
                apartment: emptyToNil(apartment),
                postalCode: emptyToNil(postalCode),
                telefon: emptyToNil(telefon),
                telefonMobil: emptyToNil(telefonMobil),
                gln: emptyToNil(gln),
                isActive: isActive,
                isDefault: isDefault,
                operatesAtHeadquarters: operatesAtHeadquarters,
                isFiscalDomicile: isFiscalDomicile,
                useInDeclarations: isFiscalDomicile ? useInDeclarations : false,
                createdAt: nil,
                updatedAt: nil
            )
        case .edit(let existing):
            return CompanyWorkLocation(
                id: existing.id,
                companyId: existing.companyId,
                denumire: trimmedName,
                country: emptyToNil(country),
                county: emptyToNil(county),
                city: emptyToNil(city),
                street: emptyToNil(street),
                streetNumber: emptyToNil(streetNumber),
                block: emptyToNil(block),
                stair: emptyToNil(stair),
                floor: emptyToNil(floor),
                apartment: emptyToNil(apartment),
                postalCode: emptyToNil(postalCode),
                telefon: emptyToNil(telefon),
                telefonMobil: emptyToNil(telefonMobil),
                gln: emptyToNil(gln),
                isActive: isActive,
                isDefault: isDefault,
                operatesAtHeadquarters: operatesAtHeadquarters,
                isFiscalDomicile: isFiscalDomicile,
                useInDeclarations: isFiscalDomicile ? useInDeclarations : false,
                createdAt: existing.createdAt,
                updatedAt: existing.updatedAt
            )
        }
    }

    private func save() async {
        guard validate(), let location = buildLocation() else { return }
        isLoading = true
        errorMessage = nil
        do {
            switch mode {
            case .create:
                _ = try await WorkLocationService.createWorkLocation(location)
            case .edit:
                _ = try await WorkLocationService.updateWorkLocation(location)
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

private struct WorkLocationSectionHeader: View {
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
