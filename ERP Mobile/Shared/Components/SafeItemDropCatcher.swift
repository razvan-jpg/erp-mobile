import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Drop de fișiere fără SwiftUI `.onDrop` — pe Mac Catalyst, `.onDrop` în ScrollView crapă la scroll (DragAndDropBridge nil).
struct SafeItemDropCatcher: UIViewRepresentable {
    var typeIdentifiers: [String]
    var onTargetedChange: (Bool) -> Void
    var onDrop: ([NSItemProvider]) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            typeIdentifiers: typeIdentifiers,
            onTargetedChange: onTargetedChange,
            onDrop: onDrop
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.typeIdentifiers = typeIdentifiers
        context.coordinator.onTargetedChange = onTargetedChange
        context.coordinator.onDrop = onDrop
    }

    final class Coordinator: NSObject, UIDropInteractionDelegate {
        var typeIdentifiers: [String]
        var onTargetedChange: (Bool) -> Void
        var onDrop: ([NSItemProvider]) -> Bool

        init(
            typeIdentifiers: [String],
            onTargetedChange: @escaping (Bool) -> Void,
            onDrop: @escaping ([NSItemProvider]) -> Bool
        ) {
            self.typeIdentifiers = typeIdentifiers
            self.onTargetedChange = onTargetedChange
            self.onDrop = onDrop
        }

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.hasItemsConforming(toTypeIdentifiers: typeIdentifiers)
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            let canCopy = session.hasItemsConforming(toTypeIdentifiers: typeIdentifiers)
            return UIDropProposal(operation: canCopy ? .copy : .cancel)
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
            onTargetedChange(true)
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
            onTargetedChange(false)
        }

        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
            onTargetedChange(false)
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            onTargetedChange(false)
            _ = onDrop(session.items.map(\.itemProvider))
        }
    }
}
