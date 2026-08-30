import SwiftUI

struct BlockedAccountView: View {
    @EnvironmentObject private var session: SessionManager

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 480) {
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.red)
                Text(L10n.tr("auth.blocked_title"))
                    .font(.title.bold())
                Text(L10n.tr("auth.blocked_message"))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.secondary)
                Button(L10n.tr("auth.back_to_login")) {
                    Task { await session.logout() }
                }
                .buttonStyle(AppButtonStyles.borderedProminent)
            }
        }
    }
}
