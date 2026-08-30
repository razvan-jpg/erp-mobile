import SwiftUI

struct StocksComingSoonView: View {
    let module: AppModule

    var body: some View {
        AdaptiveCenteredContent(maxWidth: 520) {
            VStack(spacing: 20) {
                Image(systemName: ModuleIcon.systemName(for: module.code))
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.accent)
                Text(module.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                if let description = module.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.center)
                }
                Text(L10n.tr("module.coming_soon"))
                    .font(.headline)
                    .foregroundColor(.orange)
            }
        }
        .navigationTitle(module.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
