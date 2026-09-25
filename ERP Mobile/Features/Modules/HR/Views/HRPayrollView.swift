import SwiftUI

struct HRPayrollView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var period = HRMonthPeriod.current()
    @State private var run: HRPayrollRun?
    @State private var drafts: [HRPayrollLineDraft] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDraft: HRPayrollLineDraft?

    var body: some View {
        Group {
            if drafts.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("module.hr.payroll_empty"),
                    systemImage: "banknote",
                    description: Text(L10n.tr("module.hr.payroll_empty_hint"))
                )
            } else {
                List {
                    ForEach(drafts) { draft in
                        Button { selectedDraft = draft } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(draft.employeeName)
                                        .font(.headline)
                                    Spacer()
                                    Text(SupplierFormatting.currency(draft.line.netAmount))
                                        .font(.subheadline.bold())
                                }
                                Text("\(draft.employeeCode) · \(L10n.tr("module.hr.field_hours_worked")) \(SupplierFormatting.amountString(draft.line.hoursWorked))")
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                if let error = draft.line.timesheetError, !error.isEmpty {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_payroll"))
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                HRPeriodPicker(period: $period)
                HStack {
                    if let run {
                        Text(statusLabel(run.status))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Spacer()
                    if access.canCreate || access.canEdit {
                        Button(L10n.tr("module.hr.generate_payroll")) {
                            Task { await generate() }
                        }
                        .disabled(run?.isClosed == true || isLoading)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .appBarBackground()
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
        .appTask(id: "\(companyManager.currentCompany?.id.uuidString ?? "")-\(period.year)-\(period.month)") {
            await load()
        }
        .onChange(of: period) { _ in
            Task { await load() }
        }
        .fullScreenCover(item: $selectedDraft) { draft in
            HRPayrollLineEditor(
                draft: draft,
                canEdit: (access.canEdit || access.canCreate) && run?.isClosed != true
            ) { updated in
                await persist(updated)
            }
        }
    }

    private func statusLabel(_ status: HRPayrollRunStatus) -> String {
        L10n.tr("module.hr.status_\(status.rawValue)")
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else {
            run = nil
            drafts = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let employees = HRPersonnelService.fetchEmployees(companyId: companyId)
            async let contracts = HRPersonnelService.fetchContracts(companyId: companyId)
            async let locations = WorkLocationService.fetchWorkLocations(companyId: companyId)
            if let existing = try await HRPersonnelService.fetchRun(companyId: companyId, period: period) {
                run = existing
                let lines = try await HRPersonnelService.fetchLines(runId: existing.id)
                drafts = HRPersonnelService.drafts(
                    lines: lines,
                    employees: try await employees,
                    contracts: try await contracts,
                    locations: try await locations
                )
            } else {
                run = nil
                drafts = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generate() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            run = try await HRPersonnelService.generatePayroll(companyId: companyId, period: period)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist(_ draft: HRPayrollLineDraft) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var line = draft.line
            line.recalculate(contractGross: draft.contractGross, hoursPerDay: draft.hoursPerDay)
            _ = try await HRPersonnelService.saveLine(line)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct HRPayrollLineEditor: View {
    @State var draft: HRPayrollLineDraft
    let canEdit: Bool
    let onSave: (HRPayrollLineDraft) async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var daysCO = ""
    @State private var daysCM = ""
    @State private var hoursCO = ""
    @State private var hoursCM = ""
    @State private var bonuses = ""
    @State private var other = ""
    @State private var deductions = ""
    @State private var cas = ""
    @State private var cass = ""
    @State private var tax = ""
    @State private var cam = ""
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section(draft.employeeName) {
                    HRInfoRow(title: L10n.tr("module.hr.field_code"), value: draft.employeeCode)
                    HRInfoRow(title: L10n.tr("module.hr.field_base_hours"), value: SupplierFormatting.amountString(draft.line.baseHours))
                    HRInfoRow(title: L10n.tr("module.hr.field_hours_worked"), value: SupplierFormatting.amountString(computed.hoursWorked))
                    HRInfoRow(title: L10n.tr("module.hr.field_gross"), value: SupplierFormatting.currency(computed.grossAmount))
                    HRInfoRow(title: L10n.tr("module.hr.field_net"), value: SupplierFormatting.currency(computed.netAmount))
                }
                Section(L10n.tr("module.hr.payroll_edit_section")) {
                    FormTextField(title: L10n.tr("module.hr.field_days_co"), text: $daysCO, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_hours_co"), text: $hoursCO, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_days_cm"), text: $daysCM, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_hours_cm"), text: $hoursCM, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_bonuses"), text: $bonuses, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_other"), text: $other, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_deductions"), text: $deductions, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_cas"), text: $cas, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_cass"), text: $cass, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_tax"), text: $tax, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_cam"), text: $cam, keyboardType: .decimalPad)
                    FormTextField(title: L10n.tr("module.hr.field_notes"), text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(L10n.tr("module.hr.payroll_line_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task {
                            applyFields()
                            await onSave(draft)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(!canEdit)
                }
            }
            .onAppear { populate() }
            .onChange(of: daysCO) { _ in applyFields() }
            .onChange(of: daysCM) { _ in applyFields() }
            .onChange(of: hoursCO) { _ in applyFields() }
            .onChange(of: hoursCM) { _ in applyFields() }
            .onChange(of: bonuses) { _ in applyFields(refreshStatutory: true) }
            .onChange(of: other) { _ in applyFields(refreshStatutory: true) }
            .onChange(of: deductions) { _ in applyFields() }
            .onChange(of: cas) { _ in applyFields() }
            .onChange(of: cass) { _ in applyFields() }
            .onChange(of: tax) { _ in applyFields() }
            .onChange(of: cam) { _ in applyFields() }
        }
        .navigationViewStyle(.stack)
    }

    private var computed: HRPayrollLine {
        var line = draft.line
        line.recalculate(contractGross: draft.contractGross, hoursPerDay: draft.hoursPerDay)
        return line
    }

    private func populate() {
        daysCO = string(draft.line.daysCO)
        daysCM = string(draft.line.daysCM)
        hoursCO = string(draft.line.hoursCO)
        hoursCM = string(draft.line.hoursCM)
        bonuses = string(draft.line.bonuses)
        other = string(draft.line.otherAdditions)
        deductions = string(draft.line.deductions)
        cas = string(draft.line.casAmount)
        cass = string(draft.line.cassAmount)
        tax = string(draft.line.taxAmount)
        cam = string(draft.line.camAmount)
        notes = draft.line.notes ?? ""
    }

    private func applyFields(refreshStatutory: Bool = false) {
        draft.line.daysCO = decimal(daysCO)
        draft.line.daysCM = decimal(daysCM)
        draft.line.hoursCO = decimal(hoursCO)
        draft.line.hoursCM = decimal(hoursCM)
        draft.line.bonuses = decimal(bonuses)
        draft.line.otherAdditions = decimal(other)
        draft.line.deductions = decimal(deductions)
        draft.line.casAmount = decimal(cas)
        draft.line.cassAmount = decimal(cass)
        draft.line.taxAmount = decimal(tax)
        draft.line.camAmount = decimal(cam)
        draft.line.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        draft.line.recalculate(contractGross: draft.contractGross, hoursPerDay: draft.hoursPerDay)
        if refreshStatutory {
            draft.line.applyStatutoryContributions()
            cas = string(draft.line.casAmount)
            cass = string(draft.line.cassAmount)
            tax = string(draft.line.taxAmount)
            cam = string(draft.line.camAmount)
        }
    }

    private func decimal(_ text: String) -> Decimal {
        SupplierFormatting.parseAmount(text) ?? 0
    }

    private func string(_ value: Decimal) -> String {
        value == 0 ? "" : NSDecimalNumber(decimal: value).stringValue
    }
}

private struct HRInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(AppColors.secondary)
        }
    }
}
