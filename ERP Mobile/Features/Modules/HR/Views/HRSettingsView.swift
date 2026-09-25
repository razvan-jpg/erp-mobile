import SwiftUI

struct HRSettingsView: View {
    let access: ModuleAccessRights

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var settings = HRSettings.defaults(companyId: UUID())
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var noteNumberText = "1"

    private var canEdit: Bool { access.canEdit || access.canCreate }

    var body: some View {
        Form {
            Section(L10n.tr("module.hr.settings_schedule")) {
                ForEach($settings.schedule) { $day in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(weekdayName(day.weekday), isOn: $day.isWorking)
                        if day.isWorking {
                            HStack {
                                TextField(L10n.tr("module.hr.col_start"), text: $day.startTime)
                                    .keyboardType(.numbersAndPunctuation)
                                Text("–")
                                TextField(L10n.tr("module.hr.col_end"), text: $day.endTime)
                                    .keyboardType(.numbersAndPunctuation)
                            }
                            .disabled(!canEdit)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            Section(L10n.tr("module.hr.settings_accounts")) {
                FormTextField(title: L10n.tr("module.hr.account_expense"), text: $settings.expenseAccount)
                FormTextField(title: L10n.tr("module.hr.account_payable"), text: $settings.payableAccount)
                FormTextField(title: L10n.tr("module.hr.account_cas"), text: $settings.casAccount)
                FormTextField(title: L10n.tr("module.hr.account_cass"), text: $settings.cassAccount)
                FormTextField(title: L10n.tr("module.hr.account_tax"), text: $settings.taxAccount)
                FormTextField(title: L10n.tr("module.hr.account_cam_expense"), text: $settings.camExpenseAccount)
                FormTextField(title: L10n.tr("module.hr.account_cam"), text: $settings.camAccount)
                FormTextField(title: L10n.tr("module.hr.account_journal"), text: $settings.journal)
                FormTextField(title: L10n.tr("module.hr.account_first_note"), text: $noteNumberText, keyboardType: .numberPad)
                Toggle(L10n.tr("module.hr.account_one_note"), isOn: $settings.oneNotePerEmployee)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
        }
        .navigationTitle(L10n.tr("module.hr.tile_settings"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.tr("common.save")) { Task { await save() } }
                    .disabled(!canEdit || isLoading)
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask(id: companyManager.currentCompany?.id) { await load() }
        .disabled(!canEdit && !isLoading)
    }

    private func weekdayName(_ weekday: Int) -> String {
        L10n.tr("module.hr.weekday_\(weekday)")
    }

    private func load() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            settings = try await HRPersonnelService.fetchSettings(companyId: companyId)
            noteNumberText = "\(settings.firstNoteNumber)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        settings.companyId = companyId
        settings.firstNoteNumber = max(Int(noteNumberText) ?? 1, 1)
        isLoading = true
        defer { isLoading = false }
        do {
            settings = try await HRPersonnelService.saveSettings(settings)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
