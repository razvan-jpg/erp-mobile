import SwiftUI

struct AuthGateView: View {
    var showLaunchSplash = false

    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var localeManager: LocaleManager

    var body: some View {
        Group {
            switch session.authState {
            case .loading, .configurationError, .unauthenticated, .blocked:
                baseAuthContent
            case .authenticated(let profile):
                authenticatedContent(profile: profile)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .appTask { await session.bootstrap() }
    }

    @ViewBuilder
    private var baseAuthContent: some View {
        switch session.authState {
        case .loading:
            ProgressView(L10n.tr("auth.initializing"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .configurationError:
            ConfigurationErrorView()
        case .unauthenticated:
            LoginView()
        case .blocked:
            BlockedAccountView()
        case .authenticated:
            EmptyView()
        }
    }

    @ViewBuilder
    private func authenticatedContent(profile: UserProfile) -> some View {
        Group {
            if companyManager.isLoading && companyManager.companies.isEmpty {
                ProgressView(L10n.tr("auth.loading_companies"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .withAppBottomStatusBar()
            } else if profile.isSuperAdmin && companyManager.requiresAdminCompanySetup {
                CompanySetupRequiredView()
                    .withAppBottomStatusBar()
            } else if companyManager.requiresCompanySelection {
                CompanySelectionRequiredView()
                    .withAppBottomStatusBar()
            } else if !profile.isAdmin && companyManager.companies.isEmpty {
                NoCompanyAccessView()
                    .withAppBottomStatusBar()
            } else if companyManager.canWork {
                if showLaunchSplash {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                } else {
                    MainTabView()
                }
            } else {
                ProgressView(L10n.tr("auth.preparing_workspace"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .withAppBottomStatusBar()
            }
        }
        .appTask(id: profile.id) {
            localeManager.configure(profile: profile)
            await companyManager.configure(profile: profile)
        }
    }
}

private struct ConfigurationErrorView: View {
    var body: some View {
        AdaptiveCenteredContent(maxWidth: 480) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(L10n.tr("auth.config_error_title"))
                    .font(.title2.bold())
                Text(L10n.tr("auth.config_error_message"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondary)
            }
        }
    }
}

private struct NoCompanyAccessView: View {
    @EnvironmentObject private var session: SessionManager

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 480) {
            VStack(spacing: 16) {
                Image(systemName: "building.2.crop.circle.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(L10n.tr("auth.no_company_title"))
                    .font(.title2.bold())
                Text(L10n.tr("auth.no_company_message"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondary)
                Button(L10n.tr("auth.logout")) {
                    Task { await session.logout() }
                }
                .buttonStyle(AppButtonStyles.bordered)
            }
        }
    }
}
