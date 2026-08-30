import SwiftUI

enum NomenclatoareSection: String, CaseIterable, Identifiable {
    case companies
    case partners
    case articleCatalog
    case articles
    case persons
    case accounts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .companies: return L10n.tr("module.nomenclatoare.tile.companies")
        case .partners: return L10n.tr("module.nomenclatoare.tile.partners")
        case .articleCatalog: return L10n.tr("module.nomenclatoare.tile.article_catalog")
        case .articles: return L10n.tr("module.nomenclatoare.tile.articles")
        case .persons: return L10n.tr("module.nomenclatoare.tile.persons")
        case .accounts: return L10n.tr("module.nomenclatoare.tile.accounts")
        }
    }

    var description: String {
        switch self {
        case .companies: return L10n.tr("module.nomenclatoare.tile.companies_hint")
        case .partners: return L10n.tr("module.nomenclatoare.tile.partners_hint")
        case .articleCatalog: return L10n.tr("module.nomenclatoare.tile.article_catalog_hint")
        case .articles: return L10n.tr("module.nomenclatoare.tile.articles_hint")
        case .persons: return L10n.tr("module.nomenclatoare.tile.persons_hint")
        case .accounts: return L10n.tr("module.nomenclatoare.tile.accounts_hint")
        }
    }

    var systemImage: String {
        switch self {
        case .companies: return "building.2.fill"
        case .partners: return "person.2.fill"
        case .articleCatalog: return "books.vertical.fill"
        case .articles: return "cube.box.fill"
        case .persons: return "person.3.fill"
        case .accounts: return "book.closed.fill"
        }
    }
}

struct NomenclatoareDestinationView: View {
    let module: AppModule
    let section: NomenclatoareSection

    var body: some View {
        switch section {
        case .companies:
            NomenclatoareCompaniesView()
        case .partners:
            NomenclatoarePartnersView(module: module)
        case .articleCatalog:
            NomenclatoareArticleCatalogView(module: module)
        case .articles:
            NomenclatoareArticlesView(module: module)
        case .persons:
            NomenclatoarePlaceholderView(title: section.title)
        case .accounts:
            NomenclatoarePlaceholderView(title: section.title)
        }
    }
}

private struct NomenclatoarePlaceholderView: View {
    let title: String

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.accent)
                Text(title)
                    .font(.title.bold())
                Text(L10n.tr("module.development"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NomenclatoarePartnersView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var nomenclatoareAccess = ModuleAccessRights.none
    @State private var supplierAccess = ModuleAccessRights.none
    @State private var clientAccess = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var refreshToken = 0

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.nomenclatoare.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.suppliers.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !nomenclatoareAccess.canView {
                AppEmptyStateView(
                    L10n.tr("module.nomenclatoare.partners.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else {
                PartnersListView(
                    supplierAccess: supplierAccess,
                    clientAccess: clientAccess
                ) {
                    refreshToken += 1
                }
                .id(refreshToken)
            }
        }
        .navigationTitle(L10n.tr("module.nomenclatoare.tile.partners"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            nomenclatoareAccess = .none
            supplierAccess = .none
            clientAccess = .none
            isLoadingAccess = false
            return
        }

        do {
            async let suppliersModuleTask = ModuleService.fetchModule(code: ModuleCode.supplierInvoicesPayments)
            async let clientsModuleTask = ModuleService.fetchModule(code: ModuleCode.clientInvoicesPayments)
            let (loadedSuppliersModule, loadedClientsModule) = try await (suppliersModuleTask, clientsModuleTask)

            let moduleAccess = try await ModuleAccessRights.load(
                moduleId: module.id,
                moduleCode: ModuleCode.nomenclatoare,
                profile: profile
            )
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            nomenclatoareAccess = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)

            if let loadedSuppliersModule {
                let supplierModuleAccess = try await ModuleAccessRights.load(moduleId: loadedSuppliersModule.id, profile: profile)
                supplierAccess = ModuleAccessRights.effective(module: supplierModuleAccess, company: companyAccess)
            } else {
                supplierAccess = .none
            }

            if let loadedClientsModule {
                let clientModuleAccess = try await ModuleAccessRights.load(moduleId: loadedClientsModule.id, profile: profile)
                clientAccess = ModuleAccessRights.effective(module: clientModuleAccess, company: companyAccess)
            } else {
                clientAccess = .none
            }
        } catch {
            nomenclatoareAccess = .none
            supplierAccess = .none
            clientAccess = .none
        }
        isLoadingAccess = false
    }
}

private struct NomenclatoareArticleCatalogView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var productsModule: AppModule?
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var refreshToken = 0

    var body: some View {
        Group {
            if isLoadingAccess || productsModule == nil {
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
                ProductListView(
                    scope: .catalog,
                    canEdit: access.canEdit,
                    canDelete: access.canDelete
                ) {
                    refreshToken += 1
                }
                .id(refreshToken)
            }
        }
        .navigationTitle(L10n.tr("module.nomenclatoare.tile.article_catalog"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
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
            if productsModule == nil {
                productsModule = try await ModuleService.fetchModule(code: ModuleCode.products)
            }
            guard let productsModule else {
                access = .none
                isLoadingAccess = false
                return
            }
            let moduleAccess = try await ModuleAccessRights.load(
                moduleId: productsModule.id,
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

private struct NomenclatoareArticlesView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var productsModule: AppModule?
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var refreshToken = 0

    var body: some View {
        Group {
            if isLoadingAccess || productsModule == nil {
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
                ProductListView(
                    scope: .articles,
                    canEdit: access.canEdit,
                    canCreate: access.canCreate,
                    canDelete: access.canDelete
                ) {
                    refreshToken += 1
                }
                .id(refreshToken)
            }
        }
        .navigationTitle(L10n.tr("module.nomenclatoare.tile.articles"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
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
            if productsModule == nil {
                productsModule = try await ModuleService.fetchModule(code: ModuleCode.products)
            }
            guard let productsModule else {
                access = .none
                isLoadingAccess = false
                return
            }
            let moduleAccess = try await ModuleAccessRights.load(
                moduleId: productsModule.id,
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
