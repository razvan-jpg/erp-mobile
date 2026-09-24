import SwiftUI

struct InventoryView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section = .stocks
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    private enum Section: CaseIterable, Identifiable {
        case stocks
        case movements
        case physicalInventory

        var id: String { title }

        var title: String {
            switch self {
            case .stocks: return L10n.tr("module.inventory.tab_stocks")
            case .movements: return L10n.tr("module.inventory.tab_movements")
            case .physicalInventory: return L10n.tr("module.inventory.tab_physical_inventory")
            }
        }

        var icon: String {
            switch self {
            case .stocks: return "shippingbox.fill"
            case .movements: return "arrow.left.arrow.right"
            case .physicalInventory: return "list.clipboard"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.inventory.section_picker"), selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if isLoadingAccess {
                    ProgressView(L10n.tr("module.inventory.loading_permissions"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if companyManager.currentCompany == nil {
                    AppEmptyStateView(
                        L10n.tr("module.inventory.no_company_selected"),
                        systemImage: "building.2.crop.circle",
                        description: Text(L10n.tr("module.no_company"))
                    )
                } else if !access.canView {
                    AppEmptyStateView(
                        L10n.tr("module.inventory.access_restricted"),
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
        case .stocks:
            StockListView(canEdit: access.canEdit)
        case .movements:
            StockMovementsListView()
        case .physicalInventory:
            InventarListView(access: access)
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
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }
}
