import SwiftUI
import UIKit

private enum ListingsTile: String, CaseIterable, Identifiable {
    case stocks
    case warehouseCards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stocks: return L10n.tr("listings.tile_stocks")
        case .warehouseCards: return L10n.tr("listings.tile_warehouse_cards")
        }
    }

    var hint: String {
        switch self {
        case .stocks: return L10n.tr("listings.tile_stocks_hint")
        case .warehouseCards: return L10n.tr("listings.tile_warehouse_cards_hint")
        }
    }

    var systemImage: String {
        switch self {
        case .stocks: return "shippingbox.fill"
        case .warehouseCards: return "list.bullet.rectangle.portrait"
        }
    }
}

struct ListingsHubView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            ListingsBackButton()
            Group {
            if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 260, maximum: 400), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(ListingsTile.allCases) { tile in
                            NavigationLink {
                                destination(tile)
                            } label: {
                                ModuleTileCardView(
                                    title: tile.title,
                                    description: tile.hint,
                                    systemImage: tile.systemImage
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .appScrollBottomPadding()
            } else {
                List(ListingsTile.allCases) { tile in
                    NavigationLink {
                        destination(tile)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tile.systemImage)
                                .font(.title3)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tile.title)
                                    .font(.headline)
                                Text(tile.hint)
                                    .font(.caption)
                                    .foregroundColor(AppColors.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .appScrollBottomPadding()
            }
        }
        }
        .navigationTitle(L10n.tr("module.hr.tile_listings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func destination(_ tile: ListingsTile) -> some View {
        switch tile {
        case .stocks:
            StockListingsView()
        case .warehouseCards:
            WarehouseCardListingsView()
        }
    }
}

private struct StockListingsView: View {
    var body: some View {
        StockListingView()
    }
}

private struct WarehouseCardListingsView: View {
    var body: some View {
        WarehouseCardListingView()
    }
}

struct ListingsBackButton: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.programmaticDismiss) private var programmaticDismiss

    var body: some View {
        HStack {
            Button {
                if let programmaticDismiss {
                    programmaticDismiss()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                Label(L10n.tr("common.back"), systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}
