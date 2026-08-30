import SwiftUI

extension View {
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        modifier(OnChangeCompatModifier(value: value, action: action))
    }
}

private struct OnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (V, V) -> Void

    @State private var previous: V?

    func body(content: Content) -> some View {
        content
            .onAppear { previous = value }
            .onChange(of: value) { newValue in
                let oldValue = previous ?? newValue
                previous = newValue
                action(oldValue, newValue)
            }
    }
}
