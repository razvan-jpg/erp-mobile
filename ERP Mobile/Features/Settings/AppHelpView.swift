import SwiftUI

enum HelpLegalDestination: String, Identifiable {
    case privacy
    case terms
    case gdpr
    case about

    var id: String { rawValue }
}

struct AppHelpView: View {
    var useNavigationView = true
    var onBack: (() -> Void)? = nil
    @Binding var pendingLegalDestination: HelpLegalDestination?

    @EnvironmentObject private var localeManager: LocaleManager
    @State private var presentedLegal: HelpLegalDestination?

    init(
        useNavigationView: Bool = true,
        onBack: (() -> Void)? = nil,
        pendingLegalDestination: Binding<HelpLegalDestination?> = .constant(nil)
    ) {
        self.useNavigationView = useNavigationView
        self.onBack = onBack
        _pendingLegalDestination = pendingLegalDestination
    }

    var body: some View {
        if useNavigationView {
            NavigationView {
                helpBody
            }
        } else {
            helpBody
        }
    }

    private var helpBody: some View {
        HelpManualView(
            document: ERPHelpContent.document,
            onBack: onBack,
            useGradientBackground: true,
            headerTrailingContent: { helpLegalButtons },
            extraContent: { EmptyView() }
        )
        .navigationTitle(L10n.tr("tab.help"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: consumePendingLegalDestination)
        .onChange(of: pendingLegalDestination) { _ in
            consumePendingLegalDestination()
        }
        .fullScreenCover(item: $presentedLegal) { destination in
            legalDestinationView(destination)
                .environmentObject(localeManager)
        }
    }

    private var helpLegalButtons: some View {
        VStack(alignment: .trailing, spacing: 6) {
            legalButton(
                title: L10n.tr("tab.privacy"),
                destination: .privacy
            )
            legalButton(
                title: L10n.tr("tab.terms"),
                destination: .terms
            )
            legalButton(
                title: L10n.tr("tab.gdpr"),
                destination: .gdpr
            )
            legalButton(
                title: L10n.tr("tab.about"),
                destination: .about
            )
        }
    }

    private func legalButton(title: String, destination: HelpLegalDestination) -> some View {
        Button {
            presentedLegal = destination
        } label: {
            Text(title)
                .font(.custom("Avenir Next", size: 11).weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(minWidth: 108)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    @ViewBuilder
    private func legalDestinationView(_ destination: HelpLegalDestination) -> some View {
        switch destination {
        case .privacy:
            PrivacyPolicyView(onBack: { presentedLegal = nil })
        case .terms:
            TermsOfServiceView(onBack: { presentedLegal = nil })
        case .gdpr:
            GDPRPolicyView(onBack: { presentedLegal = nil })
        case .about:
            AboutAppView(onBack: { presentedLegal = nil })
        }
    }

    private func consumePendingLegalDestination() {
        guard let destination = pendingLegalDestination else { return }
        presentedLegal = destination
        pendingLegalDestination = nil
    }
}
