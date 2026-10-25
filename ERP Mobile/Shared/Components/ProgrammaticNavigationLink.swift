import SwiftUI
import UIKit

private struct ProgrammaticDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Închide pagina deschisă din cod, în NavigationView-ul existent.
    var programmaticDismiss: (() -> Void)? {
        get { self[ProgrammaticDismissKey.self] }
        set { self[ProgrammaticDismissKey.self] = newValue }
    }
}

/// Împinge o pagină din cod, în NavigationView-ul existent.
struct ProgrammaticNavigationLink<Destination: View>: View {
    @Binding var isActive: Bool
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        ProgrammaticPushAnchor(isActive: $isActive, destination: destination)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}

private struct ProgrammaticPushAnchor<Destination: View>: UIViewControllerRepresentable {
    @Binding var isActive: Bool
    @ViewBuilder var destination: () -> Destination

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AnchorController {
        let controller = AnchorController()
        controller.view.isUserInteractionEnabled = false
        controller.view.backgroundColor = .clear
        controller.onAttached = { [weak coordinator = context.coordinator] anchor in
            coordinator?.sync(anchor: anchor)
        }
        return controller
    }

    func updateUIViewController(_ controller: AnchorController, context: Context) {
        let dismiss = { isActive = false }
        context.coordinator.isActive = $isActive
        context.coordinator.makeDestination = {
            AnyView(destination().environment(\.programmaticDismiss, dismiss))
        }
        context.coordinator.sync(anchor: controller)
    }

    final class Coordinator {
        var isActive: Binding<Bool> = .constant(false)
        var makeDestination: () -> AnyView = { AnyView(EmptyView()) }
        private weak var pushed: PopHost?

        func sync(anchor: UIViewController?) {
            let active = isActive.wrappedValue
            let destination = makeDestination()
            DispatchQueue.main.async { [weak self, weak anchor] in
                guard let self else { return }
                if active {
                    guard let anchor else { return }
                    self.push(from: anchor, destination: destination)
                } else {
                    self.pop()
                }
            }
        }

        private func push(from anchor: UIViewController, destination: AnyView) {
            if pushed != nil { return }
            guard let navigation = Self.navigationController(from: anchor) else { return }
            let host = PopHost(rootView: destination)
            host.onPop = { [weak self] in
                guard let self else { return }
                self.pushed = nil
                if self.isActive.wrappedValue {
                    self.isActive.wrappedValue = false
                }
            }
            pushed = host
            navigation.pushViewController(host, animated: true)
        }

        private static func navigationController(from anchor: UIViewController) -> UINavigationController? {
            if let navigation = anchor.navigationController { return navigation }
            var responder: UIResponder? = anchor.view
            while let current = responder {
                if let navigation = current as? UINavigationController { return navigation }
                if let controller = current as? UIViewController, let navigation = controller.navigationController {
                    return navigation
                }
                responder = current.next
            }
            return nil
        }

        private func pop() {
            guard let host = pushed else { return }
            pushed = nil
            guard let navigation = host.navigationController,
                  navigation.viewControllers.contains(host) else { return }
            if navigation.topViewController === host {
                navigation.popViewController(animated: true)
            }
        }
    }
}

private final class AnchorController: UIViewController {
    var onAttached: ((UIViewController) -> Void)?

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent != nil { onAttached?(self) }
    }
}

private final class PopHost: UIHostingController<AnyView> {
    var onPop: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            onPop?()
        }
    }
}
