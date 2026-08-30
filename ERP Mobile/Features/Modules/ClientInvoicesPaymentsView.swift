import SwiftUI

struct ClientInvoicesPaymentsView: View {
    let module: AppModule
    var initialSection: Section = .clients

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    init(module: AppModule, initialSection: Section = .clients) {
        self.module = module
        self.initialSection = initialSection
        _selectedSection = State(initialValue: initialSection)
    }

    enum Section: CaseIterable, Identifiable {
        case clients
        case invoices
        case dueDates
        case payments
        case zReports

        var id: String { title }

        var title: String {
            switch self {
            case .clients: return L10n.tr("module.clients.tab_clients")
            case .invoices: return L10n.tr("module.clients.tab_invoices")
            case .dueDates: return L10n.tr("module.clients.tab_due_dates")
            case .payments: return L10n.tr("module.clients.tab_payments")
            case .zReports: return L10n.tr("module.clients.tab_z_reports")
            }
        }

        var icon: String {
            switch self {
            case .clients: return "person.2.fill"
            case .invoices: return "doc.text.fill"
            case .dueDates: return "calendar.badge.clock"
            case .payments: return "banknote.fill"
            case .zReports: return "doc.text.magnifyingglass"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.clients.section_picker"), selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

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
                } else {
                    sectionContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(L10n.tr("module.clients.tile_situation"))
        .navigationBarTitleDisplayMode(.inline)
        .appTask { await loadAccess() }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            Task { await loadAccess() }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .clients:
            ClientsListView(access: access, onChanged: {})
        case .invoices:
            ClientInvoicesListView(access: access, onChanged: {})
        case .dueDates:
            ClientDueDatesListView(access: access, onChanged: {})
        case .payments:
            ClientPaymentsListView(access: access, onChanged: {})
        case .zReports:
            ClientZReportsListView(access: access)
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
