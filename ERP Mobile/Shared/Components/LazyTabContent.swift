import SwiftUI

/// Amână construirea conținutului unui tab până la prima afișare, pentru a evita blocarea la pornire.
struct LazyTabContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isActive = false

    var body: some View {
        Group {
            if isActive {
                content()
            } else {
                ZStack {
                    Color(.systemBackground)
                    ProgressView()
                }
            }
        }
        .onAppear { isActive = true }
    }
}
