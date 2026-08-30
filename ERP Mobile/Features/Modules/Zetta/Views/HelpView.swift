import SwiftUI

struct HelpView: View {
    var onBack: () -> Void

    var body: some View {
        HelpManualView(
            document: HelpContent.zettaManualDocument,
            onBack: onBack,
            useGradientBackground: true
        )
    }
}
