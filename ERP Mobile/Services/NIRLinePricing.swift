import Foundation

struct NIRLinePricingState: Equatable {
    var salePriceText: String
    var markupPercentText: String
    var productKind: ProductKind = .materiePrima
    var isProductKindManual: Bool = false

    static func make(
        line: SupplierInvoiceLine,
        product: Product?,
        reception: StockUnitConversion.Reception? = nil
    ) -> NIRLinePricingState {
        let resolved = reception ?? StockUnitConversion.reception(invoiceLine: line, product: product)
        let salePrice = NIRLinePricing.defaultSalePrice(line: line, product: product, reception: resolved)
        let markup = NIRLinePricing.markupPercent(salePrice: salePrice, line: line, reception: resolved)
        var state = NIRLinePricingState(
            salePriceText: SupplierFormatting.amountString(salePrice),
            markupPercentText: SupplierFormatting.amountString(markup)
        )
        state.productKind = NIRLinePricing.initialProductKind(
            line: line,
            product: product,
            pricingState: state,
            reception: resolved
        )
        return state
    }
}

enum NIRLinePricing {
    static func defaultSalePrice(
        line: SupplierInvoiceLine,
        product: Product?,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let resolved = reception ?? StockUnitConversion.reception(invoiceLine: line, product: product)
        let purchase = purchaseUnitWithVAT(line: line, reception: resolved)
        if prefersPurchasePriceDefault(product: product) {
            return purchase
        }
        if let product, product.pretVanzare > 0 {
            return SupplierFormatting.roundAmount(product.pretVanzare)
        }
        return purchase
    }

    static func hasExplicitSalePriceOverride(
        salePrice: Decimal,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Bool {
        SupplierFormatting.roundAmount(salePrice) != purchaseUnitWithVAT(line: line, reception: reception)
    }

    static func prefersPurchasePriceDefault(product: Product?) -> Bool {
        guard let product else { return false }
        return product.hasRecipe || product.tip.usesPurchasePriceAsDefault
    }

    static func purchaseUnitWithVAT(
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let unitPrice = reception?.stockUnitPrice ?? line.pretUnitar
        return SupplierFormatting.roundAmount(unitPrice * vatFactor(line: line))
    }

    static func purchaseValueExVAT(line: SupplierInvoiceLine) -> Decimal {
        SupplierFormatting.roundAmount(line.sumaLinie)
    }

    static func markupPercent(
        salePrice: Decimal,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let purchaseValue = purchaseValueExVAT(line: line)
        guard purchaseValue > 0 else { return .zero }

        if SupplierFormatting.roundAmount(salePrice) == purchaseUnitWithVAT(line: line, reception: reception) {
            return .zero
        }

        let retailValueExVAT = retailValueExVAT(salePrice: salePrice, line: line, reception: reception)
        let markupAmount = SupplierFormatting.roundAmount(retailValueExVAT - purchaseValue)
        guard markupAmount != .zero else { return .zero }
        return SupplierFormatting.roundAmount((markupAmount / purchaseValue) * Decimal(100))
    }

    static func salePrice(
        markupPercent: Decimal,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let purchaseValue = purchaseValueExVAT(line: line)
        let retailValueExVAT = SupplierFormatting.roundAmount(
            purchaseValue * (Decimal(1) + (markupPercent / Decimal(100)))
        )
        let quantity = reception?.stockQuantity ?? line.cantitate
        guard quantity > 0 else { return .zero }

        let unitExVAT = SupplierFormatting.roundAmount(retailValueExVAT / quantity)
        return SupplierFormatting.roundAmount(unitExVAT * vatFactor(line: line))
    }

    static func markupAmount(
        salePrice: Decimal,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let purchaseValue = purchaseValueExVAT(line: line)
        let retailValueExVAT = retailValueExVAT(salePrice: salePrice, line: line, reception: reception)
        return SupplierFormatting.roundAmount(retailValueExVAT - purchaseValue)
    }

    static func retailValueExVAT(
        salePrice: Decimal,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil
    ) -> Decimal {
        let quantity = reception?.stockQuantity ?? line.cantitate
        let factor = vatFactor(line: line)
        guard factor > 0 else {
            return SupplierFormatting.roundAmount(salePrice * quantity)
        }
        let unitExVAT = SupplierFormatting.roundAmount(salePrice / factor)
        return SupplierFormatting.roundAmount(unitExVAT * quantity)
    }

    static func parseMarkupPercent(_ text: String) -> Decimal? {
        guard let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 2) else { return nil }
        return SupplierFormatting.roundAmount(value)
    }

    static func applySalePriceEdit(
        _ text: String,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil,
        to state: inout NIRLinePricingState
    ) {
        state.salePriceText = text
        guard let salePrice = ProductService.parseSalePrice(text) else { return }
        state.markupPercentText = SupplierFormatting.amountString(
            markupPercent(salePrice: salePrice, line: line, reception: reception)
        )
        syncSuggestedProductKind(line: line, reception: reception, to: &state)
    }

    static func applyMarkupEdit(
        _ text: String,
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception? = nil,
        to state: inout NIRLinePricingState
    ) {
        state.markupPercentText = text
        guard let markup = parseMarkupPercent(text) else { return }
        let salePrice = salePrice(markupPercent: markup, line: line, reception: reception)
        state.salePriceText = SupplierFormatting.amountString(salePrice)
        syncSuggestedProductKind(line: line, reception: reception, to: &state)
    }

    static func applyProductKindEdit(_ kind: ProductKind, to state: inout NIRLinePricingState) {
        state.productKind = kind
        state.isProductKindManual = true
    }

    static func initialProductKind(
        line: SupplierInvoiceLine,
        product: Product?,
        pricingState: NIRLinePricingState,
        reception: StockUnitConversion.Reception? = nil
    ) -> ProductKind {
        if let product, product.tip.isArticleCategory {
            return product.tip
        }
        return suggestedProductKind(line: line, pricingState: pricingState, reception: reception)
    }

    /// Marfă dacă prețul de vânzare diferă de achiziție și există adaos; altfel materie primă.
    static func suggestedProductKind(
        line: SupplierInvoiceLine,
        pricingState: NIRLinePricingState,
        reception: StockUnitConversion.Reception? = nil
    ) -> ProductKind {
        let trimmed = pricingState.salePriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let salePrice = ProductService.parseSalePrice(trimmed) else {
            return .materiePrima
        }

        guard hasExplicitSalePriceOverride(salePrice: salePrice, line: line, reception: reception) else {
            return .materiePrima
        }

        let markup = markupPercent(salePrice: salePrice, line: line, reception: reception)
        return markup != .zero ? .marfa : .materiePrima
    }

    private static func syncSuggestedProductKind(
        line: SupplierInvoiceLine,
        reception: StockUnitConversion.Reception?,
        to state: inout NIRLinePricingState
    ) {
        guard !state.isProductKindManual else { return }
        state.productKind = suggestedProductKind(line: line, pricingState: state, reception: reception)
    }

    private static func vatFactor(line: SupplierInvoiceLine) -> Decimal {
        let rate = line.cotaTva > 0 ? line.cotaTva : .zero
        return Decimal(1) + (rate / Decimal(100))
    }
}
