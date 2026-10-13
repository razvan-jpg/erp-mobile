import SwiftUI

struct SalesEFacturaAuthSheet: View {
    var showsCloseButton = true

    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var settings: CompanyEFacturaSettings?
    @State private var accountantEmail = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var redirectUri = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var waitGeneration = 0

    var body: some View {
        if showsCloseButton {
            NavigationStack { form }
        } else {
            form
        }
    }

    private var form: some View {
        Form {
            Section {
                Text(L10n.tr("efactura.auth_intro"))
                    .font(.footnote)
                    .foregroundColor(AppColors.secondary)
            }

            Section(L10n.tr("efactura.auth_status")) {
                if let settings {
                    LabeledContent(L10n.tr("efactura.auth_status")) {
                        Text(statusLabel(settings))
                            .foregroundColor(statusColor(settings))
                    }
                    LabeledContent(L10n.tr("efactura.valid_until_spv")) {
                        Text(settings.validUntilText ?? "—")
                            .foregroundColor(settings.isExpired ? .red : AppColors.primary)
                    }
                    if let sent = settings.authInviteSentAt {
                        Text(L10n.tr("efactura.invite_sent_at", sentText(sent)))
                            .font(.footnote)
                            .foregroundColor(AppColors.secondary)
                    }
                } else if !isLoading {
                    Text(L10n.tr("efactura.auth_status_none"))
                        .foregroundColor(AppColors.secondary)
                }
            }

            Section {
                Button(L10n.tr("efactura.extend_connection")) {
                    Task { await refresh() }
                }
                .disabled(isSaving || settings?.authStatus != .authorized || settings?.isExpired == true)

                Button(L10n.tr("efactura.revoke_connection")) {
                    Task { await revoke() }
                }
                .disabled(isSaving || settings?.authStatus != .authorized)

                Button(L10n.tr("efactura.reauthorize_spv")) {
                    Task { await sendInvite() }
                }
                .disabled(isSaving || trimmedEmail == nil)
            } footer: {
                Text(L10n.tr("efactura.session_finished_hint"))
            }

            Section(L10n.tr("efactura.invite_title")) {
                Text(L10n.tr("efactura.invite_body"))
                    .font(.footnote)
                    .foregroundColor(AppColors.secondary)
                TextField(L10n.tr("efactura.accountant_email_placeholder"), text: $accountantEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(L10n.tr("efactura.send_invite")) {
                    Task { await sendInvite() }
                }
                .disabled(isSaving || trimmedEmail == nil)
            }

            if session.isSuperAdmin {
                Section(L10n.tr("efactura.enroll_title")) {
                    Text(L10n.tr("efactura.enroll_body"))
                        .font(.footnote)
                        .foregroundColor(AppColors.secondary)
                    Text(redirectUri)
                        .font(.caption)
                        .textSelection(.enabled)
                    TextField(L10n.tr("efactura.client_id"), text: $clientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(L10n.tr("efactura.client_secret"), text: $clientSecret)
                    Button(L10n.tr("efactura.save_enrollment")) {
                        Task { await saveEnrollment() }
                    }
                    .disabled(isSaving || clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let infoMessage {
                Section {
                    Text(infoMessage)
                        .font(.footnote)
                        .foregroundColor(.green)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(L10n.tr("efactura.auth_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.close")) { dismiss() }
                }
            }
        }
        .overlay {
            if isLoading { ProgressView() }
        }
        .appTask { await reload() }
    }

    private var trimmedEmail: String? {
        let value = accountantEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func statusLabel(_ settings: CompanyEFacturaSettings) -> String {
        if settings.isExpired { return L10n.tr("efactura.auth_status_expired") }
        if settings.authStatus == .requested { return L10n.tr("efactura.invite_status") }
        return settings.authStatus.label
    }

    private func statusColor(_ settings: CompanyEFacturaSettings) -> Color {
        if settings.isExpired { return .red }
        switch settings.authStatus {
        case .authorized: return .green
        case .requested: return .orange
        case .none: return AppColors.secondary
        }
    }

    private func sentText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ro_RO")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func reload(quiet: Bool = false) async {
        guard let companyId = companyManager.currentCompany?.id else {
            isLoading = false
            return
        }
        if !quiet { isLoading = true }
        if !quiet { errorMessage = nil }
        defer { isLoading = false }
        do {
            let oauth = try await CompanyEFacturaSettingsService.spvStatus()
            redirectUri = oauth.redirectUri ?? ""
            if let savedId = oauth.clientId, !savedId.isEmpty {
                clientId = savedId
            }
            let row = try await CompanyEFacturaSettingsService.fetch(companyId: companyId)
            settings = row
            if accountantEmail.isEmpty {
                accountantEmail = row?.trimmedAccountantEmail ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendInvite() async {
        guard let companyId = companyManager.currentCompany?.id, let email = trimmedEmail else { return }
        let wait = waitGeneration + 1
        waitGeneration = wait
        let before = settings?.authValidUntil
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await CompanyEFacturaSettingsService.sendSpvInvite(companyId: companyId, email: email)
            infoMessage = L10n.tr("efactura.invite_sent_now")
            await reload(quiet: true)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        for _ in 0..<90 {
            if waitGeneration != wait { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if waitGeneration != wait { return }
            await reload(quiet: true)
            if settings?.authStatus == .authorized, settings?.authValidUntil != before {
                infoMessage = L10n.tr("efactura.authorized_from_spv", settings?.validUntilText ?? "")
                return
            }
        }
    }

    private func refresh() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await CompanyEFacturaSettingsService.refreshSpv(companyId: companyId)
            await reload(quiet: true)
            infoMessage = L10n.tr("efactura.extended_until", settings?.validUntilText ?? "")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func revoke() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        waitGeneration += 1
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await CompanyEFacturaSettingsService.revokeSpv(companyId: companyId)
            await reload(quiet: true)
            infoMessage = L10n.tr("efactura.revoked")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveEnrollment() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await CompanyEFacturaSettingsService.saveSpvEnrollment(clientId: clientId, clientSecret: clientSecret)
            clientSecret = ""
            infoMessage = L10n.tr("efactura.enrollment_saved")
            await reload(quiet: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
