import MessageUI
import SwiftUI

struct SalesEFacturaAuthSheet: View {
    var showsCloseButton = true

    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.dismiss) private var dismiss

    @State private var settings: CompanyEFacturaSettings?
    @State private var accountantEmail = ""
    @State private var validUntil = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var mailPayload: EFacturaAuthMailItem?
    @State private var showMailUnavailable = false

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

                Section(L10n.tr("efactura.accountant_email")) {
                    TextField(L10n.tr("efactura.accountant_email_placeholder"), text: $accountantEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let settings {
                        LabeledContent(L10n.tr("efactura.auth_status")) {
                            Text(statusLabel(settings))
                                .foregroundColor(statusColor(settings))
                        }
                        if let until = settings.validUntilText {
                            LabeledContent(L10n.tr("efactura.valid_until")) {
                                Text(until)
                                    .foregroundColor(settings.isExpired ? .red : AppColors.primary)
                            }
                        }
                        if settings.isExpired {
                            Text(L10n.tr("efactura.expired"))
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    if settings?.authStatus == .requested || settings?.authStatus == .authorized {
                        DatePicker(
                            L10n.tr("efactura.valid_until"),
                            selection: $validUntil,
                            in: Calendar.current.startOfDay(for: Date())...,
                            displayedComponents: .date
                        )
                    }
                }

                Section {
                    Button {
                        Task { await saveEmailOnly() }
                    } label: {
                        Label(L10n.tr("efactura.save_email"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSaving || trimmedEmail == nil)

                    Button {
                        Task { await requestAuth() }
                    } label: {
                        Label(L10n.tr("efactura.send_auth_request"), systemImage: "envelope.badge")
                    }
                    .disabled(isSaving || trimmedEmail == nil)

                    if settings?.authStatus == .requested || settings?.authStatus == .authorized {
                        Button {
                            Task { await confirmAuthorized() }
                        } label: {
                            Label(L10n.tr("efactura.mark_authorized"), systemImage: "checkmark.seal")
                        }
                        .disabled(isSaving || trimmedEmail == nil)
                    }
                } footer: {
                    Text(L10n.tr("efactura.auth_footer"))
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
                if isLoading {
                    ProgressView()
                }
            }
            .appTask { await reload() }
            .sheet(item: $mailPayload) { payload in
                MailComposeView(
                    subject: payload.subject,
                    body: payload.body,
                    recipients: payload.recipients,
                    attachments: [],
                    onFinish: { result in
                        mailPayload = nil
                        if result == .sent {
                            Task { await afterAuthMailSent() }
                        }
                    }
                )
            }
            .alert(L10n.tr("module.sales.cash_sale.mail_unavailable_title"), isPresented: $showMailUnavailable) {
                Button(L10n.tr("common.ok"), role: .cancel) {}
                Button(L10n.tr("efactura.copy_email_body")) {
                    UIPasteboard.general.string = authMailBody()
                }
                Button(L10n.tr("efactura.mark_requested_manual")) {
                    Task { await afterAuthMailSent() }
                }
            } message: {
                Text(L10n.tr("efactura.mail_unavailable_auth_body", trimmedEmail ?? ""))
            }
    }

    private var trimmedEmail: String? {
        let value = accountantEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func statusLabel(_ settings: CompanyEFacturaSettings) -> String {
        settings.isExpired ? L10n.tr("efactura.auth_status_expired") : settings.authStatus.label
    }

    private func statusColor(_ settings: CompanyEFacturaSettings) -> Color {
        if settings.isExpired { return .red }
        switch settings.authStatus {
        case .none: return AppColors.secondary
        case .requested: return .orange
        case .authorized: return .green
        }
    }

    private func reload() async {
        guard let companyId = companyManager.currentCompany?.id else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let row = try await CompanyEFacturaSettingsService.fetch(companyId: companyId)
            settings = row
            accountantEmail = row?.trimmedAccountantEmail ?? ""
            if let until = row?.authValidUntil, until >= Calendar.current.startOfDay(for: Date()) {
                validUntil = until
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveEmailOnly() async {
        guard let companyId = companyManager.currentCompany?.id, let email = trimmedEmail else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            settings = try await CompanyEFacturaSettingsService.saveAccountantEmail(
                companyId: companyId,
                email: email,
                existing: settings
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestAuth() async {
        guard let company = companyManager.currentCompany, let email = trimmedEmail else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            settings = try await CompanyEFacturaSettingsService.saveAccountantEmail(
                companyId: company.id,
                email: email,
                existing: settings
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if DocumentExportSupport.canSendMail {
            mailPayload = EFacturaAuthMailItem(
                subject: L10n.tr("efactura.auth_mail_subject", company.denumire),
                body: authMailBody(),
                recipients: [email]
            )
        } else {
            showMailUnavailable = true
        }
    }

    private func afterAuthMailSent() async {
        guard let companyId = companyManager.currentCompany?.id, let email = trimmedEmail else { return }
        do {
            settings = try await CompanyEFacturaSettingsService.markAuthRequested(
                companyId: companyId,
                email: email,
                existing: settings
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmAuthorized() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            if settings == nil {
                _ = try await saveEmailOnlyPrep()
            }
            guard let existing = settings else { return }
            settings = try await CompanyEFacturaSettingsService.markAuthAuthorized(
                companyId: companyId,
                existing: existing,
                validUntil: validUntil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveEmailOnlyPrep() async throws -> CompanyEFacturaSettings? {
        guard let companyId = companyManager.currentCompany?.id else { return nil }
        let row = try await CompanyEFacturaSettingsService.saveAccountantEmail(
            companyId: companyId,
            email: trimmedEmail,
            existing: settings
        )
        settings = row
        return row
    }

    private func authMailBody() -> String {
        let company = companyManager.currentCompany
        let name = company?.denumire ?? "—"
        let cui = company?.cui ?? "—"
        return L10n.tr("efactura.auth_mail_body", name, cui)
    }
}

private struct EFacturaAuthMailItem: Identifiable {
    let id = UUID()
    let subject: String
    let body: String
    let recipients: [String]
}
