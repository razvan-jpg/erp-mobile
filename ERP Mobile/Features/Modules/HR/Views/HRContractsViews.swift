import SwiftUI

struct HRContractsListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var contracts: [HRContract] = []
    @State private var employees: [HREmployee] = []
    @State private var locations: [CompanyWorkLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var contractToEdit: HRContract?
    @State private var contractToDelete: HRContract?
    @State private var showDeleteConfirm = false

    private var filtered: [HRContract] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contracts }
        return contracts.filter { contract in
            employeeName(for: contract).localizedCaseInsensitiveContains(query)
                || contract.jobTitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.hr.contracts_empty"),
                    systemImage: "doc.text.fill",
                    description: Text(access.canCreate
                        ? L10n.tr("module.hr.contracts_empty_create")
                        : L10n.tr("module.hr.contracts_empty_readonly"))
                )
            } else {
                List {
                    ForEach(filtered) { contract in
                        Button { contractToEdit = contract } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(employeeName(for: contract))
                                    .font(.headline)
                                Text("\(contract.jobTitle) · \(SupplierFormatting.date(contract.startDate))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("module.hr.contracts_search"))
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_contracts"))
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
        .appTask(id: companyManager.currentCompany?.id) { await load() }
        .appRefreshable { await load() }
        .fullScreenCover(isPresented: $showCreate) {
            HRContractFormView(mode: .create, access: access, employees: employees, locations: locations) { await load() }
        }
        .fullScreenCover(item: $contractToEdit) { contract in
            HRContractFormView(mode: .edit(contract), access: access, employees: employees, locations: locations) { await load() }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text(L10n.tr("module.hr.contracts_delete_title")),
                message: Text(L10n.tr("module.hr.contracts_delete_confirm")),
                primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                    if let contract = contractToDelete {
                        Task { await delete(contract) }
                    }
                },
                secondaryButton: .cancel { contractToDelete = nil }
            )
        }
    }

    private func employeeName(for contract: HRContract) -> String {
        employees.first { $0.id == contract.employeeId }?.fullName ?? L10n.tr("module.hr.unknown_employee")
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            contracts = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedContracts = HRPersonnelService.fetchContracts(companyId: companyId)
            async let fetchedEmployees = HRPersonnelService.fetchEmployees(companyId: companyId)
            async let fetchedLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            contracts = try await fetchedContracts
            employees = try await fetchedEmployees
            locations = try await fetchedLocations
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        contractToDelete = filtered[index]
        showDeleteConfirm = true
    }

    private func delete(_ contract: HRContract) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await HRPersonnelService.deleteContract(id: contract.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum HRContractFormMode: Identifiable {
    case create
    case edit(HRContract)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let contract): return contract.id.uuidString
        }
    }
}

private struct HRContractFormView: View {
    let mode: HRContractFormMode
    let access: ModuleAccessRights
    let employees: [HREmployee]
    let locations: [CompanyWorkLocation]
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var employeeId: UUID?
    @State private var contractType = HRContractType.cim.rawValue
    @State private var jobTitle = ""
    @State private var corCode = ""
    @State private var locationId: UUID?
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var hoursText = "8"
    @State private var salaryText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        switch mode {
        case .create: return access.canCreate
        case .edit: return access.canEdit
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Picker(L10n.tr("module.hr.field_employee"), selection: $employeeId) {
                    Text(L10n.tr("module.hr.choose_employee")).tag(Optional<UUID>.none)
                    ForEach(employees) { employee in
                        Text("\(employee.fullName) (\(employee.employeeCode))").tag(Optional(employee.id))
                    }
                }
                Picker(L10n.tr("module.hr.field_contract_type"), selection: $contractType) {
                    ForEach(HRContractType.allCases) { type in
                        Text(L10n.tr(type.labelKey)).tag(type.rawValue)
                    }
                }
                FormTextField(title: L10n.tr("module.hr.field_job"), text: $jobTitle, isRequired: true)
                FormTextField(title: L10n.tr("module.hr.field_cor"), text: $corCode)
                Picker(L10n.tr("module.hr.field_location"), selection: $locationId) {
                    Text(L10n.tr("module.hr.no_location")).tag(Optional<UUID>.none)
                    ForEach(locations) { location in
                        Text(location.denumire).tag(Optional(location.id))
                    }
                }
                DatePicker(L10n.tr("module.hr.field_start"), selection: $startDate, displayedComponents: .date)
                Toggle(L10n.tr("module.hr.field_has_end"), isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker(L10n.tr("module.hr.field_end"), selection: $endDate, displayedComponents: .date)
                }
                FormTextField(title: L10n.tr("module.hr.field_hours_day"), text: $hoursText, keyboardType: .decimalPad)
                FormTextField(title: L10n.tr("module.hr.field_gross"), text: $salaryText, keyboardType: .decimalPad)
                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle(mode.id == "create" ? L10n.tr("module.hr.contracts_create") : L10n.tr("module.hr.contracts_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await save() } }
                        .disabled(!canSave || isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .onAppear { populate() }
        }
        .navigationViewStyle(.stack)
    }

    private func populate() {
        guard case .edit(let contract) = mode else { return }
        employeeId = contract.employeeId
        contractType = contract.contractType
        jobTitle = contract.jobTitle
        corCode = contract.corCode ?? ""
        locationId = contract.workLocationId
        startDate = contract.startDate
        if let end = contract.endDate {
            hasEndDate = true
            endDate = end
        }
        hoursText = NSDecimalNumber(decimal: contract.hoursPerDay).stringValue
        salaryText = NSDecimalNumber(decimal: contract.grossSalary).stringValue
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id, let employeeId else {
            errorMessage = L10n.tr("module.hr.validation_contract")
            return
        }
        let title = jobTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
              let hours = SupplierFormatting.parseAmount(hoursText), hours > 0,
              let salary = SupplierFormatting.parseAmount(salaryText) else {
            errorMessage = L10n.tr("module.hr.validation_contract")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let existing: HRContract? = if case .edit(let contract) = mode { contract } else { nil }
            let contract = HRContract(
                id: existing?.id ?? UUID(),
                companyId: companyId,
                employeeId: employeeId,
                contractType: contractType,
                jobTitle: title,
                corCode: corCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : corCode,
                workLocationId: locationId,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                hoursPerDay: hours,
                grossSalary: salary,
                createdAt: existing?.createdAt,
                updatedAt: existing?.updatedAt
            )
            if existing == nil {
                _ = try await HRPersonnelService.createContract(contract)
            } else {
                _ = try await HRPersonnelService.updateContract(contract)
            }
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
