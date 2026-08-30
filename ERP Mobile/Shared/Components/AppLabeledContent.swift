import SwiftUI
import UIKit

struct AppLabeledContent<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundColor(Color(UIColor.secondaryLabel))
            Spacer(minLength: 12)
            content()
                .multilineTextAlignment(.trailing)
        }
    }
}

extension AppLabeledContent where Content == Text {
    init(_ title: String, value: String) {
        self.title = title
        self.content = { Text(value) }
    }
}
