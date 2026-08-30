import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var localeManager: LocaleManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSection: MainSection? = .home
    @State private var selectedTab: MainSection = .home
    @State private var showCompanySettings = false
    @State private var pendingSettingsDestination: SettingsDeepLink?
    @State private var helpLegalDestination: HelpLegalDestination?
    @State private var homeStackIdentity = UUID()
    @State private var utilitiesStackIdentity = UUID()

    var body: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                regularLayout
            } else {
                compactLayout
            }
        }
        .withAppBottomStatusBar(
            onOpenUsers: session.isAdmin ? { openUsers() } : nil,
            onOpenCompanySettings: { openCompanySettings() },
            onOpenAboutApp: { openAboutApp() }
        )
        .sheet(isPresented: $showCompanySettings) {
            CurrentCompanySettingsView()
                .environmentObject(session)
                .environmentObject(companyManager)
                .environmentObject(localeManager)
        }
        .onAppear {
            selectedTab = .home
            selectedSection = .home
        }
        .onChange(of: selectedTab) { tab in
            if tab == .home {
                resetHomeNavigation()
            }
        }
        .id(localeManager.language.rawValue)
        .appLegacyAlert(
            isPresented: Binding(
                get: { session.showDefaultPasswordWarning },
                set: { session.showDefaultPasswordWarning = $0 }
            ),
            title: L10n.tr("auth.change_superadmin_password"),
            message: L10n.tr("auth.default_password_warning")
        )
    }

    private var tabSelection: Binding<MainSection> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    switch newTab {
                    case .home:
                        resetHomeNavigation()
                    case .utilities:
                        resetUtilitiesNavigation()
                    default:
                        break
                    }
                }
                selectedTab = newTab
            }
        )
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            NavigationView {
                DashboardView(useNavigationView: false)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .id(homeStackIdentity)
            .tabItem {
                Label(MainSection.home.title, systemImage: MainSection.home.systemImage)
            }
            .tag(MainSection.home)

            LazyTabContent {
                CRMRootView(useNavigationView: false)
            }
            .tabItem {
                Label(MainSection.crm.title, systemImage: MainSection.crm.systemImage)
            }
            .tag(MainSection.crm)

            LazyTabContent {
                NavigationView {
                    UtilitiesRootView(useNavigationView: false)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .id(utilitiesStackIdentity)
            }
            .tabItem {
                Label(MainSection.utilities.title, systemImage: MainSection.utilities.systemImage)
            }
            .tag(MainSection.utilities)

            LazyTabContent {
                AppHelpView(useNavigationView: false, pendingLegalDestination: $helpLegalDestination)
            }
            .tabItem {
                Label(MainSection.help.title, systemImage: MainSection.help.systemImage)
            }
            .tag(MainSection.help)

            WhatsNewView()
                .tabItem {
                    Label(MainSection.whatsNew.title, systemImage: MainSection.whatsNew.systemImage)
                }
                .tag(MainSection.whatsNew)

            UserSettingsView(pendingDestination: $pendingSettingsDestination)
                .tabItem {
                    Label(MainSection.settings.title, systemImage: MainSection.settings.systemImage)
                }
                .tag(MainSection.settings)
        }
    }

    private var regularLayout: some View {
        NavigationView {
            List {
                homeSidebarRow
                sidebarRow(.crm)
                utilitiesSidebarRow

                sidebarRow(.help)
                sidebarRow(.whatsNew)
                sidebarRow(.settings)

#if targetEnvironment(macCatalyst)
                Section {
                    Button {
                        MacInstallSupport.quitApplication()
                    } label: {
                        Label(L10n.tr("settings.mac_quit_app"), systemImage: "power")
                    }
                }
#endif
            }
            .navigationTitle(L10n.tr("app.name"))

            Group {
                if selectedSection == .home {
                    DashboardView(useNavigationView: false)
                        .id(homeStackIdentity)
                } else {
                    sidebarDetailContent
                }
            }
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
    }

    private func sidebarRow(_ section: MainSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            Label(section.title, systemImage: section.systemImage)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedSection == section ? Color.accentColor.opacity(0.12) : nil)
    }

    private var homeSidebarRow: some View {
        Button {
            goHome()
        } label: {
            Label(MainSection.home.title, systemImage: MainSection.home.systemImage)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedSection == .home ? Color.accentColor.opacity(0.12) : nil)
    }

    private var utilitiesSidebarRow: some View {
        Button {
            goUtilities()
        } label: {
            Label(MainSection.utilities.title, systemImage: MainSection.utilities.systemImage)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedSection == .utilities ? Color.accentColor.opacity(0.12) : nil)
    }

    private func goUtilities() {
        selectedSection = .utilities
        selectedTab = .utilities
        resetUtilitiesNavigation()
    }

    private func goHome() {
        selectedSection = .home
        selectedTab = .home
        resetHomeNavigation()
    }

    private func resetHomeNavigation() {
        homeStackIdentity = UUID()
    }

    private func resetUtilitiesNavigation() {
        utilitiesStackIdentity = UUID()
    }

    private func openCompanySettings() {
        if session.isSuperAdmin {
            pendingSettingsDestination = .adminCompanies
            selectedTab = .settings
            selectedSection = .settings
            return
        }
        showCompanySettings = true
    }

    private func openUsers() {
        guard session.isAdmin else { return }
        pendingSettingsDestination = .users
        selectedTab = .settings
        selectedSection = .settings
    }

    private func openAboutApp() {
        selectedTab = .help
        selectedSection = .help
        helpLegalDestination = .about
    }

    @ViewBuilder
    private var sidebarDetailContent: some View {
        switch selectedSection ?? .home {
        case .home:
            DashboardView(useNavigationView: false)
        case .crm:
            CRMRootView(useNavigationView: false)
        case .utilities:
            UtilitiesRootView(useNavigationView: false)
                .id(utilitiesStackIdentity)
        case .help:
            AppHelpView(useNavigationView: false, pendingLegalDestination: $helpLegalDestination)
        case .whatsNew:
            WhatsNewView(useNavigationView: false)
        case .settings:
            UserSettingsView(
                useNavigationView: false,
                pendingDestination: $pendingSettingsDestination
            )
        }
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case home
    case crm
    case utilities
    case help
    case whatsNew
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return L10n.tr("tab.home")
        case .crm: return L10n.tr("tab.crm")
        case .utilities: return L10n.tr("tab.utilities")
        case .help: return L10n.tr("tab.help")
        case .whatsNew: return L10n.tr("tab.whats_new")
        case .settings: return L10n.tr("tab.settings")
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .crm: return "person.crop.rectangle.stack.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .help: return "questionmark.circle.fill"
        case .whatsNew: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }
}
