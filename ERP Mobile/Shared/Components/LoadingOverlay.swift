import SwiftUI
import UIKit

struct LoadingOverlay: View {
    let isLoading: Bool
    var message: String = L10n.tr("common.loading")

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.2).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                    Text(message)
                        .font(.subheadline)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
            }
        }
    }
}
