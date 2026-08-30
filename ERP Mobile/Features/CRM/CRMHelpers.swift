import SwiftUI

struct CRMInfoBanner: View {
    let text: String
    let color: Color
    var icon: String = "info.circle.fill"

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension View {
    @ViewBuilder
    func crmErrorFooter(_ message: String?) -> some View {
        appSafeAreaInsetBottom {
            if let message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .appBarBackground()
            }
        }
    }
}

enum CRMContactDisplay {
    @MainActor
    static func localizedName(_ contact: CRMContact) -> String {
        let name = contact.fullName
        return name.isEmpty ? L10n.tr("crm.contact_unnamed") : name
    }
}
