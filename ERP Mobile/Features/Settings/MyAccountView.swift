import SwiftUI

struct MyAccountView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @State private var successMessage = ""

    var body: some View {
        NavigationView {
            Form {
                if let profile = session.currentProfile {
                    Section(header: Text(L10n.tr("my_account.profile_section"))) {
                        AppLabeledContent(L10n.tr("my_account.full_name"), value: profile.fullName)
                        AppLabeledContent(L10n.tr("common.field_email"), value: profile.email)
                        if let role = profile.roleLabel {
                            AppLabeledContent(L10n.tr("my_account.role"), value: role)
                        }
                        AppLabeledContent(L10n.tr("user_form.email_status")) {
                            Text(profile.isEmailConfirmed ? L10n.tr("common.confirmed") : L10n.tr("common.unconfirmed"))
                                .foregroundColor(profile.isEmailConfirmed ? .green : .orange)
                        }
                    }
                }

                Section(header: Text(L10n.tr("my_account.password_section"))) {
                    Text(L10n.tr("my_account.password_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)

                    FormTextField(
                        title: L10n.tr("my_account.new_password"),
                        text: $newPassword,
                        isRequired: true,
                        isSecure: true
                    )

                    FormTextField(
                        title: L10n.tr("my_account.confirm_password"),
                        text: $confirmPassword,
                        isRequired: true,
                        isSecure: true
                    )
                }

                if let errorMessage = errorMessage {
                    Section(header: Text(L10n.tr("user_form.error_section"))) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("my_account.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await savePassword() }
                    }
                    .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty)
                }
            }
            .appLoadingOverlay(isLoading: isLoading)
            .appLegacyAlert(
                isPresented: $showSuccessAlert,
                title: L10n.tr("user_form.done_title"),
                message: successMessage,
                buttonTitle: L10n.tr("common.ok"),
                onDismiss: {
                    Task { await session.logout() }
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func savePassword() async {
        errorMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = L10n.tr("my_account.password_too_short")
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = L10n.tr("my_account.password_mismatch")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await AuthService.updateOwnPassword(newPassword)
            var message = L10n.tr("my_account.password_saved_message") + "\n\n" + result.emailStatus
            if !result.emailsSent, let link = result.verificationLink {
                message += "\n\n" + L10n.tr("my_account.password_manual_link") + "\n" + link
            }
            successMessage = message
            showSuccessAlert = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    MyAccountView()
        .environmentObject(SessionManager())
}
