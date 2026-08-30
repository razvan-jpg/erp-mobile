import SwiftUI

struct CRMRootView: View {
    var useNavigationView = true

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section = .dealsKanban
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true
    @State private var accessError: String?

    private enum Section: CaseIterable, Identifiable {
        case overview
        case leads
        case dealsKanban
        case dealsList
        case contacts
        case companies
        case quotes
        case activities
        case analytics
        case tickets

        var id: Self { self }

        var title: String {
            switch self {
            case .overview: return L10n.tr("crm.tab.overview")
            case .leads: return L10n.tr("crm.tab.leads")
            case .dealsKanban: return L10n.tr("crm.tab.deals_kanban")
            case .dealsList: return L10n.tr("crm.tab.deals_list")
            case .contacts: return L10n.tr("crm.tab.contacts")
            case .companies: return L10n.tr("crm.tab.companies")
            case .quotes: return L10n.tr("crm.tab.quotes")
            case .activities: return L10n.tr("crm.tab.activities")
            case .analytics: return L10n.tr("crm.tab.analytics")
            case .tickets: return L10n.tr("crm.tab.tickets")
            }
        }

        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .leads: return "person.crop.circle.badge.plus"
            case .dealsKanban: return "rectangle.grid.3x2.fill"
            case .dealsList: return "list.bullet.rectangle.fill"
            case .contacts: return "person.2.fill"
            case .companies: return "building.2.fill"
            case .quotes: return "doc.text.fill"
            case .activities: return "calendar"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .tickets: return "ticket.fill"
            }
        }
    }

    var body: some View {
        Group {
            if useNavigationView {
                NavigationView { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
        Group {
            if isLoadingAccess {
                ProgressView(L10n.tr("crm.loading_access"))
            } else if !access.canView {
                AppEmptyStateView(
                    L10n.tr("crm.access_denied_title"),
                    systemImage: "lock.fill",
                    description: Text(accessError ?? L10n.tr("crm.access_denied_hint"))
                )
            } else if companyManager.currentCompany == nil {
                AppEmptyStateView(
                    L10n.tr("crm.no_company_title"),
                    systemImage: "building.2",
                    description: Text(L10n.tr("crm.no_company_hint"))
                )
            } else {
                VStack(spacing: 0) {
                    sectionBar

                    Group {
                        switch selectedSection {
                        case .overview:
                            CRMOverviewView(access: access)
                        case .leads:
                            CRMLeadsListView(access: access)
                        case .dealsKanban:
                            CRMDealKanbanView(access: access)
                        case .dealsList:
                            CRMDealListView(access: access)
                        case .contacts:
                            CRMContactsListView(access: access)
                        case .companies:
                            CRMCompaniesListView(access: access)
                        case .quotes:
                            CRMQuotesListView(access: access)
                        case .activities:
                            CRMActivitiesListView(access: access)
                        case .analytics:
                            CRMAnalyticsView(access: access)
                        case .tickets:
                            CRMTicketsListView(access: access)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("tab.crm"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    private var sectionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Section.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.title, systemImage: section.icon)
                            .font(.caption.weight(selectedSection == section ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSection == section ? AppColors.accent.opacity(0.15) : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func loadAccess() async {
        isLoadingAccess = true
        accessError = nil
        defer { isLoadingAccess = false }

        guard let profile = session.currentProfile else {
            access = .none
            accessError = L10n.tr("crm.access_no_profile")
            return
        }
        guard companyManager.currentCompany?.id != nil else {
            access = .none
            return
        }

        do {
            guard let clientModule = try await ModuleService.fetchModule(code: ModuleCode.clientInvoicesPayments) else {
                access = .none
                accessError = L10n.tr("crm.access_module_missing")
                return
            }
            let moduleAccess = try await ModuleAccessRights.load(moduleId: clientModule.id, profile: profile)
            let companyAccess = try await CompanyAccessRights.load(companyId: companyManager.currentCompany!.id, profile: profile)
            access = ModuleAccessRights.effective(module: moduleAccess, company: companyAccess)
        } catch {
            access = .none
            accessError = error.localizedDescription
        }
    }
}
