import SwiftUI

struct NomenclatoareCompaniesView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var selectedTab: Tab = .parametrizare
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    private enum Tab: CaseIterable, Identifiable {
        case parametrizare
        case documentSeries
        case workLocations
        case warehouses

        var id: String { title }

        var title: String {
            switch self {
            case .parametrizare:
                return L10n.tr("module.nomenclatoare.companies.tab_parametrizare")
            case .documentSeries:
                return L10n.tr("module.nomenclatoare.companies.tab_document_series")
            case .workLocations:
                return L10n.tr("module.nomenclatoare.companies.tab_work_locations")
            case .warehouses:
                return L10n.tr("module.nomenclatoare.companies.tab_warehouses")
            }
        }

        var icon: String {
            switch self {
            case .parametrizare: return "slider.horizontal.3"
            case .documentSeries: return "list.number"
            case .workLocations: return "mappin.and.ellipse"
            case .warehouses: return "shippingbox.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.nomenclatoare.companies.section_picker"), selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if isLoadingAccess {
                    ProgressView(L10n.tr("module.nomenclatoare.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if companyManager.currentCompany == nil {
                    AppEmptyStateView(
                        L10n.tr("module.products.no_company_selected"),
                        systemImage: "building.2.crop.circle",
                        description: Text(L10n.tr("module.no_company"))
                    )
                } else if !access.canView {
                    AppEmptyStateView(
                        L10n.tr("module.products.access_restricted"),
                        systemImage: "lock.fill",
                        description: Text(L10n.tr("module.no_access"))
                    )
                } else {
                    tabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L10n.tr("module.nomenclatoare.tile.companies"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .parametrizare:
            parametrizareContent
        case .documentSeries:
            NomenclatoareCompaniesPlaceholderTab(
                title: Tab.documentSeries.title,
                systemImage: Tab.documentSeries.icon
            )
        case .workLocations:
            WorkLocationsListView(access: access) {}
        case .warehouses:
            WarehousesListView(access: access) {}
        }
    }

    private var parametrizareContent: some View {
        CompanyParametrizareView(canEdit: access.canEdit) { updated in
            companyManager.afterCompanyUpdated(updated)
        }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            isLoadingAccess = false
            return
        }

        do {
            guard let nomenclatoareModule = try await ModuleService.fetchModule(code: ModuleCode.nomenclatoare) else {
                access = .none
                isLoadingAccess = false
                return
            }
            let moduleAccess = try await ModuleAccessRights.load(
                moduleId: nomenclatoareModule.id,
                moduleCode: ModuleCode.nomenclatoare,
                profile: profile
            )
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }
}

private struct NomenclatoareCompaniesPlaceholderTab: View {
    let title: String
    let systemImage: String

    var body: some View {
        AppEmptyStateView(
            title,
            systemImage: systemImage,
            description: Text(L10n.tr("module.development"))
        )
    }
}
