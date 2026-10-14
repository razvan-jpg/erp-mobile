import SwiftUI

struct ProductThumbnailView: View {
    let imagineUrl: String?
    var showsPlaceholder: Bool = true
    var contentMode: ContentMode = .fill
    var plate: Color = Color(.tertiarySystemBackground)

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
        .background(showsPlaceholder ? plate : .clear)
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
    var locationStocks: [ProductLocationStock] = []
    var productionCost: Decimal?
    var purchasePrice: Decimal?
    var showsExtendedMetrics: Bool = false
    var recipePricesIncomplete: Bool = false
    let onTap: () -> Void

    @ObservedObject private var stockDecimals = StockQuantityFormat.shared

    /// Fixed portrait tile proportions.
    private static let tileAspectRatio: CGFloat = 0.62
    private static let imageHeightFraction: CGFloat = 0.58
    private static let textHeightFraction: CGFloat = 0.42
    private static let maxImageWidthFraction: CGFloat = 0.8
    private static let titleZoneHeightFraction: CGFloat = 0.36
    private static let tileTextHorizontalPadding: CGFloat = 2

    private static func titleFontSize(for tileWidth: CGFloat) -> CGFloat {
        min(17, max(13, tileWidth * 0.14))
    }

    private var optimalStockLabel: String {
        L10n.tr(
            "module.products.tile_optimal_stock",
            stockDecimals.string(product.cantitateOptima),
            product.unitateMasura
        )
    }

    private var minimumStockLabel: String {
        L10n.tr(
            "module.products.tile_min_stock",
            stockDecimals.string(product.cantitateMinima),
            product.unitateMasura
        )
    }

    private var stockLabel: String {
        L10n.tr(
            "module.products.tile_stock",
            stockDecimals.string(stockQuantity),
            product.unitateMasura
        )
    }

    private var showsLocationStocks: Bool {
        !locationStocks.isEmpty
    }

    private func locationStockLabel(_ line: ProductLocationStock) -> String {
        L10n.tr(
            "module.products.tile_stock_location",
            line.locationName,
            stockDecimals.string(line.quantity),
            product.unitateMasura
        )
    }

    private var salePriceLabel: String {
        L10n.tr(
            "module.products.tile_sale_price",
            SupplierFormatting.amountString(product.pretVanzare)
        )
    }

    private var onlinePriceLabel: String {
        L10n.tr(
            "module.products.tile_sale_price_online",
            SupplierFormatting.amountString(product.pretVanzareOnline)
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
                formattedAmount(merchandisePurchasePrice)
            )
        default:
            return L10n.tr(
                "module.products.tile_purchase_price",
                formattedAmount(product.pretAchizitie)
            )
        }
    }

    private var storeProfitLabel: String {
        profitAmountLabel("module.products.tile_profit_store", storeProfit)
    }

    private var onlineProfitLabel: String {
        profitAmountLabel("module.products.tile_profit_online", onlineProfit)
    }

    private func profitAmountLabel(_ key: String, _ profit: Decimal?) -> String {
        let missing = L10n.tr("module.products.tile_value_missing")
        guard let profit else {
            return L10n.tr(key, missing, missing)
        }
        let amount = SupplierFormatting.amountString(profit)
        let percent: String
        if let cost = unitCostBasis, cost > 0 {
            percent = InventoryFormatting.vatPercent(
                SupplierFormatting.roundAmount((profit / cost) * Decimal(100))
            )
        } else {
            percent = missing
        }
        return L10n.tr(key, amount, percent)
    }

    private var storeProfit: Decimal? {
        guard let unitCostBasis else { return nil }
        return SupplierFormatting.roundAmount(product.pretVanzare - unitCostBasis)
    }

    private var onlineProfit: Decimal? {
        guard let unitCostBasis else { return nil }
        let commission = SupplierFormatting.roundAmount(product.pretVanzareOnline * Decimal(3) / Decimal(10))
        return SupplierFormatting.roundAmount(product.pretVanzareOnline - commission - unitCostBasis)
    }

    private var merchandisePurchasePrice: Decimal? {
        product.pretAchizitie ?? purchasePrice
    }

    private var unitCostBasis: Decimal? {
        switch product.tip {
        case .produsFinit:
            return productionCost
        case .marfa:
            return merchandisePurchasePrice
        default:
            return product.pretAchizitie
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
                    ZStack(alignment: .bottom) {
                        ProductThumbnailView(
                            imagineUrl: product.imagineUrl,
                            contentMode: .fit
                        )
                        .frame(maxWidth: maxImageWidth, maxHeight: maxImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        if recipePricesIncomplete {
                            Text(L10n.tr("module.products.tile_recipe_price_warning"))
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange, in: Capsule())
                                .padding(.bottom, 6)
                                .padding(.horizontal, 6)
                        }
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
        VStack(spacing: 2) {
            Text(salePriceLabel)
                .foregroundColor(.blue)
            Text(onlinePriceLabel)
                .foregroundColor(.blue)
            stockMetricsBlock
        }
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var catalogMetricsContent: some View {
        VStack(spacing: 2) {
            metricLine(salePriceLabel, color: .blue)
            metricLine(onlinePriceLabel, color: .blue)
            stockMetricsBlock
            metricLine(costPriceLabel, color: .orange)
            if product.inCatalog {
                metricLine(storeProfitLabel, color: profitColor(storeProfit))
                if product.pretVanzareOnline > 0 {
                    metricLine(onlineProfitLabel, color: profitColor(onlineProfit))
                }
            }
        }
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var stockMetricsBlock: some View {
        if showsLocationStocks {
            ForEach(locationStocks) { line in
                metricLine(locationStockLabel(line), color: AppColors.secondary)
            }
        } else {
            metricLine(stockLabel, color: AppColors.secondary)
        }
        metricLine(minimumStockLabel, color: AppColors.secondary)
        metricLine(optimalStockLabel, color: AppColors.secondary)
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
