import SwiftUI
import UIKit

extension View {
    /// Etichetă VoiceOver + tip vizibil la hover (Mac Catalyst / pointer).
    func appControlHint(_ text: String) -> some View {
        modifier(AppHoverTipModifier(text: text, setsAccessibilityLabel: true))
    }

    /// Doar tip la hover (când controlul are deja text / Label vizibil).
    func appHoverTip(_ text: String) -> some View {
        modifier(AppHoverTipModifier(text: text, setsAccessibilityLabel: false))
    }
}

/// Pe Catalyst, `.help()` nu arată tip la mouse — folosim hover + overlay (și UIToolTipInteraction pe UIKit).
private struct AppHoverTipModifier: ViewModifier {
    let text: String
    let setsAccessibilityLabel: Bool

    @State private var isHovering = false
    @State private var showTip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = content
            .background {
                if !trimmed.isEmpty {
                    MacCatalystToolTipBridge(text: trimmed)
                        .allowsHitTesting(false)
                }
            }
            .onHover { hovering in
                guard !trimmed.isEmpty else { return }
                isHovering = hovering
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        guard !Task.isCancelled, isHovering else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            showTip = true
                        }
                    }
                } else {
                    showTip = false
                }
            }
            .overlay(alignment: .top) {
                if showTip, !trimmed.isEmpty {
                    Text(trimmed)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.18), radius: 4, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .fixedSize()
                        .offset(y: -30)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .help(trimmed)

        if setsAccessibilityLabel, !trimmed.isEmpty {
            base.accessibilityLabel(trimmed)
        } else {
            base
        }
    }
}

/// Atașează `UIToolTipInteraction` pe primul ancestor UIKit util (fallback native Catalyst).
private struct MacCatalystToolTipBridge: UIViewRepresentable {
    var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        context.coordinator.anchor = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.text = text
        context.coordinator.scheduleInstall()
    }

    final class Coordinator {
        var text: String
        weak var anchor: UIView?
        weak var target: UIView?
        private var interaction: UIToolTipInteraction?

        init(text: String) {
            self.text = text
        }

        func scheduleInstall() {
            DispatchQueue.main.async { [weak self] in
                self?.install()
            }
        }

        private func install() {
            guard let anchor else { return }
            guard let nextTarget = Self.resolveTarget(from: anchor) else { return }

            if target !== nextTarget {
                if let target, let interaction {
                    target.removeInteraction(interaction)
                }
                target = nextTarget
                let tip = UIToolTipInteraction(defaultToolTip: text)
                nextTarget.addInteraction(tip)
                interaction = tip
            } else if let target, let interaction {
                target.removeInteraction(interaction)
                let tip = UIToolTipInteraction(defaultToolTip: text)
                target.addInteraction(tip)
                self.interaction = tip
            }
        }

        private static func resolveTarget(from anchor: UIView) -> UIView? {
            var current: UIView? = anchor.superview
            while let view = current {
                let typeName = String(describing: type(of: view))
                if view is UIControl
                    || typeName.contains("Button")
                    || typeName.contains("Toolbar")
                    || (view.gestureRecognizers?.isEmpty == false)
                {
                    return view
                }
                current = view.superview
            }
            return anchor.superview
        }
    }
}

/// Buton plutitor „+” standard, cu tooltip.
struct FloatingAddIconButton: View {
    var hint: String = L10n.tr("common.add")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .appSymbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .appControlHint(hint)
    }
}

/// Buton doar cu iconiță SF Symbol, cu tooltip obligatoriu.
struct AppIconButton: View {
    let systemImage: String
    let hint: String
    var font: Font = .body
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(font)
                .appSymbolRenderingMode(.hierarchical)
        }
        .contentShape(Rectangle())
        .appControlHint(hint)
    }
}
