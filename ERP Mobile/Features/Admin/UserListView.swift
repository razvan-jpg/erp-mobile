import SwiftUI

struct UserListView: View {
    var useNavigationView = true

    @EnvironmentObject private var session: SessionManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var users: [UserProfile] = []
    @State private var companies: [Company] = []
    @State private var companyPermissionsByUserId: [UUID: [CompanyPermission]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateUser = false
    @State private var userToEdit: UserProfile?
    @State private var userToDelete: UserProfile?
    @State private var showDeleteConfirm = false
    @State private var successMessage: String?
    @State private var showSuccessAlert = false

    var body: some View {
        if useNavigationView {
            NavigationView { userListBody }
        } else {
            userListBody
        }
    }

    private var userListBody: some View {
        Group {
            if users.isEmpty && !isLoading {
                AppEmptyStateView(
                    L10n.tr("users.empty"),
                    systemImage: "person.slash",
                    description: Text(L10n.tr("users.empty_hint"))
                )
            } else if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 320, maximum: 480), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(users) { user in
                            UserCardView(
                                user: user,
                                companyAccessLabel: companyAccessLabel(for: user)
                            ) {
                                userToEdit = user
                            } onToggleBlock: {
                                Task { await toggleBlock(user) }
                            } onResendConfirmation: {
                                Task { await resendConfirmation(user) }
                            } onDelete: {
                                userToDelete = user
                                showDeleteConfirm = true
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .appScrollBottomPadding()
            } else {
                List {
                    ForEach(users) { user in
                        UserRowView(
                            user: user,
                            companyAccessLabel: companyAccessLabel(for: user)
                        ) {
                            userToEdit = user
                        } onToggleBlock: {
                            Task { await toggleBlock(user) }
                        } onResendConfirmation: {
                            Task { await resendConfirmation(user) }
                        } onDelete: {
                            userToDelete = user
                            showDeleteConfirm = true
                        }
                    }
                }
                .appScrollBottomPadding()
            }
        }
        .navigationTitle(L10n.tr("users.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateUser = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .appSafeAreaInsetBottom {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .appTask { await loadUsers() }
        .appRefreshable { await loadUsers() }
        .fullScreenCover(isPresented: $showCreateUser) {
            UserFormView(mode: .create) {
                await loadUsers()
            }
            .environmentObject(session)
        }
        .fullScreenCover(item: $userToEdit) { user in
            UserFormView(mode: .edit(user)) {
                await loadUsers()
            }
            .environmentObject(session)
        }
        .alert(L10n.tr("users.delete_title"), isPresented: $showDeleteConfirm, presenting: userToDelete) { user in
            Button(L10n.tr("common.delete")) {
                Task { await deleteUser(user) }
            }
            Button(L10n.tr("common.cancel")) {}
        } message: { user in
            Text(L10n.tr("users.delete_confirm", user.fullName))
        }
        .alert(L10n.tr("user_form.done_title"), isPresented: $showSuccessAlert) {
            Button(L10n.tr("common.ok")) {}
        } message: {
            Text(successMessage ?? "")
        }
    }

    private func loadUsers() async {
        isLoading = true
        errorMessage = nil
        do {
            async let usersTask = UserAdminService.fetchAllUsers()
            async let companiesTask = CompanyService.fetchCompanies()
            async let permissionsTask = CompanyService.fetchAllCompanyPermissions()
            let (loadedUsers, loadedCompanies, loadedPermissions) = try await (usersTask, companiesTask, permissionsTask)
            users = loadedUsers
            companies = loadedCompanies
            companyPermissionsByUserId = UserCompanyAccessSummary.permissionsGroupedByUser(loadedPermissions)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func companyAccessLabel(for user: UserProfile) -> String {
        UserCompanyAccessSummary.labels(
            for: user,
            companies: companies,
            permissionsByUserId: companyPermissionsByUserId
        )
    }

    private func toggleBlock(_ user: UserProfile) async {
        guard !user.isSuperAdmin else {
            errorMessage = L10n.tr("users.cannot_block_superadmin")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let updated = try await UserAdminService.toggleBlock(userId: user.id, isBlocked: !user.isBlocked)
            successMessage = updated.isBlocked
                ? L10n.tr("user_form.blocked_success", updated.fullName)
                : L10n.tr("user_form.unblocked_success", updated.fullName)
            showSuccessAlert = true
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func resendConfirmation(_ user: UserProfile) async {
        guard !user.isSuperAdmin else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await UserAdminService.resendConfirmation(userId: user.id)
            var message = result.emailStatus
            if !result.emailsSent {
                message += "\n\n" + L10n.tr("user_form.email_not_sent_config")
                if let link = result.verificationLink {
                    message += "\n\n" + L10n.tr("user_form.confirmation_link_manual", link)
                }
            }
            successMessage = message
            showSuccessAlert = true
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func deleteUser(_ user: UserProfile) async {
        guard !user.isSuperAdmin, !user.isCompanyAdmin else {
            errorMessage = user.isSuperAdmin
                ? L10n.tr("users.cannot_delete_superadmin")
                : L10n.tr("users.cannot_delete_company_admin")
            return
        }
        isLoading = true
        do {
            try await UserAdminService.deleteUser(userId: user.id)
            await loadUsers()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct UserRowView: View {
    let user: UserProfile
    let companyAccessLabel: String
    let onEdit: () -> Void
    let onToggleBlock: () -> Void
    let onResendConfirmation: () -> Void
    let onDelete: () -> Void

    var body: some View {
        UserInfoContent(
            user: user,
            companyAccessLabel: companyAccessLabel,
            onEdit: onEdit,
            onToggleBlock: onToggleBlock,
            onResendConfirmation: onResendConfirmation,
            onDelete: onDelete
        )
        .padding(.vertical, 4)
    }
}

private struct UserCardView: View {
    let user: UserProfile
    let companyAccessLabel: String
    let onEdit: () -> Void
    let onToggleBlock: () -> Void
    let onResendConfirmation: () -> Void
    let onDelete: () -> Void

    var body: some View {
        UserInfoContent(
            user: user,
            companyAccessLabel: companyAccessLabel,
            onEdit: onEdit,
            onToggleBlock: onToggleBlock,
            onResendConfirmation: onResendConfirmation,
            onDelete: onDelete
        )
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
    }
}

private struct UserInfoContent: View {
    let user: UserProfile
    let companyAccessLabel: String
    let onEdit: () -> Void
    let onToggleBlock: () -> Void
    let onResendConfirmation: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(user.fullName)
                    .font(.headline)
                if let role = user.roleLabel {
                    Text(role)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(user.isSuperAdmin ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(user.statusLabel)
                    .font(.caption)
                    .foregroundColor(userStatusColor(user))
            }
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
            Text(L10n.tr("users.cnp_label", user.cnp))
                .font(.caption)
                .foregroundColor(AppColors.tertiary)
            if let telefon = user.telefon, !telefon.isEmpty {
                Text(L10n.tr("common.phone_label", telefon))
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
            }
            Text(L10n.tr("users.companies_access", companyAccessLabel))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(L10n.tr("common.edit"), action: onEdit)
                    .font(.caption)

                if !user.isSuperAdmin {
                    Button(user.isBlocked ? L10n.tr("common.unblock") : L10n.tr("common.block"), action: onToggleBlock)
                        .font(.caption)
                        .foregroundColor(user.isBlocked ? .green : .orange)

                    Button(L10n.tr("user_form.resend_confirmation"), action: onResendConfirmation)
                        .font(.caption)
                }

                if !user.isSuperAdmin && !user.isCompanyAdmin {
                    Button(L10n.tr("common.delete"), action: onDelete)
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
            .padding(.top, 4)
        }
    }

    private func userStatusColor(_ user: UserProfile) -> Color {
        if user.isBlocked { return .red }
        if !user.isEmailConfirmed { return .orange }
        return .green
    }
}
