import SwiftUI

struct AppDevelopmentInfoOverlay: View {
    let onDismiss: () -> Void

    @State private var autoDismissTask: Task<Void, Never>?

    private let maxDisplayDuration: TimeInterval = 60

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            infoPanel
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(maxDisplayDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { dismiss() }
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
        }
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text(L10n.tr("launch.development_info_title"))
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.primary)

                Spacer(minLength: 0)

                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .appSymbolRenderingMode(.hierarchical)
                        .foregroundColor(AppColors.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("launch.development_info_close"))
            }

            Text(L10n.tr("launch.development_info_message", language: .romanian))
                .font(.body)
                .foregroundColor(AppColors.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text(L10n.tr("launch.development_info_message", language: .english))
                .font(.body)
                .foregroundColor(AppColors.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: 560)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .appFullOverlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
    }

    private func dismiss() {
        autoDismissTask?.cancel()
        onDismiss()
    }
}

#Preview {
    AppDevelopmentInfoOverlay(onDismiss: {})
}
