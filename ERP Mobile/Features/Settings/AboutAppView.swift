import SwiftUI

struct AboutAppView: View {
    var useNavigationView = true
    var onBack: (() -> Void)?

    private let goldDark = Color(red: 0.72, green: 0.52, blue: 0.12)

    var body: some View {
        if useNavigationView {
            NavigationView { aboutBody }
        } else {
            aboutBody
        }
    }

    private var aboutBody: some View {
        GeometryReader { proxy in
            let row2Size = min(proxy.size.width * 0.075, 40)
            let row1Size = row2Size * 2
            let detailSize = min(proxy.size.width * 0.048, 26)
            let iconBaseSize = min(proxy.size.width * 0.22, 88)

            ZStack {
                aboutBackground

                VStack(spacing: proxy.size.height * 0.035) {
                    Text(L10n.tr("about.app_title"))
                        .font(.system(size: row1Size, weight: .bold))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    Image("AppLaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconBaseSize, height: iconBaseSize)
                        .scaleEffect(2)
                        .frame(width: iconBaseSize * 2, height: iconBaseSize * 2)
                        .clipShape(RoundedRectangle(cornerRadius: iconBaseSize * 0.36, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                    Spacer(minLength: 0)

                    Text(L10n.tr("about.developer"))
                        .font(.system(size: row2Size, weight: .bold))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(L10n.tr("about.app_version", AppInfo.marketingVersionWithBuildLabel))
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    (
                        Text(L10n.tr("about.database_engine_prefix"))
                        + Text("  SUPABASE").bold().italic().underline()
                    )
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    Text(L10n.tr("about.database_version", AppInfo.databaseSchemaVersion))
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    Text(L10n.tr("about.resend_version", AppInfo.resendIntegrationVersion))
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundColor(goldDark)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, AppChrome.bottomStatusBarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(L10n.tr("tab.about"))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(AboutToolbarStyleModifier(goldDark: goldDark))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(L10n.tr("common.back"))
                        }
                    }
                    .foregroundColor(goldDark)
                }
            }
        }
    }

    private var aboutBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.16),
                Color(red: 0.07, green: 0.11, blue: 0.22),
                Color(red: 0.05, green: 0.08, blue: 0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct AboutToolbarStyleModifier: ViewModifier {
    let goldDark: Color

    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            content
        }
    }
}
