import SwiftUI

struct UtilitiesRootView: View {
    var useNavigationView = true

    var body: some View {
        if useNavigationView {
            NavigationView { contentBody }
        } else {
            contentBody
        }
    }

    private var contentBody: some View {
        AdaptiveCenteredContent(maxWidth: 560) {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.tr("utilities.subtitle"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)

                VStack(spacing: 10) {
                    NavigationLink(destination: ZettaUtilityView()) {
                        utilityButtonLabel(
                            title: L10n.tr("utilities.zetta_import.title"),
                            subtitle: L10n.tr("utilities.zetta_import.subtitle"),
                            systemImage: "doc.text.magnifyingglass"
                        )
                        .settingsMenuButtonChrome()
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: MT940UtilityView()) {
                        utilityButtonLabel(
                            title: L10n.tr("utilities.mt940.title"),
                            subtitle: L10n.tr("utilities.mt940.subtitle"),
                            systemImage: "archivebox"
                        )
                        .settingsMenuButtonChrome()
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: CashRegisterZExtractView()) {
                        utilityButtonLabel(
                            title: L10n.tr("utilities.cash_register.title"),
                            subtitle: L10n.tr("utilities.cash_register.subtitle"),
                            systemImage: "printer.dotmatrix.fill"
                        )
                        .settingsMenuButtonChrome()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle(L10n.tr("utilities.title"))
    }

    private func utilityButtonLabel(title: String, subtitle: String, systemImage: String) -> some View {
        SettingsMenuButtonLabel(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            showsChevron: true
        )
    }
}
