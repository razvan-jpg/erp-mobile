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
    @StateObject private var casierPos = CasierPosLaunch()

    var body: some View {
        Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                regularLayout
            } else {
                compactLayout
            }
        }
        .environmentObject(casierPos)
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
        .fullScreenCover(item: $casierPos.location) { location in
            CasierPosView(location: location) {
                casierPos.location = nil
            }
            .environmentObject(companyManager)
            .environmentObject(session)
            .environmentObject(localeManager)
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            selectedTab = .home
            selectedSection = .home
        }
        .onChange(of: selectedTab) { _, tab in
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
            VStack(spacing: 0) {
                List {
                    homeSidebarRow
                    sidebarRow(.crm)
                    utilitiesSidebarRow

                    sidebarRow(.help)
                    sidebarRow(.whatsNew)
                    sidebarRow(.settings)
                }
                .frame(maxHeight: 320)
                .navigationTitle(L10n.tr("app.name"))

                sidebarCompanyLogo
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

#if targetEnvironment(macCatalyst)
                ZStack {
                    Button {
                        MacInstallSupport.quitApplication()
                    } label: {
                        Text(L10n.tr("settings.mac_quit_app"))
                            .font(.body.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 22, alignment: .center)
                    }
                    .buttonStyle(SidebarCloseButton3DStyle())
                    .frame(maxWidth: 220)
                    .appControlHint(L10n.tr("settings.mac_quit_app"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
#endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var showsNectarieLogo: Bool {
        guard let company = companyManager.currentCompany else { return false }
        if let cui = company.cui, let profile = FirmaRegistry.profile(forCUI: cui) {
            return profile.isNectarie
        }
        return Conturi.isNectarieFirma(company.denumire)
    }

    private var sidebarCompanyLogo: some View {
        Group {
            if showsNectarieLogo {
                Image("NectariePosLogo")
                    .resizable()
                    .scaledToFit()
            } else if let stored = companyManager.currentCompany?.logoUrl,
                      let image = CompanyLogoStorage.swiftUIImage(from: stored) {
                image
                    .resizable()
                    .scaledToFit()
            } else if let name = companyManager.currentCompany?.denumire,
                      let stored = CompanyLogoStorage.suggestedLogo(from: name),
                      let image = CompanyLogoStorage.swiftUIImage(from: stored) {
                image
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
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

private struct SidebarCloseButton3DStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: configuration.isPressed
                        ? [
                            Color(red: 0.55, green: 0.40, blue: 0.16),
                            Color(red: 0.78, green: 0.62, blue: 0.36)
                        ]
                        : [
                            Color(red: 0.95, green: 0.84, blue: 0.63),
                            Color(red: 0.78, green: 0.63, blue: 0.35),
                            Color(red: 0.55, green: 0.41, blue: 0.17)
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(
                color: Color(red: 0.36, green: 0.26, blue: 0.09),
                radius: 0,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .shadow(
                color: Color.black.opacity(0.28),
                radius: configuration.isPressed ? 1 : 5,
                x: 0,
                y: configuration.isPressed ? 1 : 6
            )
            .offset(y: configuration.isPressed ? 3 : 0)
    }
}
