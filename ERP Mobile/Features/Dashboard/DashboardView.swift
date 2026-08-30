import SwiftUI

struct DashboardView: View {
    var useNavigationView = true

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var modules: [AppModule] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        if useNavigationView {
            NavigationView { dashboardBody }
        } else {
            dashboardBody
        }
    }

    private var dashboardBody: some View {
        Group {
            if modules.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("dashboard.no_modules"),
                    systemImage: "square.grid.2x2",
                    description: Text(session.isAdmin
                        ? L10n.tr("dashboard.no_modules_admin")
                        : L10n.tr("dashboard.no_modules_user"))
                )
            } else if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(modules) { module in
                            NavigationLink(destination: ModuleDestinationView(module: module)) {
                                ModuleTileCardView(
                                    title: module.name,
                                    description: module.description,
                                    systemImage: ModuleIcon.systemName(for: module.code)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .appScrollBottomPadding()
            } else {
                List(modules) { module in
                    NavigationLink(destination: ModuleDestinationView(module: module)) {
                        ModuleRowView(module: module)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("dashboard.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let company = companyManager.currentCompany {
                    Menu {
                        if companyManager.canSwitchCompany {
                            ForEach(companyManager.switchableCompanies) { item in
                                Button(item.denumire) {
                                    Task { await companyManager.selectCompany(item) }
                                }
                            }
                            Divider()
                        }
                        if let cui = company.cui, !cui.isEmpty {
                            Text(L10n.tr("common.cui_label", cui))
                        }
                    } label: {
                        Label(company.denumire, systemImage: "building.2.fill")
                            .font(.caption)
                            .appLabelStyleTitleAndIcon()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let profile = session.currentProfile {
                        Text(profile.fullName)
                        Text(profile.email)
                    }
                    if let company = companyManager.currentCompany {
                        Text(L10n.tr("common.company_label", company.denumire))
                    }
                    NavigationLink {
                        UserSettingsView()
                    } label: {
                        Text(L10n.tr("settings.title"))
                    }
                    Button(L10n.tr("auth.logout")) {
                        Task { await session.logout() }
                    }
                } label: {
                    Image(systemName: "person.circle")
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
        .appTask(id: session.currentProfile?.id) { await loadModules() }
        .appRefreshable { await loadModules() }
    }

    private func loadModules() async {
        guard let profile = session.currentProfile else { return }
        isLoading = true
        errorMessage = nil
        do {
            modules = try await ModuleService.accessibleModules(for: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct ModuleRowView: View {
    let module: AppModule

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(module.name)
                .font(.headline)
            if let description = module.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
