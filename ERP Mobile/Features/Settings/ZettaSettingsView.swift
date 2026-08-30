import SwiftUI

struct ZettaSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var settings = CompanyZettaSettings.defaults(companyId: UUID())
    @State private var workLocations: [CompanyWorkLocation] = []
    @State private var warehousesCreated = 0
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var hasMultipleWorkLocations: Bool {
        workLocations.count > 1
    }

    private var missingWorkLocation: Bool {
        workLocations.isEmpty
    }

    var body: some View {
        ZStack {
            AdaptiveFormContainer(maxWidth: 480) {
                Form {
                if let company = companyManager.currentCompany {
                    Section(header: Text(L10n.tr("settings.zetta.company_section"))) {
                        Text(company.denumire)
                            .font(.headline)
                    }
                }

                if missingWorkLocation {
                    Section {
                        Text(L10n.tr("settings.zetta.no_work_location"))
                            .foregroundColor(.orange)
                        Text(L10n.tr("settings.zetta.no_work_location_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }

                shiftsSection
                workLocationsSection
                headquartersCasaSection
                paymentMethodsSection
                vatReportSection

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .frame(maxWidth: 220)
                    .disabled(isLoading || isSaving || missingWorkLocation)
                }
                }
            }
            .appScrollBottomPadding()
            .navigationTitle(L10n.tr("settings.zetta.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(isLoading || isSaving || missingWorkLocation)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading || isSaving) }
            .appTask(id: companyManager.currentCompany?.id) { await load() }
        }
    }

    // MARK: - Sections

    private var shiftsSection: some View {
        Section(header: Text(L10n.tr("settings.zetta.shifts_section"))) {
            Toggle(L10n.tr("settings.zetta.multiple_shifts"), isOn: multipleShiftsBinding)
            if settings.payload.multipleShiftsPerRegister {
                Stepper(
                    value: shiftsCountBinding,
                    in: 2...10,
                    step: 1
                ) {
                    Text(L10n.tr("settings.zetta.shifts_count", settings.payload.shiftsPerRegisterCount))
                }
            }
        }
    }

    @ViewBuilder
    private var workLocationsSection: some View {
        if hasMultipleWorkLocations {
            Section(header: Text(L10n.tr("settings.zetta.locations_section"))) {
                Toggle(
                    L10n.tr("settings.zetta.multiple_registers"),
                    isOn: multipleRegistersBinding
                )
                Text(L10n.tr("settings.zetta.multiple_registers_hint", workLocations.count))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)

                if settings.payload.usesRegistersOnMultipleWorkLocations {
                    ForEach(workLocations) { location in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(location.denumire)
                                .font(.subheadline.bold())
                            ZettaAccountField(
                                account: sanitizedAccountBinding(
                                    get: { settings.payload.account(for: location.id) },
                                    set: { settings.payload.setAccount($0, for: location.id) }
                                )
                            )
                        }
                    }
                }
            }
        } else if let location = workLocations.first {
            Section(header: Text(L10n.tr("settings.zetta.locations_section"))) {
                Text(location.denumire)
                    .font(.subheadline.bold())
                ZettaAccountField(
                    account: sanitizedAccountBinding(
                        get: { settings.payload.account(for: location.id) },
                        set: { settings.payload.setAccount($0, for: location.id) }
                    )
                )
            }
        }
    }

    private var paymentMethodsSection: some View {
        Section(header: Text(L10n.tr("settings.zetta.payments_section"))) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.zetta.card_account"))
                    .font(.subheadline.bold())
                ZettaAccountField(
                    account: sanitizedAccountBinding(
                        get: { settings.payload.cardPaymentAccount },
                        set: { settings.payload.cardPaymentAccount = $0 }
                    )
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("settings.zetta.modern_payment_account"))
                    .font(.subheadline.bold())
                ZettaAccountField(
                    account: sanitizedAccountBinding(
                        get: { settings.payload.modernPaymentAccount },
                        set: { settings.payload.modernPaymentAccount = $0 }
                    )
                )
            }
        }
    }

    private var headquartersCasaSection: some View {
        Section(header: Text(L10n.tr("settings.zetta.headquarters_section"))) {
            ZettaAccountField(
                account: sanitizedAccountBinding(
                    get: { settings.payload.headquartersCasaAccount },
                    set: { settings.payload.headquartersCasaAccount = $0 }
                )
            )
            Text(L10n.tr("settings.zetta.headquarters_casa_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
    }

    private var vatReportSection: some View {
        Group {
            ForEach(ZettaVatSlot.allCases) { slot in
                ZettaVatCategorySection(
                    slot: slot,
                    settings: vatBinding(for: slot)
                )
            }
        }
    }

    // MARK: - Bindings

    private var multipleShiftsBinding: Binding<Bool> {
        Binding(
            get: { settings.payload.multipleShiftsPerRegister },
            set: { settings.payload.multipleShiftsPerRegister = $0 }
        )
    }

    private var shiftsCountBinding: Binding<Int> {
        Binding(
            get: { settings.payload.shiftsPerRegisterCount },
            set: { settings.payload.shiftsPerRegisterCount = $0 }
        )
    }

    private var multipleRegistersBinding: Binding<Bool> {
        Binding(
            get: { settings.payload.usesRegistersOnMultipleWorkLocations },
            set: { settings.payload.usesRegistersOnMultipleWorkLocations = $0 }
        )
    }

    private func vatBinding(for slot: ZettaVatSlot) -> Binding<ZettaVatCategorySettings> {
        Binding(
            get: { settings.payload.vatSettings(for: slot) },
            set: { settings.payload.setVatSettings($0, for: slot) }
        )
    }

    private func sanitizedAccountBinding(get: @escaping () -> String, set: @escaping (String) -> Void) -> Binding<String> {
        Binding(
            get: get,
            set: { set(ZettaAccountInput.sanitize($0)) }
        )
    }

    // MARK: - Data

    @MainActor
    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            workLocations = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            warehousesCreated = try await ZettaSettingsService.ensureWarehousesForWorkLocations(companyId: companyId)
            workLocations = try await WorkLocationService.fetchWorkLocations(companyId: companyId)
            var loaded = try await ZettaSettingsService.fetchSettings(companyId: companyId)
            loaded.payload.syncLocationAccounts(with: workLocations)
            settings = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        guard !workLocations.isEmpty else {
            errorMessage = L10n.tr("settings.zetta.validation_work_location")
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            _ = try await ZettaSettingsService.ensureWarehousesForWorkLocations(companyId: companyId)
            settings.companyId = companyId
            settings.payload.syncLocationAccounts(with: workLocations)
            settings = try await ZettaSettingsService.saveSettings(settings)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Account input

private enum ZettaAccountInput {
    static let maxLength = 10

    static func sanitize(_ raw: String) -> String {
        let filtered = raw.filter { $0.isNumber || $0 == "." }
        return String(filtered.prefix(maxLength))
    }
}

private struct ZettaAccountField: View {
    @Binding var account: String

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.tr("settings.zetta.account_used"))
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
                .frame(maxWidth: 120, alignment: .leading)
            TextField(
                L10n.tr("settings.zetta.account_example"),
                text: $account
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140)
#if os(iOS)
            .keyboardType(.numbersAndPunctuation)
#endif
        }
    }
}

// MARK: - VAT category section

private struct ZettaVatCategorySection: View {
    let slot: ZettaVatSlot
    @Binding var settings: ZettaVatCategorySettings

    private var visibleCategories: [ZettaSalesCategory] {
        settings.rate == .zero ? [.sgr, .bacsis] : ZettaSalesCategory.configurableCases
    }

    var body: some View {
        Section(header: Text(L10n.tr("settings.zetta.vat_slot", slot.rawValue))) {
            Toggle(L10n.tr("settings.zetta.vat_enabled"), isOn: $settings.isEnabled)

            if settings.isEnabled {
                Picker(L10n.tr("settings.zetta.vat_rate"), selection: $settings.rate) {
                    ForEach(ZettaVatRateOption.allCases) { rate in
                        Text(rate.label).tag(rate)
                    }
                }
                .onChange(of: settings.rate) { newRate in
                    syncSalesMappingsForRate(newRate)
                }

                Text(L10n.tr("settings.zetta.sales_type"))
                    .font(.subheadline.bold())
                    .padding(.top, 4)

                Picker(L10n.tr("settings.zetta.sales_type"), selection: selectedCategoryBinding) {
                    Text(L10n.tr("settings.zetta.sales_none")).tag(Optional<ZettaSalesCategory>.none)
                    ForEach(visibleCategories) { category in
                        Text(category.label).tag(Optional(category))
                    }
                }
                .pickerStyle(.menu)

                if let index = selectedMappingIndex {
                    ZettaAccountField(account: mappingAccountBinding(at: index))
                }
            }
        }
        .onAppear {
            syncSalesMappingsForRate(settings.rate)
            enforceSingleSelection()
        }
    }

    private var selectedMappingIndex: Int? {
        guard let category = settings.salesMappings.first(where: \.isEnabled)?.category,
              visibleCategories.contains(category) else { return nil }
        return settings.salesMappings.firstIndex(where: { $0.category == category })
    }

    private var selectedCategoryBinding: Binding<ZettaSalesCategory?> {
        Binding(
            get: {
                settings.salesMappings.first(where: { $0.isEnabled && visibleCategories.contains($0.category) })?.category
            },
            set: { newCategory in
                for index in settings.salesMappings.indices {
                    let isSelected = settings.salesMappings[index].category == newCategory
                    settings.salesMappings[index].isEnabled = isSelected
                    if isSelected, settings.salesMappings[index].account.isEmpty {
                        settings.salesMappings[index].account = settings.salesMappings[index].category.defaultAccount
                    }
                }
            }
        )
    }

    private func mappingAccountBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { settings.salesMappings[index].account },
            set: { settings.salesMappings[index].account = ZettaAccountInput.sanitize($0) }
        )
    }

    private func syncSalesMappingsForRate(_ rate: ZettaVatRateOption) {
        for index in settings.salesMappings.indices {
            let category = settings.salesMappings[index].category
            if rate == .zero {
                if !category.hasFixedAccount {
                    settings.salesMappings[index].isEnabled = false
                }
            } else if category.hasFixedAccount {
                settings.salesMappings[index].isEnabled = false
            }
        }
        enforceSingleSelection()
    }

    /// Păstrează cel mult o opțiune activă pe cotă.
    private func enforceSingleSelection() {
        let active = settings.salesMappings.enumerated().filter { $0.element.isEnabled && visibleCategories.contains($0.element.category) }
        guard active.count > 1 else { return }
        let keep = active[0].offset
        for index in settings.salesMappings.indices where index != keep {
            settings.salesMappings[index].isEnabled = false
        }
    }
}

#Preview {
    NavigationView {
        ZettaSettingsView()
            .environmentObject(CompanyManager())
    }
}
