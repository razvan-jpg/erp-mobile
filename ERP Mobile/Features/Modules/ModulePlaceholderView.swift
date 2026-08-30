import SwiftUI

struct ModulePlaceholderView: View {
    let module: AppModule

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(spacing: 20) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.accent)
                Text(module.name)
                    .font(.title.bold())
                Text(L10n.tr("module.development"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                Text(L10n.tr("module.code", module.code))
                    .font(.caption)
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
