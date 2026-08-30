import SwiftUI

enum AppChrome {
    static let standardEdgePadding: CGFloat = 16
    static let bottomStatusBarHeight: CGFloat = 58
}

private struct OpenUsersActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct OpenCompanySettingsActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct OpenAboutAppActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var openUsers: (() -> Void)? {
        get { self[OpenUsersActionKey.self] }
        set { self[OpenUsersActionKey.self] = newValue }
    }

    var openCompanySettings: (() -> Void)? {
        get { self[OpenCompanySettingsActionKey.self] }
        set { self[OpenCompanySettingsActionKey.self] = newValue }
    }

    var openAboutApp: (() -> Void)? {
        get { self[OpenAboutAppActionKey.self] }
        set { self[OpenAboutAppActionKey.self] = newValue }
    }
}

struct AppBottomStatusBar: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.openUsers) private var openUsers
    @Environment(\.openCompanySettings) private var openCompanySettings
    @Environment(\.openAboutApp) private var openAboutApp

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 8) {
                userSection
                companySection
                versionSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .appBarBackground()
        }
    }

    @ViewBuilder
    private var userSection: some View {
        if let profile = session.currentProfile {
            let content = VStack(alignment: .leading, spacing: 2) {
                Text(profile.fullName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(profile.roleLabel ?? L10n.tr("users.role_user"))
                    .font(.caption2)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let openUsers {
                Button(action: openUsers) {
                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("tab.users"))
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Spacer(minLength: 0)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var companySection: some View {
        let content = VStack(spacing: 2) {
            if let company = companyManager.currentCompany {
                Text(company.denumire)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Text(L10n.tr("status_bar.no_company"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }

        if let openCompanySettings {
            Button(action: openCompanySettings) {
                content
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("company_settings.title"))
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var versionSection: some View {
        let content = VStack(alignment: .trailing, spacing: 2) {
            Text(AppInfo.displayVersion)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(L10n.tr("status_bar.free_version"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }

        if let openAboutApp {
            Button(action: openAboutApp) {
                content
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("tab.about"))
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

extension View {
    func withAppBottomStatusBar(
        onOpenUsers: (() -> Void)? = nil,
        onOpenCompanySettings: (() -> Void)? = nil,
        onOpenAboutApp: (() -> Void)? = nil
    ) -> some View {
        appSafeAreaInsetBottom {
            AppBottomStatusBar()
                .environment(\.openUsers, onOpenUsers)
                .environment(\.openCompanySettings, onOpenCompanySettings)
                .environment(\.openAboutApp, onOpenAboutApp)
        }
        .environment(\.appBottomBarClearance, AppChrome.bottomStatusBarHeight)
    }

    func floatingBottomTrailing<OverlayContent: View>(
        @ViewBuilder content: @escaping () -> OverlayContent
    ) -> some View {
        modifier(FloatingBottomTrailingModifier(content: content))
    }

    func appScrollBottomPadding() -> some View {
        modifier(AppScrollBottomPaddingModifier())
    }
}

private struct AppBottomBarClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = AppChrome.bottomStatusBarHeight
}

extension EnvironmentValues {
    var appBottomBarClearance: CGFloat {
        get { self[AppBottomBarClearanceKey.self] }
        set { self[AppBottomBarClearanceKey.self] = newValue }
    }
}

private struct FloatingBottomTrailingModifier<OverlayContent: View>: ViewModifier {
    @Environment(\.appBottomBarClearance) private var bottomBarClearance
    private let overlayContent: () -> OverlayContent

    init(@ViewBuilder content: @escaping () -> OverlayContent) {
        self.overlayContent = content
    }

    func body(content: Content) -> some View {
        content.appOverlayBottomTrailing {
            overlayContent()
                .padding(.trailing, AppChrome.standardEdgePadding)
                .padding(.bottom, AppChrome.standardEdgePadding + bottomBarClearance)
        }
    }
}

private struct AppScrollBottomPaddingModifier: ViewModifier {
    @Environment(\.appBottomBarClearance) private var bottomBarClearance

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content
                .contentMargins(.bottom, bottomBarClearance, for: .scrollContent)
        } else {
            content
                .appSafeAreaInsetBottom {
                    Color.clear.frame(height: bottomBarClearance)
                }
        }
    }
}

#Preview {
    AppBottomStatusBar()
        .environmentObject(SessionManager())
        .environmentObject(CompanyManager())
}
