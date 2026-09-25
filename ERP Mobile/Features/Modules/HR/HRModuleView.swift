import SwiftUI

enum HRModuleSection: String, CaseIterable, Identifiable {
    case employees
    case contracts
    case payroll
    case timesheet
    case listings
    case settings

    var id: String { rawValue }

    var title: String {
        L10n.tr("module.hr.tile_\(rawValue)")
    }

    var description: String {
        L10n.tr("module.hr.tile_\(rawValue)_hint")
    }

    var systemImage: String {
        switch self {
        case .employees: return "person.crop.rectangle.stack"
        case .contracts: return "doc.text.fill"
        case .payroll: return "banknote"
        case .timesheet: return "calendar.badge.clock"
        case .listings: return "list.bullet.rectangle.portrait"
        case .settings: return "gearshape"
        }
    }
}

struct HRModuleView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    var body: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("module.hr.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("module.hr.no_company_selected"),
                    systemImage: "building.2.crop.circle",
                    description: Text(L10n.tr("module.no_company"))
                )
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("module.hr.access_restricted"),
                    systemImage: "lock.fill",
                    description: Text(L10n.tr("module.no_access"))
                )
            } else {
                hub
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    private var hub: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 400), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(HRModuleSection.allCases) { section in
                            NavigationLink {
                                HRModuleDestinationView(module: module, section: section, access: access)
                            } label: {
                                ModuleTileCardView(
                                    title: section.title,
                                    description: section.description,
                                    systemImage: section.systemImage
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
                List(HRModuleSection.allCases) { section in
                    NavigationLink {
                        HRModuleDestinationView(module: module, section: section, access: access)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: section.systemImage)
                                .font(.title3)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.headline)
                                Text(section.description)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .appScrollBottomPadding()
            }
        }
    }

    private func loadAccess() async {
        isLoadingAccess = true
        defer { isLoadingAccess = false }
        guard let profile = session.currentProfile,
              let companyId = companyManager.currentCompany?.id else {
            access = .none
            return
        }
        do {
            let moduleAccess = try await ModuleAccessRights.load(moduleId: module.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyId, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
        }
    }
}

struct HRModuleDestinationView: View {
    let module: AppModule
    let section: HRModuleSection
    let access: ModuleAccessRights

    var body: some View {
        switch section {
        case .employees:
            HREmployeesListView(access: access)
        case .contracts:
            HRContractsListView(access: access)
        case .payroll:
            HRPayrollView(access: access)
        case .timesheet:
            HRTimesheetView(access: access)
        case .listings:
            HRListingsView(access: access)
        case .settings:
            HRSettingsView(access: access)
        }
    }
}
