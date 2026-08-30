import SwiftUI
import UIKit

struct ModuleTileCardView: View {
    let title: String
    var description: String?
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.primary)
            if let description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}
