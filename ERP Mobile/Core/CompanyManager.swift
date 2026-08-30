import Combine
import Foundation

@MainActor
final class CompanyManager: ObservableObject {
    @Published var companies: [Company] = []
    @Published var switchableCompanies: [Company] = []
    @Published var currentCompany: Company?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var requiresAdminCompanySetup: Bool {
        guard let profile = profile else { return false }
        return profile.isSuperAdmin && companies.isEmpty
    }

    var canSwitchCompany: Bool {
        switchableCompanies.count >= 2
    }

    var requiresCompanySelection: Bool {
        currentCompany == nil && canSwitchCompany
    }

    var canWork: Bool {
        currentCompany != nil
    }

    private var profile: UserProfile?
    private var companyPermissions: [CompanyPermission] = []

    func configure(profile: UserProfile) async {
        self.profile = profile
        await reload()
    }

    func reload() async {
        guard let profile else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            companies = try await CompanyService.fetchCompanies()
            if profile.isSuperAdmin {
                companyPermissions = []
            } else {
                companyPermissions = try await CompanyService.fetchUserCompanyPermissions(userId: profile.id)
            }
            refreshSwitchableCompanies()
            try await resolveCurrentCompany()
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                companies = []
                switchableCompanies = []
                companyPermissions = []
                currentCompany = nil
            }
        }
    }

    func selectCompany(_ company: Company) async {
        guard switchableCompanies.contains(where: { $0.id == company.id }) else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            try await CompanyService.setSelectedCompany(id: company.id)
            currentCompany = company
            profile?.selectedCompanyId = company.id
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    func afterCompanyCreated(_ company: Company) async {
        await reload()
        let resolved = companies.first(where: { $0.id == company.id }) ?? company
        await selectCompany(resolved)
    }

    func afterCompanyUpdated(_ company: Company) {
        if let index = companies.firstIndex(where: { $0.id == company.id }) {
            companies[index] = company
        }
        if let index = switchableCompanies.firstIndex(where: { $0.id == company.id }) {
            switchableCompanies[index] = company
        }
        if currentCompany?.id == company.id {
            currentCompany = company
        }
        refreshSwitchableCompanies()
    }

    private func refreshSwitchableCompanies() {
        guard let profile else {
            switchableCompanies = []
            return
        }
        switchableCompanies = CompanyWritableAccess.writableCompanies(
            profile: profile,
            companies: companies,
            permissions: companyPermissions
        )
        .sorted {
            $0.denumire.localizedCaseInsensitiveCompare($1.denumire) == .orderedAscending
        }
    }

    private func resolveCurrentCompany() async throws {
        refreshSwitchableCompanies()

        guard let profile else {
            currentCompany = nil
            return
        }

        if switchableCompanies.isEmpty {
            currentCompany = nil
            if profile.isSuperAdmin {
                try await CompanyService.setSelectedCompany(id: nil)
            }
            return
        }

        if let selectedId = profile.selectedCompanyId,
           let selected = switchableCompanies.first(where: { $0.id == selectedId }) {
            currentCompany = selected
            return
        }

        if switchableCompanies.count == 1, let only = switchableCompanies.first {
            try await CompanyService.setSelectedCompany(id: only.id)
            currentCompany = only
            self.profile?.selectedCompanyId = only.id
            return
        }

        currentCompany = nil
    }
}
