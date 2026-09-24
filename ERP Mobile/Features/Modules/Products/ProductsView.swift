import SwiftUI

struct ProductsView: View {
    let module: AppModule
    var permissionsModule: AppModule?

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section = .catalog
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    private enum Section: CaseIterable, Identifiable {
        case catalog
        case articles
        case recipes

        var id: String { title }

        var title: String {
            switch self {
            case .catalog: return L10n.tr("module.products.tab_catalog")
            case .articles: return L10n.tr("module.products.tab_articles")
            case .recipes: return L10n.tr("module.products.tab_recipes")
            }
        }

        var icon: String {
            switch self {
            case .catalog: return "books.vertical.fill"
            case .articles: return "cube.box.fill"
            case .recipes: return "list.bullet.rectangle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.products.section_picker"), selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if isLoadingAccess {
                    ProgressView(L10n.tr("module.products.loading_permissions"))
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
                    sectionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .catalog:
            ProductListView(scope: .catalog, canEdit: access.canEdit, canDelete: access.canDelete)
        case .articles:
            ProductListView(
                scope: .articles,
                canEdit: access.canEdit,
                canCreate: access.canCreate,
                canDelete: access.canDelete
            )
        case .recipes:
            ProductListView(scope: .recipes, canEdit: access.canEdit, canDelete: access.canDelete)
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
            let accessModule = permissionsModule ?? module
            let moduleAccess = try await ModuleAccessRights.load(moduleId: accessModule.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }
}
