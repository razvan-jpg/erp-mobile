import SwiftUI

enum UserFormMode: Identifiable {
    case create
    case edit(UserProfile)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let user): return user.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return L10n.tr("user_form.create_title")
        case .edit: return L10n.tr("user_form.edit_title")
        }
    }

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}

private enum FormField: Hashable {
    case nume, prenume, cnp, email, telefon, parola
}

struct UserFormView: View {
    let mode: UserFormMode
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var session: SessionManager

    @State private var nume = ""
    @State private var prenume = ""
    @State private var cnp = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var parola = ""
    @State private var moduleAccess: [UUID: ModuleAccessLevel] = [:]
    @State private var companyAccess: [UUID: CompanyAccessLevel] = [:]
    @State private var modules: [AppModule] = []
    @State private var companies: [Company] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fieldErrors: [FormField: String] = [:]
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var editingUser: UserProfile?
    @State private var originalEmail = ""
    @State private var isBlocked = false
    @State private var isEmailConfirmed = true

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("user_form.required_hint"))
                        Text(L10n.tr("user_form.cnp_hint"))
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                }

                Section(header: Text(L10n.tr("user_form.personal_data_section"))) {
                    FormTextField(
                        title: L10n.tr("user_form.field_last_name"),
                        text: $nume,
                        isRequired: true,
                        errorMessage: fieldErrors[.nume]
                    )
                    FormTextField(
                        title: L10n.tr("user_form.field_first_name"),
                        text: $prenume,
                        isRequired: true,
                        errorMessage: fieldErrors[.prenume]
                    )
                    FormTextField(
                        title: L10n.tr("user_form.field_cnp"),
                        text: $cnp,
                        isRequired: true,
                        errorMessage: fieldErrors[.cnp],
                        keyboardType: .numberPad,
                        autocapitalization: .never
                    )
                    FormTextField(
                        title: L10n.tr("common.field_email"),
                        text: $email,
                        isRequired: true,
                        errorMessage: fieldErrors[.email],
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )
                    FormTextField(
                        title: L10n.tr("common.field_phone"),
                        text: $telefon,
                        errorMessage: fieldErrors[.telefon],
                        keyboardType: .phonePad
                    )
                    FormTextField(
                        title: mode.isEdit
                            ? L10n.tr("user_form.field_password_optional")
                            : L10n.tr("user_form.field_password"),
                        text: $parola,
                        isRequired: !mode.isEdit,
                        errorMessage: fieldErrors[.parola],
                        isSecure: true
                    )
                }

                if showAccountAdminSection {
                    accountAdminSection
                }

                if session.isSuperAdmin {
                    Section(header: Text(L10n.tr("user_form.company_rights_section"))) {
                        Text(L10n.tr("user_form.company_rights_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        CompanyPermissionsEditorView(companies: companies, companyAccess: $companyAccess)
                    }
                } else if !companies.isEmpty {
                    Section(header: Text(L10n.tr("user_form.company_rights_section"))) {
                        Text(L10n.tr("user_form.company_admin_rights_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        CompanyPermissionsEditorView(companies: companies, companyAccess: $companyAccess)
                    }
                }

                Section(header: Text(L10n.tr("user_form.module_rights_section"))) {
                    Text(L10n.tr("user_form.module_rights_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                    PermissionsEditorView(modules: modules, moduleAccess: $moduleAccess)
                }

                if let errorMessage {
                    Section(header: Text(L10n.tr("user_form.error_section"))) {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await save() }
                    }
                    .disabled(isLoading)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .onAppear { primeEditStateFromMode() }
            .appTask { await loadData() }
            .onChange(of: nume) { newValue in
                applyNameFormat(newValue, to: .nume)
            }
            .onChange(of: prenume) { newValue in
                applyNameFormat(newValue, to: .prenume)
            }
            .onChange(of: cnp) { _ in clearError(.cnp) }
            .onChange(of: email) { _ in clearError(.email) }
            .onChange(of: telefon) { _ in clearError(.telefon) }
            .onChange(of: parola) { _ in clearError(.parola) }
            .alert(L10n.tr("user_form.validate_title"), isPresented: $showValidationAlert) {
                Button(L10n.tr("common.ok")) {}
            } message: {
                Text(validationAlertMessage)
            }
            .alert(alertTitle, isPresented: $showSuccessAlert) {
                Button(L10n.tr("common.ok")) {
                    if mode.isEdit {
                        return
                    }
                    Task {
                        await onSaved()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(successAlertMessage)
            }
            .modifier(VisibleScrollContentBackgroundModifier())
        }
    }

    private func clearError(_ field: FormField) {
        fieldErrors.removeValue(forKey: field)
        errorMessage = nil
    }

    private func applyNameFormat(_ value: String, to field: FormField) {
        let formatted = NameFormatter.formatName(value)
        switch field {
        case .nume:
            if nume != formatted { nume = formatted }
            clearError(.nume)
        case .prenume:
            if prenume != formatted { prenume = formatted }
            clearError(.prenume)
        default:
            break
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            modules = try await ModuleService.modulesForPermissionsEditor()
            companies = try await CompanyService.fetchCompanies()
            if let profile = session.currentProfile, !session.isSuperAdmin {
                let callerPermissions = try await CompanyService.fetchUserCompanyPermissions(userId: profile.id)
                let writableIds = CompanyWritableAccess.writableCompanyIds(
                    profile: profile,
                    companies: companies,
                    permissions: callerPermissions
                )
                companies = companies.filter { writableIds.contains($0.id) }
            }
            for module in modules {
                moduleAccess[module.id] = .noAccess
            }
            for company in companies {
                companyAccess[company.id] = .noAccess
            }

            if case .edit(let user) = mode {
                primeEditState(from: user)
                if user.isSuperAdmin || (user.isCompanyAdmin && !session.isSuperAdmin) {
                    errorMessage = L10n.tr("user_form.cannot_edit_user")
                    isLoading = false
                    return
                }
                nume = NameFormatter.formatName(user.nume)
                prenume = NameFormatter.formatName(user.prenume)
                cnp = user.cnp
                email = user.email
                telefon = user.telefon ?? ""
                let existing = try await UserAdminService.fetchUserPermissions(userId: user.id)
                let permissionsByModule = Dictionary(
                    uniqueKeysWithValues: existing.map { ($0.moduleId, $0) }
                )
                for module in modules {
                    moduleAccess[module.id] = ModuleAccessLevel.from(
                        permission: permissionsByModule[module.id]
                    )
                }
                let existingCompanies = try await UserAdminService.fetchUserCompanyPermissions(userId: user.id)
                let permissionsByCompany = Dictionary(
                    uniqueKeysWithValues: existingCompanies.map { ($0.companyId, $0) }
                )
                for company in companies {
                    companyAccess[company.id] = CompanyAccessLevel.from(
                        permission: permissionsByCompany[company.id]
                    )
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func validateForm() -> Bool {
        fieldErrors.removeAll()
        errorMessage = nil
        var messages: [String] = []

        if nume.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors[.nume] = L10n.tr("user_form.validation_last_name_required")
            messages.append(L10n.tr("user_form.validation_label_last_name"))
        }
        if prenume.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors[.prenume] = L10n.tr("user_form.validation_first_name_required")
            messages.append(L10n.tr("user_form.validation_label_first_name"))
        }
        if cnp.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors[.cnp] = L10n.tr("user_form.validation_cnp_required")
            messages.append(L10n.tr("user_form.validation_label_cnp"))
        } else if !Validators.isValidCNP(cnp.trimmingCharacters(in: .whitespaces)) {
            fieldErrors[.cnp] = L10n.tr(
                "user_form.validation_cnp_invalid",
                Validators.gdprCNPPlaceholder
            )
            messages.append(L10n.tr("user_form.validation_label_cnp_invalid"))
        }
        if email.trimmingCharacters(in: .whitespaces).isEmpty {
            fieldErrors[.email] = L10n.tr("user_form.validation_email_required")
            messages.append(L10n.tr("user_form.validation_label_email"))
        } else if !Validators.isValidEmail(email.trimmingCharacters(in: .whitespaces)) {
            fieldErrors[.email] = L10n.tr("user_form.validation_email_invalid")
            messages.append(L10n.tr("user_form.validation_label_email_invalid"))
        }
        if !telefon.isEmpty && !Validators.isValidPhone(telefon) {
            fieldErrors[.telefon] = L10n.tr("user_form.validation_phone_invalid")
            messages.append(L10n.tr("user_form.validation_label_phone_invalid"))
        }
        if !mode.isEdit && parola.isEmpty {
            fieldErrors[.parola] = L10n.tr("user_form.validation_password_required")
            messages.append(L10n.tr("user_form.validation_label_password"))
        } else if !parola.isEmpty && parola.count < 6 {
            fieldErrors[.parola] = L10n.tr("user_form.validation_password_short")
            messages.append(L10n.tr("user_form.validation_label_password_short"))
        }

        if session.isSuperAdmin && !companies.isEmpty && companyPermissionInputs.isEmpty {
            validationAlertMessage = L10n.tr("user_form.validation_company_access_superadmin")
            showValidationAlert = true
            return false
        }

        if session.isCompanyAdmin && companyPermissionInputs.isEmpty {
            validationAlertMessage = L10n.tr("user_form.validation_company_access_admin")
            showValidationAlert = true
            return false
        }

        if !messages.isEmpty {
            validationAlertMessage = messages.joined(separator: "\n")
            showValidationAlert = true
            return false
        }
        return true
    }

    private var companyPermissionInputs: [CompanyPermissionInput] {
        companies.compactMap { company in
            let level = companyAccess[company.id] ?? .noAccess
            guard let permission = level.toPermission(companyId: company.id) else { return nil }
            return CompanyPermissionInput(
                companyId: permission.companyId,
                canView: permission.canView,
                canCreate: permission.canCreate,
                canEdit: permission.canEdit,
                canDelete: permission.canDelete
            )
        }
    }

    private var companyPermissionsSummary: String {
        companies.map { company in
            let level = companyAccess[company.id] ?? .noAccess
            return "- \(company.denumire): \(level.label)"
        }.joined(separator: "\n")
    }

    private var permissionInputs: [PermissionInput] {
        modules.compactMap { module -> PermissionInput? in
            let level = moduleAccess[module.id] ?? .noAccess
            guard let permission = level.toPermission(moduleId: module.id) else { return nil }
            return PermissionInput(
                moduleId: permission.moduleId,
                canView: permission.canView,
                canCreate: permission.canCreate,
                canEdit: permission.canEdit,
                canDelete: permission.canDelete
            )
        }
    }

    private var permissionsSummary: String {
        modules.map { module in
            let level = moduleAccess[module.id] ?? .noAccess
            return "- \(module.name): \(level.label)"
        }.joined(separator: "\n")
    }

    private var editTargetUser: UserProfile? {
        if case .edit(let user) = mode { return user }
        return nil
    }

    private var showAccountAdminSection: Bool {
        guard let user = editTargetUser else { return false }
        return canManageAccount(user)
    }

    private func isManageableUser(_ user: UserProfile) -> Bool {
        !user.isSuperAdmin
    }

    private func canManageAccount(_ user: UserProfile) -> Bool {
        guard isManageableUser(user) else { return false }
        return session.isAdmin
    }

    @ViewBuilder
    private var accountAdminSection: some View {
        Section(header: Text(L10n.tr("user_form.account_admin"))) {
            AppLabeledContent(L10n.tr("user_form.email_status")) {
                Text(isEmailConfirmed ? L10n.tr("common.confirmed") : L10n.tr("common.unconfirmed"))
                    .foregroundColor(isEmailConfirmed ? .green : .orange)
            }
            AppLabeledContent(L10n.tr("user_form.account_status")) {
                Text(isBlocked ? L10n.tr("common.blocked") : L10n.tr("common.active"))
                    .foregroundColor(isBlocked ? .red : .green)
            }

            Button {
                Task { await toggleBlockInForm() }
            } label: {
                Label(
                    isBlocked ? L10n.tr("user_form.unblock_user") : L10n.tr("user_form.block_user"),
                    systemImage: isBlocked ? "checkmark.circle" : "hand.raised"
                )
            }
            .buttonStyle(AppButtonStyles.bordered)
            .tint(isBlocked ? .green : .orange)
            .disabled(isLoading)

            Button {
                Task { await resendConfirmationEmail() }
            } label: {
                Label(L10n.tr("user_form.resend_confirmation"), systemImage: "envelope.arrow.triangle.branch")
            }
            .buttonStyle(AppButtonStyles.bordered)
            .disabled(isLoading)

            if email.trimmingCharacters(in: .whitespaces) != originalEmail {
                Text(L10n.tr("user_form.email_changed_hint"))
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if !isEmailConfirmed {
                Text(L10n.tr("user_form.email_unconfirmed_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
    }

    private func primeEditStateFromMode() {
        if case .edit(let user) = mode {
            primeEditState(from: user)
        }
    }

    private func primeEditState(from user: UserProfile) {
        editingUser = user
        originalEmail = user.email
        isBlocked = user.isBlocked
        isEmailConfirmed = user.isEmailConfirmed
    }

    private func toggleBlockInForm() async {
        guard let user = editingUser ?? editTargetUser else { return }
        isLoading = true
        errorMessage = nil
        do {
            let updated = try await UserAdminService.toggleBlock(
                userId: user.id,
                isBlocked: !isBlocked
            )
            editingUser = updated
            isBlocked = updated.isBlocked
            successAlertMessage = updated.isBlocked
                ? L10n.tr("user_form.blocked_success", updated.fullName)
                : L10n.tr("user_form.unblocked_success", updated.fullName)
            showSuccessAlert = true
            await onSaved()
        } catch {
            errorMessage = error.localizedDescription
            validationAlertMessage = error.localizedDescription
            showValidationAlert = true
        }
        isLoading = false
    }

    private func resendConfirmationEmail() async {
        guard let user = editingUser ?? editTargetUser else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await UserAdminService.resendConfirmation(userId: user.id)
            editingUser = result.user
            isEmailConfirmed = result.user.isEmailConfirmed
            var message = result.emailStatus
            if !result.emailsSent {
                message += "\n\n" + L10n.tr("user_form.email_not_sent_config")
                if let link = result.verificationLink {
                    message += "\n\n" + L10n.tr("user_form.confirmation_link_manual", link)
                }
            }
            successAlertMessage = message
            showSuccessAlert = true
            await onSaved()
        } catch {
            errorMessage = error.localizedDescription
            validationAlertMessage = error.localizedDescription
            showValidationAlert = true
        }
        isLoading = false
    }

    private func save() async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil

        do {
            switch mode {
            case .create:
                let request = CreateUserRequest(
                    nume: nume.trimmingCharacters(in: .whitespaces),
                    prenume: prenume.trimmingCharacters(in: .whitespaces),
                    cnp: cnp.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    telefon: telefon.trimmingCharacters(in: .whitespaces),
                    parola: parola,
                    permissions: permissionInputs,
                    companyPermissions: companyPermissionInputs,
                    adminEmail: session.currentProfile?.email ?? "",
                    modulePermissionsSummary: permissionsSummary,
                    companyPermissionsSummary: companyPermissionsSummary
                )
                let result = try await UserAdminService.createUser(request)
                var message = L10n.tr(
                    "user_form.create_success",
                    result.user.fullName,
                    result.emailStatus
                )
                if !result.emailsSent {
                    message += "\n\n" + L10n.tr("user_form.email_not_sent_resend")
                    if let link = result.verificationLink {
                        message += "\n\n" + L10n.tr("user_form.confirmation_link_manual_user", link)
                    }
                }
                successAlertMessage = message
                showSuccessAlert = true
                isLoading = false
                return

            case .edit(let user):
                var request = UpdateUserRequest(userId: user.id)
                request.nume = nume.trimmingCharacters(in: .whitespaces)
                request.prenume = prenume.trimmingCharacters(in: .whitespaces)
                request.cnp = cnp.trimmingCharacters(in: .whitespaces)
                request.email = email.trimmingCharacters(in: .whitespaces)
                request.telefon = telefon.trimmingCharacters(in: .whitespaces)
                if !parola.isEmpty { request.parola = parola }
                if !user.isAdmin && !user.isSuperAdmin {
                    request.permissions = permissionInputs
                }
                if session.isSuperAdmin || session.isCompanyAdmin {
                    request.companyPermissions = companyPermissionInputs
                }
                let result = try await UserAdminService.updateUser(request)
                editingUser = result.user
                isEmailConfirmed = result.user.isEmailConfirmed
                originalEmail = result.user.email

                if user.id == session.currentProfile?.id {
                    await session.refreshProfile()
                    if !parola.isEmpty {
                        await session.logout()
                        isLoading = false
                        return
                    }
                }

                if result.emailChanged {
                    var message = L10n.tr(
                        "user_form.save_success_email_changed",
                        result.emailStatus ?? ""
                    )
                    if result.emailsSent == false {
                        message += "\n\n" + L10n.tr("user_form.email_confirm_not_sent")
                        if let link = result.verificationLink {
                            message += "\n\n" + L10n.tr("user_form.confirmation_link", link)
                        }
                    }
                    successAlertMessage = message
                    showSuccessAlert = true
                    await onSaved()
                    isLoading = false
                    return
                }
            }

            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
            validationAlertMessage = error.localizedDescription
            showValidationAlert = true
        }

        isLoading = false
    }

    private var alertTitle: String {
        switch mode {
        case .create: return L10n.tr("user_form.created_title")
        case .edit: return L10n.tr("user_form.done_title")
        }
    }
}

private struct VisibleScrollContentBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            content.scrollContentBackground(.visible)
        } else {
            content
        }
    }
}
