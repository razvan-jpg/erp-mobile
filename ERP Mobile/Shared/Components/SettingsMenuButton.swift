import SwiftUI

struct SettingsMenuButtonLabel: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var showsChevron: Bool = true
    var isDestructive: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundColor(isDestructive ? .red : AppColors.accent)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("Avenir Next", size: 15).weight(.semibold))
                    .foregroundColor(isDestructive ? .red : AppColors.primary)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .settingsMenuButtonChrome(isPressed: configuration.isPressed)
    }
}

private struct SettingsMenuButtonChrome: ViewModifier {
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isPressed ? 0.28 : 0.14), lineWidth: 1)
            )
            .opacity(isPressed ? 0.88 : 1)
    }
}

extension View {
    func settingsMenuButtonChrome(isPressed: Bool = false) -> some View {
        modifier(SettingsMenuButtonChrome(isPressed: isPressed))
    }
}
