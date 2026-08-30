import Foundation
import SwiftUI
import UIKit

enum PartnerRole: Sendable, Equatable {
    case supplierOnly
    case clientOnly
    case both

    static func forSupplier(hasClientCounterpart: Bool) -> PartnerRole {
        hasClientCounterpart ? .both : .supplierOnly
    }

    static func forClient(hasSupplierCounterpart: Bool) -> PartnerRole {
        hasSupplierCounterpart ? .both : .clientOnly
    }

    var displayLabel: String {
        switch self {
        case .supplierOnly:
            return L10n.tr("account.partner_role_supplier")
        case .clientOnly:
            return L10n.tr("account.partner_role_client")
        case .both:
            return L10n.tr("account.partner_role_both")
        }
    }

    var showsSupplierBadge: Bool {
        self == .supplierOnly || self == .both
    }

    var showsClientBadge: Bool {
        self == .clientOnly || self == .both
    }
}

struct PartnerRoleBadge: View {
    let role: PartnerRole

    private static let supplierBadgeColor = Color(UIColor.systemBlue)
    private static let clientBadgeColor = Color(red: 48.0 / 255.0, green: 176.0 / 255.0, blue: 199.0 / 255.0)

    var body: some View {
        HStack(spacing: 6) {
            if role.showsSupplierBadge {
                badge(L10n.tr("account.partner_role_supplier"), color: Self.supplierBadgeColor)
            }
            if role.showsClientBadge {
                badge(L10n.tr("account.partner_role_client"), color: Self.clientBadgeColor)
            }
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(color)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}
