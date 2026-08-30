import SwiftUI

struct ProductThumbnailView: View {
    let imagineUrl: String?
    var showsPlaceholder: Bool = true
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let imagineUrl,
               !imagineUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let url = URL(string: imagineUrl) {
                AppRemoteImage(url: url) {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                }
            } else if showsPlaceholder {
                placeholder
            }
        }
        .background(showsPlaceholder ? Color(.tertiarySystemBackground) : .clear)
        .clipped()
    }

    private var placeholder: some View {
        Image(systemName: "cube.box")
            .font(.title2)
            .foregroundColor(AppColors.tertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProductTileView: View {
    let product: Product
    let stockQuantity: Decimal
    var productionCost: Decimal?
    var purchasePrice: Decimal?
    var showsExtendedMetrics: Bool = false
    let onTap: () -> Void

    /// Fixed portrait tile proportions.
    private static let tileAspectRatio: CGFloat = 0.62
    private static let imageHeightFraction: CGFloat = 2.0 / 3.0
    private static let textHeightFraction: CGFloat = 1.0 / 3.0
    private static let maxImageWidthFraction: CGFloat = 0.8
    private static let titleZoneHeightFraction: CGFloat = 0.42
    private static let tileTextHorizontalPadding: CGFloat = 2

    private static func titleFontSize(for tileWidth: CGFloat) -> CGFloat {
        min(17, max(13, tileWidth * 0.14))
    }

    private var stockLabel: String {
        L10n.tr(
            "module.products.tile_stock",
            SupplierFormatting.amountString(stockQuantity),
            product.unitateMasura
        )
    }

    private var salePriceLabel: String {
        L10n.tr(
            "module.products.tile_sale_price",
            SupplierFormatting.amountString(product.pretVanzare)
        )
    }

    private var costPriceLabel: String {
        switch product.tip {
        case .produsFinit:
            return L10n.tr(
                "module.products.tile_production_price",
                formattedAmount(productionCost)
            )
        case .marfa:
            return L10n.tr(
                "module.products.tile_purchase_price",
                formattedAmount(purchasePrice)
            )
        default:
            return L10n.tr(
                "module.products.tile_purchase_price",
                formattedAmount(nil)
            )
        }
    }

    private var profitPerUnitLabel: String {
        guard let profit = profitPerUnit else {
            let missing = L10n.tr("module.products.tile_value_missing")
            return L10n.tr("module.products.tile_profit_per_unit", missing, missing)
        }

        let amount = SupplierFormatting.amountString(profit)
        let percent = formattedProfitPercent(profit)
        return L10n.tr("module.products.tile_profit_per_unit", amount, percent)
    }

    private func formattedProfitPercent(_ profit: Decimal) -> String {
        guard let cost = unitCostBasis, cost > 0 else {
            return L10n.tr("module.products.tile_value_missing")
        }
        let percent = SupplierFormatting.roundAmount((profit / cost) * Decimal(100))
        return InventoryFormatting.vatPercent(percent)
    }

    private var profitPerUnit: Decimal? {
        guard let unitCostBasis else { return nil }
        return SupplierFormatting.roundAmount(product.pretVanzare - unitCostBasis)
    }

    private var unitCostBasis: Decimal? {
        switch product.tip {
        case .produsFinit:
            return productionCost
        case .marfa:
            return purchasePrice
        default:
            return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                let tileWidth = geometry.size.width
                let tileHeight = geometry.size.height
                let imageZoneHeight = tileHeight * Self.imageHeightFraction
                let textZoneHeight = tileHeight * Self.textHeightFraction
                let maxImageWidth = tileWidth * Self.maxImageWidthFraction
                let maxImageHeight = tileHeight * Self.imageHeightFraction

                VStack(spacing: 0) {
                    ZStack {
                        ProductThumbnailView(
                            imagineUrl: product.imagineUrl,
                            contentMode: .fit
                        )
                        .frame(maxWidth: maxImageWidth, maxHeight: maxImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .frame(width: tileWidth, height: imageZoneHeight)

                    tileInfoSection(
                        tileWidth: tileWidth,
                        textZoneHeight: textZoneHeight
                    )
                        .padding(.horizontal, Self.tileTextHorizontalPadding)
                        .padding(.vertical, 4)
                        .frame(
                            width: tileWidth,
                            height: textZoneHeight,
                            alignment: .center
                        )
                        .clipped()
                }
                .frame(width: tileWidth, height: tileHeight)
            }
            .aspectRatio(Self.tileAspectRatio, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tileInfoSection(tileWidth: CGFloat, textZoneHeight: CGFloat) -> some View {
        let titleHeight = textZoneHeight * Self.titleZoneHeightFraction
        let titleFontSize = Self.titleFontSize(for: tileWidth)

        VStack(spacing: 0) {
            Text(product.denumire)
                .font(.system(size: titleFontSize, weight: .bold))
                .foregroundColor(AppColors.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
                .frame(height: titleHeight, alignment: .center)

            VStack(spacing: 2) {
                if let barcode = product.codBare, !barcode.isEmpty {
                    Text(barcode)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }

                if showsExtendedMetrics {
                    catalogMetricsContent
                } else {
                    compactMetricsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactMetricsContent: some View {
        VStack(spacing: 3) {
            Text(stockLabel)
                .foregroundColor(AppColors.secondary)
            Text(SupplierFormatting.amountString(product.pretVanzare))
                .foregroundColor(.blue)
        }
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var catalogMetricsContent: some View {
        VStack(spacing: 3) {
            metricLine(stockLabel, color: AppColors.secondary)
            metricLine(costPriceLabel, color: .orange)
            metricLine(salePriceLabel, color: .blue)
            metricLine(profitPerUnitLabel, color: profitColor(profitPerUnit))
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
    }

    private func metricLine(_ text: String, color: Color) -> some View {
        Text(text)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func formattedAmount(_ value: Decimal?) -> String {
        guard let value else {
            return L10n.tr("module.products.tile_value_missing")
        }
        return SupplierFormatting.amountString(value)
    }

    private func profitColor(_ profit: Decimal?) -> Color {
        guard let profit else { return AppColors.secondary }
        if profit > 0 { return .green }
        if profit < 0 { return .red }
        return AppColors.secondary
    }
}
