import SwiftUI

enum SettingsDeepLink: Equatable {
    case adminCompanies
    case users
}

struct UserSettingsView: View {
    var useNavigationView = true
    @Binding var pendingDestination: SettingsDeepLink?

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var localeManager: LocaleManager
    @State private var selectedLanguage: AppLanguage = .romanian
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @State private var settingsNavigation: SettingsDeepLink?

    init(
        useNavigationView: Bool = true,
        pendingDestination: Binding<SettingsDeepLink?> = .constant(nil)
    ) {
        self.useNavigationView = useNavigationView
        _pendingDestination = pendingDestination
    }

#if targetEnvironment(macCatalyst)
    @State private var desktopShortcutMessage: String?
    @State private var showDesktopFolderPicker = false
#endif

    var body: some View {
        if useNavigationView {
            NavigationView { settingsBody }
        } else {
            settingsBody
        }
    }

    private var settingsBody: some View {
        ZStack {
            settingsContent
            LoadingOverlay(isLoading: isLoading)
        }
        .onAppear {
            selectedLanguage = localeManager.language
            openPendingDestinationIfNeeded()
        }
        .onChange(of: pendingDestination) { _ in
            openPendingDestinationIfNeeded()
        }
#if targetEnvironment(macCatalyst)
        .sheet(isPresented: $showDesktopFolderPicker) {
            DocumentDirectoryPicker(
                isPresented: $showDesktopFolderPicker,
                onPick: { url in
                    MacInstallSupport.saveDesktopFolderBookmark(url)
                    handleDesktopShortcutResult(MacInstallSupport.installDesktopShortcut(forceRecreate: false))
                },
                onCancel: {}
            )
        }
#endif
    }

    private var settingsContent: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(alignment: .leading, spacing: 20) {
                if let profile = session.currentProfile {
                    accountHeader(profile)
                }

                    VStack(spacing: 10) {
                        languageMenuButton
                        currentCompanyMenuButton
                        usersLink
                        zettaSettingsLink
                        macDesktopShortcutButton
                        adminCompaniesLink
                        logoutButton
                    }

                if let savedMessage {
                    Text(savedMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }

#if targetEnvironment(macCatalyst)
                if let desktopShortcutMessage {
                    Text(desktopShortcutMessage)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
#endif
            }
        }
        .appScrollBottomPadding()
        .navigationTitle(L10n.tr("settings.title"))
        .background(adminCompaniesNavigationLink)
    }

    @ViewBuilder
    private func accountHeader(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("settings.account"))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.secondary)
            Text(profile.fullName)
                .font(.title3.bold())
            Text(profile.email)
                .foregroundColor(AppColors.secondary)
            if let role = profile.roleLabel {
                Text(role)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var languageMenuButton: some View {
        Menu {
            ForEach(AppLanguage.sortedAll) { language in
                Button {
                    selectedLanguage = language
                    Task { await saveLanguage(language) }
                } label: {
                    HStack {
                        Text(language.nativeName)
                        if selectedLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SettingsMenuButtonLabel(
                title: L10n.tr("settings.language"),
                subtitle: selectedLanguage.nativeName,
                systemImage: "globe",
                showsChevron: true
            )
            .settingsMenuButtonChrome()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var currentCompanyMenuButton: some View {
        if !session.isSuperAdmin && companyManager.canSwitchCompany {
            Menu {
                ForEach(companyManager.switchableCompanies) { company in
                    Button {
                        Task { await companyManager.selectCompany(company) }
                    } label: {
                        HStack {
                            Text(company.denumire)
                            if companyManager.currentCompany?.id == company.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                SettingsMenuButtonLabel(
                    title: L10n.tr("settings.current_company"),
                    subtitle: companyManager.currentCompany?.denumire ?? L10n.tr("common.select_placeholder"),
                    systemImage: "building.2",
                    showsChevron: true
                )
                .settingsMenuButtonChrome()
            }
            .buttonStyle(.plain)

            Text(L10n.tr("settings.current_company_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var usersLink: some View {
        if session.isAdmin {
            NavigationLink(destination: UserListView(useNavigationView: true)) {
                SettingsMenuButtonLabel(
                    title: L10n.tr("settings.users.title"),
                    subtitle: L10n.tr("settings.users.hint"),
                    systemImage: "person.3.fill",
                    showsChevron: true
                )
                .settingsMenuButtonChrome()
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var zettaSettingsLink: some View {
        if companyManager.currentCompany != nil {
            NavigationLink(destination: ZettaSettingsView()) {
                SettingsMenuButtonLabel(
                    title: L10n.tr("settings.zetta.title"),
                    subtitle: L10n.tr("settings.zetta.hint"),
                    systemImage: "doc.text.magnifyingglass",
                    showsChevron: true
                )
                .settingsMenuButtonChrome()
            }
            .buttonStyle(.plain)
        }
    }

#if targetEnvironment(macCatalyst)
    @ViewBuilder
    private var macDesktopShortcutButton: some View {
        Button(action: beginDesktopShortcutInstall) {
            SettingsMenuButtonLabel(
                title: L10n.tr("settings.mac_desktop_shortcut"),
                subtitle: L10n.tr("settings.mac_desktop_shortcut_hint"),
                systemImage: "macwindow.and.arrow.down",
                showsChevron: false
            )
        }
        .buttonStyle(SettingsMenuButtonStyle())
    }
#else
    @ViewBuilder
    private var macDesktopShortcutButton: some View { EmptyView() }
#endif

    @ViewBuilder
    private var adminCompaniesLink: some View {
        if session.isSuperAdmin {
            NavigationLink(
                destination: AdminSettingsView(useNavigationView: true)
            ) {
                SettingsMenuButtonLabel(
                    title: L10n.tr("settings.admin_companies"),
                    subtitle: L10n.tr("settings.admin_companies_hint"),
                    systemImage: "building.columns",
                    showsChevron: true
                )
                .settingsMenuButtonChrome()
            }
            .buttonStyle(.plain)
        }
    }

    private var logoutButton: some View {
        Button {
            Task { await session.logout() }
        } label: {
            SettingsMenuButtonLabel(
                title: L10n.tr("auth.logout"),
                systemImage: "rectangle.portrait.and.arrow.right",
                showsChevron: false,
                isDestructive: true
            )
        }
        .buttonStyle(SettingsMenuButtonStyle())
    }

    @ViewBuilder
    private var adminCompaniesNavigationLink: some View {
        NavigationLink(
            destination: AdminSettingsView(useNavigationView: false),
            tag: SettingsDeepLink.adminCompanies,
            selection: $settingsNavigation
        ) {
            EmptyView()
        }
        .hidden()

        NavigationLink(
            destination: UserListView(useNavigationView: false),
            tag: SettingsDeepLink.users,
            selection: $settingsNavigation
        ) {
            EmptyView()
        }
        .hidden()
    }

    private func openPendingDestinationIfNeeded() {
        guard pendingDestination != nil else { return }
        settingsNavigation = pendingDestination
        pendingDestination = nil
    }

#if targetEnvironment(macCatalyst)
    @MainActor
    private func beginDesktopShortcutInstall() {
        desktopShortcutMessage = nil
        if MacInstallSupport.hasSavedDesktopFolder {
            handleDesktopShortcutResult(MacInstallSupport.installDesktopShortcut(forceRecreate: false))
        } else {
            showDesktopFolderPicker = true
        }
    }

    @MainActor
    private func handleDesktopShortcutResult(_ result: MacInstallSupport.DesktopShortcutResult) {
        switch result {
        case .created:
            desktopShortcutMessage = L10n.tr("settings.mac_desktop_shortcut_created")
        case .alreadyExists:
            desktopShortcutMessage = L10n.tr("settings.mac_desktop_shortcut_exists")
        case .cancelled:
            break
        case .failed(let message):
            desktopShortcutMessage = L10n.tr("settings.mac_desktop_shortcut_failed", message)
        }
    }
#endif

    private func saveLanguage(_ language: AppLanguage) async {
        guard language != localeManager.language else { return }
        isLoading = true
        errorMessage = nil
        savedMessage = nil
        do {
            try await localeManager.setLanguage(language, persistToServer: session.currentProfile != nil)
            await session.refreshProfile()
            savedMessage = L10n.tr("settings.language_saved")
        } catch {
            errorMessage = error.localizedDescription
            selectedLanguage = localeManager.language
        }
        isLoading = false
    }
}
