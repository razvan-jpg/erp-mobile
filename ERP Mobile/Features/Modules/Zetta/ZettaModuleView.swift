import SwiftUI

struct ZettaModuleView: View {
    let module: AppModule

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @StateObject private var model = ZettaAppViewModel()
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.clients.loading_permissions"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.clients.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.clients.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else if let company = companyManager.currentCompany {
                ZettaImportView(
                    model: model,
                    erpContext: ZettaERPContext(company: company),
                    onExportAndSaveCompleted: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            NotificationCenter.default.post(name: .clientZettaOpenSituationZReports, object: nil)
                        }
                        dismiss()
                    }
                )
            }
        }
        .preferredColorScheme(.light)
        .navigationTitle(L10n.tr("module.clients.tile_zetta"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            model.resetForCompanyChange()
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
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
        isLoadingAccess = false
    }
}
