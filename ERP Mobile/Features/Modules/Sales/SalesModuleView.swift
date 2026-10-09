import SwiftUI

struct SalesModuleView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section = .cashRegisterSale
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    enum Section: CaseIterable, Identifiable {
        case binaBFImport
        case cashRegisterSale

        var id: String { rawValue }

        private var rawValue: String {
            switch self {
            case .binaBFImport: return "bina_bf"
            case .cashRegisterSale: return "cash_sale"
            }
        }

        var title: String {
            switch self {
            case .binaBFImport: return L10n.tr("module.sales.tab_bina_bf")
            case .cashRegisterSale: return L10n.tr("module.sales.tab_cash_register_sale")
            }
        }

        var icon: String {
            switch self {
            case .binaBFImport: return "arrow.down.doc.fill"
            case .cashRegisterSale: return "barcode.viewfinder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.sales.section_picker"), selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Group {
                if isLoadingAccess {
                    ProgressView(L10n.tr("module.sales.loading_permissions"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if companyManager.currentCompany == nil {
                    AppEmptyStateView(
                        L10n.tr("module.sales.no_company_selected"),
                        systemImage: "building.2.crop.circle",
                        description: Text(L10n.tr("module.no_company"))
                    )
                } else if !access.canView {
                    AppEmptyStateView(
                        L10n.tr("module.sales.access_restricted"),
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
        .onChange(of: companyManager.currentCompany?.id) { _, _ in
            Task { await loadAccess() }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .binaBFImport:
            SalesBinaBFImportView()
        case .cashRegisterSale:
            SalesCashRegisterSaleView()
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

