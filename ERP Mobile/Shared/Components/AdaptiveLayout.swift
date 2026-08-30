import SwiftUI

enum DeviceLayout {
    static let compactFormMaxWidth: CGFloat = 480
    static let regularFormMaxWidth: CGFloat = 640
    static var contentMaxWidth: CGFloat {
#if targetEnvironment(macCatalyst)
        1200
#else
        900
#endif
    }

    static func isRegularWidth(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        sizeClass == .regular
#endif
    }
}

enum ListRowActions {
    /// Pe Mac Catalyst swipe-ul este greu de folosit; afișăm buton explicit de ștergere.
    static var prefersExplicitDeleteButton: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }
}

/// Conținut static (VStack, butoane, mesaje) centrat și scrollabil.
/// Nu folosi pentru `Form`/`List` — acestea au scroll propriu; folosește `AdaptiveFormContainer`.
struct AdaptiveCenteredContent<Content: View>: View {
    var maxWidth: CGFloat = DeviceLayout.contentMaxWidth
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var horizontalPadding: CGFloat {
        DeviceLayout.isRegularWidth(horizontalSizeClass) ? 40 : 20
    }
}

/// Limitează lățimea unui `Form`/`List` fără ScrollView suplimentar (evită layout colapsat).
struct AdaptiveFormContainer<Content: View>: View {
    var maxWidth: CGFloat?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder let content: () -> Content

    init(maxWidth: CGFloat? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.maxWidth = maxWidth
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: resolvedMaxWidth)
            .frame(maxWidth: .infinity)
    }

    private var resolvedMaxWidth: CGFloat {
        if let maxWidth { return maxWidth }
        return DeviceLayout.isRegularWidth(horizontalSizeClass)
            ? DeviceLayout.regularFormMaxWidth
            : DeviceLayout.compactFormMaxWidth
    }
}

extension View {
    func adaptiveSheetStyle() -> some View {
        modifier(AdaptiveSheetModifier())
    }
}

private struct AdaptiveSheetModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if #available(iOS 16, *) {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                content
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .frame(idealWidth: 640, maxWidth: 720)
            } else {
                content
                    .presentationDetents([.large])
            }
        } else {
            content
        }
    }
}
