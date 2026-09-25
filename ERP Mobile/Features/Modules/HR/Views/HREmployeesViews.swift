import SwiftUI

struct HREmployeesListView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var employees: [HREmployee] = []
    @State private var locations: [CompanyWorkLocation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showCreate = false
    @State private var employeeToEdit: HREmployee?
    @State private var employeeToDelete: HREmployee?
    @State private var showDeleteConfirm = false

    private var filtered: [HREmployee] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return employees }
        return employees.filter {
            $0.fullName.localizedCaseInsensitiveContains(query)
                || $0.employeeCode.localizedCaseInsensitiveContains(query)
                || ($0.cnp?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.hr.employees_empty"),
                    systemImage: "person.crop.rectangle.stack",
                    description: Text(access.canCreate
                        ? L10n.tr("module.hr.employees_empty_create")
                        : L10n.tr("module.hr.employees_empty_readonly"))
                )
            } else {
                List {
                    ForEach(filtered) { employee in
                        Button { employeeToEdit = employee } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(employee.fullName)
                                    .font(.headline)
                                Text("\(employee.employeeCode)\(employee.isActive ? "" : " · \(L10n.tr("module.hr.inactive"))")")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: access.canDelete ? deleteItems : { _ in })
                }
                .appSearchable(text: $searchText, prompt: L10n.tr("module.hr.employees_search"))
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_employees"))
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
            HREmployeeFormView(mode: .create, access: access, locations: locations) { await load() }
        }
        .fullScreenCover(item: $employeeToEdit) { employee in
            HREmployeeFormView(mode: .edit(employee), access: access, locations: locations) { await load() }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text(L10n.tr("module.hr.employees_delete_title")),
                message: Text(employeeToDelete.map { L10n.tr("module.hr.employees_delete_confirm", $0.fullName) } ?? ""),
                primaryButton: .destructive(Text(L10n.tr("common.delete"))) {
                    if let employee = employeeToDelete {
                        Task { await delete(employee) }
                    }
                },
                secondaryButton: .cancel { employeeToDelete = nil }
            )
        }
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            employees = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedEmployees = HRPersonnelService.fetchEmployees(companyId: companyId)
            async let fetchedLocations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            employees = try await fetchedEmployees
            locations = try await fetchedLocations
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        employeeToDelete = filtered[index]
        showDeleteConfirm = true
    }

    private func delete(_ employee: HREmployee) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await HRPersonnelService.deleteEmployee(id: employee.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum HREmployeeFormMode: Identifiable {
    case create
    case edit(HREmployee)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let employee): return employee.id.uuidString
        }
    }
}

private struct HREmployeeFormView: View {
    let mode: HREmployeeFormMode
    let access: ModuleAccessRights
    let locations: [CompanyWorkLocation]
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var code = ""
    @State private var name = ""
    @State private var cnp = ""
    @State private var iban = ""
    @State private var phone = ""
    @State private var locationId: UUID?
    @State private var isActive = true
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
                FormTextField(title: L10n.tr("module.hr.field_code"), text: $code, isRequired: true)
                FormTextField(title: L10n.tr("module.hr.field_name"), text: $name, isRequired: true)
                FormTextField(title: L10n.tr("module.hr.field_cnp"), text: $cnp, keyboardType: .numberPad)
                FormTextField(title: L10n.tr("module.hr.field_iban"), text: $iban, autocapitalization: .characters)
                FormTextField(title: L10n.tr("module.hr.field_phone"), text: $phone, keyboardType: .phonePad)
                Picker(L10n.tr("module.hr.field_location"), selection: $locationId) {
                    Text(L10n.tr("module.hr.no_location")).tag(Optional<UUID>.none)
                    ForEach(locations) { location in
                        Text(location.denumire).tag(Optional(location.id))
                    }
                }
                Toggle(L10n.tr("module.hr.field_active"), isOn: $isActive)
                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle(mode.id == "create" ? L10n.tr("module.hr.employees_create") : L10n.tr("module.hr.employees_edit"))
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
        guard case .edit(let employee) = mode else { return }
        code = employee.employeeCode
        name = employee.fullName
        cnp = employee.cnp ?? ""
        iban = employee.iban ?? ""
        phone = employee.phone ?? ""
        locationId = employee.defaultWorkLocationId
        isActive = employee.isActive
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !trimmedName.isEmpty else {
            errorMessage = L10n.tr("module.hr.validation_employee")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let existing: HREmployee? = if case .edit(let employee) = mode { employee } else { nil }
            let employee = HREmployee(
                id: existing?.id ?? UUID(),
                companyId: companyId,
                employeeCode: trimmedCode,
                fullName: trimmedName,
                cnp: trimmed(cnp),
                iban: trimmed(iban),
                phone: trimmed(phone),
                defaultWorkLocationId: locationId,
                isActive: isActive,
                createdAt: existing?.createdAt,
                updatedAt: existing?.updatedAt
            )
            if existing == nil {
                _ = try await HRPersonnelService.createEmployee(employee)
            } else {
                _ = try await HRPersonnelService.updateEmployee(employee)
            }
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func trimmed(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
