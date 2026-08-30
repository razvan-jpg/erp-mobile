import SwiftUI
import UIKit

struct FloatingIconActionsBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 2) {
            content()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct FloatingIconActionButton: View {
    let systemImage: String
    let label: String
    var isEnabled: Bool = true
    var isProminent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .appSymbolRenderingMode(.hierarchical)
                .foregroundColor(isProminent ? .white : AppColors.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(isProminent ? Color.accentColor : Color.accentColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(label)
        .help(Text(verbatim: label))
    }
}

struct FloatingIconActionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 22, height: 1)
            .padding(.vertical, 4)
    }
}
