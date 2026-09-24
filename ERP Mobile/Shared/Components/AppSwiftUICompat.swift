import SwiftUI
import UIKit

enum AppTextAutocapitalization {
    case never
    case words
    case sentences
    case characters

    var uiKitValue: UITextAutocapitalizationType {
        switch self {
        case .never: return .none
        case .words: return .words
        case .sentences: return .sentences
        case .characters: return .allCharacters
        }
    }
}

enum AppColors {
    static let primary = Color(UIColor.label)
    static let secondary = Color(UIColor.secondaryLabel)
    static let tertiary = Color(UIColor.tertiaryLabel)
    static let accent = Color.accentColor
}

struct AppBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct AppBorderedProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

enum AppButtonStyles {
    static var bordered: AppBorderedButtonStyle { AppBorderedButtonStyle() }
    static var borderedProminent: AppBorderedProminentButtonStyle { AppBorderedProminentButtonStyle() }
}

struct AppRemoteImage<Placeholder: View, Content: View>: View {
    let url: URL
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var content: (Image) -> Content

    @State private var loadedImage: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let loadedImage {
                content(Image(uiImage: loadedImage))
            } else if didFail {
                placeholder()
            } else {
                placeholder()
                    .onAppear { load() }
            }
        }
    }

    private func load() {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data, let image = UIImage(data: data) {
                    loadedImage = image
                } else {
                    didFail = true
                }
            }
        }.resume()
    }
}

enum AppSymbolRenderingMode {
    case hierarchical

    @available(iOS 15.0, *)
    var value: SymbolRenderingMode {
        switch self {
        case .hierarchical: return .hierarchical
        }
    }
}

enum AppControlSize {
    case small
    case regular
    case mini
    case large

    @available(iOS 15.0, *)
    var value: ControlSize {
        switch self {
        case .small: return .small
        case .regular: return .regular
        case .mini: return .mini
        case .large: return .large
        }
    }
}

extension View {
    func appBarBackground() -> some View {
        background(Color(UIColor.secondarySystemBackground))
    }

    @ViewBuilder
    func appLoadingOverlay(isLoading: Bool, message: String = L10n.tr("common.loading")) -> some View {
        ZStack {
            self
            LoadingOverlay(isLoading: isLoading, message: message)
        }
    }

    @ViewBuilder
    func appTextSelectionEnabled() -> some View {
        if #available(iOS 15.0, *) {
            textSelection(.enabled)
        } else {
            self
        }
    }

    func appSafeAreaInsetBottom<InsetContent: View>(
        spacing: CGFloat = 0,
        @ViewBuilder content: () -> InsetContent
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: spacing, content: content)
    }

    func appOverlayBottomTrailing<OverlayContent: View>(
        @ViewBuilder overlayContent: () -> OverlayContent
    ) -> some View {
        overlay(alignment: .bottomTrailing, content: overlayContent)
    }

    @ViewBuilder
    func appSearchable(text: Binding<String>, prompt: String) -> some View {
        if #available(iOS 15.0, *) {
            searchable(text: text, prompt: prompt)
        } else {
            self
        }
    }

    func appLegacyAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        buttonTitle: String = L10n.tr("common.ok"),
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        alert(isPresented: isPresented) {
            Alert(
                title: Text(title),
                message: Text(message),
                dismissButton: .default(Text(buttonTitle), action: onDismiss)
            )
        }
    }

    @ViewBuilder
    func appTask(priority: TaskPriority = .userInitiated, _ action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            task(priority: priority) {
                await action()
            }
        } else {
            onAppear {
                Task(priority: priority) { await action() }
            }
        }
    }

    @ViewBuilder
    func appTask<T: Equatable>(
        id: T,
        priority: TaskPriority = .userInitiated,
        _ action: @escaping () async -> Void
    ) -> some View {
        if #available(iOS 15.0, *) {
            task(id: id, priority: priority) {
                await action()
            }
        } else {
            self
                .onAppear { Task(priority: priority) { await action() } }
                .onChange(of: id) { _ in Task(priority: priority) { await action() } }
        }
    }

    @ViewBuilder
    func appRefreshable(_ action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            refreshable { await action() }
        } else {
            self
        }
    }

    func appOverlay<OverlayContent: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> OverlayContent
    ) -> some View {
        overlay(alignment: alignment, content: content)
    }

    @ViewBuilder
    func appFullOverlay<OverlayContent: View>(
        @ViewBuilder content: () -> OverlayContent
    ) -> some View {
        appOverlay(alignment: .center, content: content)
    }

    @ViewBuilder
    func appSymbolRenderingMode(_ mode: AppSymbolRenderingMode = .hierarchical) -> some View {
        if #available(iOS 15.0, *) {
            symbolRenderingMode(mode.value)
        } else {
            self
        }
    }

    @ViewBuilder
    func appListRowSeparatorHidden() -> some View {
        if #available(iOS 15.0, *) {
            listRowSeparator(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func appControlSize(_ size: AppControlSize) -> some View {
        if #available(iOS 15.0, *) {
            controlSize(size.value)
        } else {
            self
        }
    }

    @ViewBuilder
    func appBackgroundIgnoresSafeArea(_ color: Color) -> some View {
        if #available(iOS 15.0, *) {
            background(color.ignoresSafeArea())
        } else {
            background(color)
        }
    }

    @ViewBuilder
    func appLabelStyleTitleAndIcon() -> some View {
        if #available(iOS 14.5, *) {
            labelStyle(.titleAndIcon)
        } else {
            labelStyle(.titleOnly)
        }
    }

    @ViewBuilder
    func appSwipeActions<Actions: View>(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        @ViewBuilder content: () -> Actions
    ) -> some View {
        if #available(iOS 15.0, *) {
            swipeActions(edge: edge, allowsFullSwipe: allowsFullSwipe, content: content)
        } else {
            self
        }
    }
}

enum AppDismissAction {
    static func fromPresentationMode(_ presentationMode: Binding<PresentationMode>) -> () -> Void {
        { presentationMode.wrappedValue.dismiss() }
    }
}
