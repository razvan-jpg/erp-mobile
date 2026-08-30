import Combine
import Foundation

enum AppAuthState: Equatable {
    case loading
    case unauthenticated
    case blocked
    case authenticated(UserProfile)
    case configurationError
}

@MainActor
final class SessionManager: ObservableObject {
    @Published var authState: AppAuthState = .loading
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showDefaultPasswordWarning = false

    private let defaultSuperAdminEmail = "razvan.ivan@icloud.com"

    func bootstrap() async {
        guard SupabaseConfig.isConfigured else {
            authState = .configurationError
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            try await AuthService.seedAdminIfNeeded()

            if await AuthService.currentSession() != nil {
                let profile = try await AuthService.fetchCurrentProfile()
                applyProfile(profile)
            } else {
                authState = .unauthenticated
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                authState = .unauthenticated
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let profile = try await AuthService.signIn(email: email, password: password)
            applyProfile(profile)
            if email.lowercased() == defaultSuperAdminEmail && password == "123456" {
                showDefaultPasswordWarning = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        isLoading = true
        do {
            try await AuthService.signOut()
            authState = .unauthenticated
            showDefaultPasswordWarning = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshProfile() async {
        do {
            let profile = try await AuthService.fetchCurrentProfile()
            applyProfile(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var currentProfile: UserProfile? {
        if case .authenticated(let profile) = authState {
            return profile
        }
        return nil
    }

    var isSuperAdmin: Bool {
        currentProfile?.isSuperAdmin ?? false
    }

    var isCompanyAdmin: Bool {
        currentProfile?.isCompanyAdmin ?? false
    }

    var isAdmin: Bool {
        isSuperAdmin || isCompanyAdmin
    }

    private func applyProfile(_ profile: UserProfile) {
        if profile.isBlocked {
            authState = .blocked
            Task { try? await AuthService.signOut() }
        } else if !profile.isEmailConfirmed && !profile.isAdmin && !profile.isSuperAdmin {
            authState = .unauthenticated
            errorMessage = AppAuthError.emailNotConfirmed.errorDescription
            Task { try? await AuthService.signOut() }
        } else {
            authState = .authenticated(profile)
        }
    }
}
