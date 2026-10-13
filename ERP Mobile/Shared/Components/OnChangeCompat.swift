import SwiftUI

extension View {
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        onChange(of: value) { oldValue, newValue in
            action(oldValue, newValue)
        }
    }
}
