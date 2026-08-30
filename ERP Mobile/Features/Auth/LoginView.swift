import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            AdaptiveCenteredContent(maxWidth: 520) {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: horizontalSizeClass == .regular ? 64 : 48))
                            .foregroundColor(AppColors.accent)
                        Text(L10n.tr("app.name"))
                            .font(horizontalSizeClass == .regular ? .largeTitle.bold() : .title.bold())
                        Text(L10n.tr("app.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondary)
                    }

                    AdaptiveFormContainer {
                        VStack(spacing: 16) {
                            FormTextField(
                                title: L10n.tr("common.field_email"),
                                text: $email,
                                keyboardType: .emailAddress,
                                autocapitalization: .never,
                                autocorrectionDisabled: true,
                                preserveExactTextCase: true
                            )
                            FormTextField(
                                title: L10n.tr("auth.field_password"),
                                text: $password,
                                isSecure: true
                            )
                        }
                    }

                    if let error = session.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(L10n.tr("auth.login")) {
                        Task { await session.login(email: email, password: password) }
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .appControlSize(horizontalSizeClass == .regular ? .large : .regular)
                    .disabled(email.isEmpty || password.isEmpty || session.isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: session.isLoading) }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}
