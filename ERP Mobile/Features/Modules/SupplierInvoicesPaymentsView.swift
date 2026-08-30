import SwiftUI

struct SupplierInvoicesPaymentsView: View {
    let module: AppModule

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @State private var selectedSection: Section = .suppliers
    @State private var access = ModuleAccessRights.none
    @State private var isLoadingAccess = true

    private enum Section: CaseIterable, Identifiable {
        case suppliers
        case invoices
        case nirs
        case payments
        case dueDates

        var id: String { title }

        var title: String {
            switch self {
            case .suppliers: return L10n.tr("module.suppliers.tab_suppliers")
            case .invoices: return L10n.tr("module.suppliers.tab_invoices")
            case .nirs: return L10n.tr("module.suppliers.tab_nirs")
            case .dueDates: return L10n.tr("module.suppliers.tab_due_dates")
            case .payments: return L10n.tr("module.suppliers.tab_payments")
            }
        }

        var icon: String {
            switch self {
            case .suppliers: return "building.2.fill"
            case .invoices: return "doc.text.fill"
            case .nirs: return "shippingbox.fill"
            case .dueDates: return "calendar.badge.clock"
            case .payments: return "banknote.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(L10n.tr("module.suppliers.section_picker"), selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                if isLoadingAccess {
                    ProgressView(L10n.tr("module.suppliers.loading_permissions"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if companyManager.currentCompany == nil {
                    AppEmptyStateView(
                        L10n.tr("module.suppliers.no_company_selected"),
                        systemImage: "building.2.crop.circle",
                        description: Text(L10n.tr("module.no_company"))
                    )
                } else if !access.canView {
                    AppEmptyStateView(
                        L10n.tr("module.suppliers.access_restricted"),
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
        case .suppliers:
            SuppliersListView(access: access, onChanged: {})
        case .invoices:
            InvoicesListView(access: access, onChanged: {})
        case .nirs:
            NIRListView(access: access, onChanged: {})
        case .dueDates:
            DueDatesListView(access: access, onChanged: {})
        case .payments:
            PaymentsListView(access: access, onChanged: {})
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
