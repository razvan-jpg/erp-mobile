import SwiftUI

struct AdminSettingsView: View {
    var useNavigationView = true

    @EnvironmentObject private var companyManager: CompanyManager
    @State private var showCreateCompany = false
    @State private var companyToEdit: Company?

    var body: some View {
        if useNavigationView {
            NavigationView { settingsBody }
        } else {
            settingsBody
        }
    }

    private var settingsBody: some View {
        List {
            Section {
                Text(L10n.tr("admin.companies_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }

            if companyManager.canSwitchCompany {
                CurrentCompanyPickerSection()
            } else if let current = companyManager.currentCompany {
                Section(header: Text(L10n.tr("settings.current_company"))) {
                    AppLabeledContent(L10n.tr("settings.current_company_active"), value: current.denumire)
                }
            }

            Section(header: Text(L10n.tr("admin.companies_section"))) {
                if companyManager.companies.isEmpty {
                    Text(L10n.tr("admin.no_companies"))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                } else {
                    ForEach(companyManager.companies) { company in
                        Button {
                            companyToEdit = company
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(company.denumire)
                                        .font(.subheadline.bold())
                                        .foregroundColor(AppColors.primary)
                                    if let cui = company.cui, !cui.isEmpty {
                                        Text(L10n.tr("common.cui_label", cui))
                                            .font(.caption)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                }
                                Spacer()
                                if companyManager.currentCompany?.id == company.id {
                                    Text(L10n.tr("common.current"))
                                        .font(.caption.bold())
                                        .foregroundColor(.blue)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .appSwipeActions(edge: .leading) {
                            Button(L10n.tr("admin.set_current")) {
                                Task { await companyManager.selectCompany(company) }
                            }
                            .tint(.blue)
                        }
                    }
                }

                Button {
                    showCreateCompany = true
                } label: {
                    Label(L10n.tr("admin.add_company"), systemImage: "plus.circle.fill")
                }
            }
        }
        .appScrollBottomPadding()
        .navigationTitle(L10n.tr("admin.settings_title"))
        .appFullOverlay { LoadingOverlay(isLoading: companyManager.isLoading) }
        .appSafeAreaInsetBottom {
            if let errorMessage = companyManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .fullScreenCover(isPresented: $showCreateCompany) {
            CompanyFormView(mode: .create) { company in
                await companyManager.afterCompanyCreated(company)
            }
        }
        .fullScreenCover(item: $companyToEdit) { company in
            CompanyFormView(mode: .edit(company)) { updated in
                companyManager.afterCompanyUpdated(updated)
            }
        }
    }
}

struct CurrentCompanyPickerSection: View {
    @EnvironmentObject private var companyManager: CompanyManager

    var body: some View {
        Section(header: Text(L10n.tr("settings.current_company"))) {
            Picker(L10n.tr("settings.current_company"), selection: currentCompanySelection) {
                ForEach(companyManager.switchableCompanies) { company in
                    Text(company.denumire).tag(Optional(company.id))
                }
            }
            .pickerStyle(.menu)

            Text(L10n.tr("settings.current_company_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
    }

    private var currentCompanySelection: Binding<UUID?> {
        Binding(
            get: { companyManager.currentCompany?.id },
            set: { newValue in
                guard let newValue,
                      let company = companyManager.switchableCompanies.first(where: { $0.id == newValue }) else {
                    return
                }
                Task { await companyManager.selectCompany(company) }
            }
        )
    }
}

struct CompanySetupRequiredView: View {
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var showCreateCompany = true

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(spacing: 20) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text(L10n.tr("admin.setup_title"))
                    .font(.title2.bold())
                Text(L10n.tr("admin.setup_message"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondary)
                Button(L10n.tr("admin.add_first_company")) {
                    showCreateCompany = true
                }
                .buttonStyle(AppButtonStyles.borderedProminent)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showCreateCompany) {
            CompanyFormView(mode: .create) { company in
                await companyManager.afterCompanyCreated(company)
            }
        }
    }
}

struct CompanySelectionRequiredView: View {
    @EnvironmentObject private var companyManager: CompanyManager

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(spacing: 20) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(L10n.tr("admin.select_company_title"))
                    .font(.title2.bold())
                Text(L10n.tr("admin.select_company_message"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondary)

                Picker(L10n.tr("settings.current_company"), selection: currentCompanySelection) {
                    Text(L10n.tr("common.select_placeholder")).tag(Optional<UUID>.none)
                    ForEach(companyManager.switchableCompanies) { company in
                        Text(company.denumire).tag(Optional(company.id))
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 160)
            }
            .padding()
        }
    }

    private var currentCompanySelection: Binding<UUID?> {
        Binding(
            get: { companyManager.currentCompany?.id },
            set: { newValue in
                guard let newValue,
                      let company = companyManager.switchableCompanies.first(where: { $0.id == newValue }) else {
                    return
                }
                Task { await companyManager.selectCompany(company) }
            }
        )
    }
}
