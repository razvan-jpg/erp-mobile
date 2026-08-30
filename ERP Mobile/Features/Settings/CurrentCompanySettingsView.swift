import SwiftUI

struct CurrentCompanySettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    var body: some View {
        NavigationView {
            Group {
                if session.isSuperAdmin {
                    AdminSettingsView(useNavigationView: false)
                } else {
                    standardCompanySettings
                }
            }
            .navigationTitle(
                session.isSuperAdmin
                    ? L10n.tr("admin.settings_title")
                    : L10n.tr("company_settings.title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }

    private var standardCompanySettings: some View {
        Form {
            if let company = companyManager.currentCompany {
                Section(header: Text(L10n.tr("settings.current_company"))) {
                    AppLabeledContent(L10n.tr("company_settings.name"), value: company.denumire)
                    if let cui = company.cui, !cui.isEmpty {
                        AppLabeledContent(L10n.tr("common.cui"), value: cui)
                    }
                    if let adresa = company.adresa, !adresa.isEmpty {
                        AppLabeledContent(L10n.tr("company_settings.address"), value: adresa)
                    }
                }
            } else {
                Section {
                    Text(L10n.tr("status_bar.no_company"))
                        .foregroundColor(AppColors.secondary)
                }
            }

            if companyManager.canSwitchCompany {
                CurrentCompanyPickerSection()
            }
        }
        .appLoadingOverlay(isLoading: companyManager.isLoading)
    }
}

#Preview {
    CurrentCompanySettingsView()
        .environmentObject(SessionManager())
        .environmentObject(CompanyManager())
}
