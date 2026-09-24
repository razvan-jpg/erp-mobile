import Foundation

enum StockUnitConversion {
    struct Reception: Equatable, Sendable {
        var invoiceQuantity: Decimal
        var invoiceUnit: String
        var factor: Decimal
        var stockQuantity: Decimal
        var stockUnit: String
        var stockUnitPrice: Decimal
        var lineValue: Decimal
        /// Dedusă din denumire / UM diferite, fără factor salvat pe articol — de verificat.
        var needsConversionReview: Bool = false

        var showsConversionUI: Bool {
            needsConversionReview
        }

        var note: String? {
            guard showsConversionUI else { return nil }
            return L10n.tr(
                "nir.conversion_note",
                SupplierFormatting.amountString(invoiceQuantity),
                invoiceUnit,
                invoiceUnit,
                SupplierFormatting.amountString(factor),
                stockUnit
            )
        }
    }

    nonisolated static func unitsMatch(_ lhs: String, _ rhs: String) -> Bool {
        EFacturaUnitCode.normalize(lhs)
            .caseInsensitiveCompare(EFacturaUnitCode.normalize(rhs)) == .orderedSame
    }

    static func defaultFactor(
        product: Product?,
        invoiceUnit: String,
        lineName: String = "",
        allowsConversion: Bool? = nil
    ) -> Decimal {
        guard allowsConversion ?? product?.tip.allowsStockConversion ?? true else { return 1 }
        if InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit),
           let pack = InvoiceNamePackHint.parse(lineName) {
            if let product,
               !unitsMatch(product.unitateMasura, invoiceUnit),
               product.factorConversie > 0,
               product.factorConversie != 1 {
                return product.factorConversie
            }
            return pack.quantity
        }

        guard let product else { return 1 }
        if unitsMatch(product.unitateMasura, invoiceUnit) {
            return 1
        }
        let purchase = product.unitateAchizitie?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !purchase.isEmpty, unitsMatch(purchase, invoiceUnit), product.factorConversie > 0 {
            return product.factorConversie
        }
        if product.factorConversie > 1 {
            return product.factorConversie
        }
        return 1
    }

    static func stockUnit(
        product: Product?,
        invoiceUnit: String,
        lineName: String = "",
        allowsConversion: Bool? = nil
    ) -> String {
        guard allowsConversion ?? product?.tip.allowsStockConversion ?? true else {
            return invoiceUnit
        }
        if InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit),
           let pack = InvoiceNamePackHint.parse(lineName) {
            if let product,
               let resolved = ProductStockUnit.resolve(product.unitateMasura),
               resolved != .bucata {
                return resolved.rawValue
            }
            return pack.unit.rawValue
        }
        let trimmed = product?.unitateMasura.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? invoiceUnit : product!.unitateMasura
    }

    static func reception(
        invoiceLine: SupplierInvoiceLine,
        product: Product?,
        invoiceQuantityOverride: Decimal? = nil,
        factorOverride: Decimal? = nil,
        stockQuantityOverride: Decimal? = nil,
        stockUnitOverride: String? = nil,
        allowsConversion: Bool? = nil
    ) -> Reception {
        let fullInvoiceQuantity = invoiceLine.cantitate
        let invoiceQuantity: Decimal = {
            if let invoiceQuantityOverride, invoiceQuantityOverride > 0 {
                return invoiceQuantityOverride
            }
            return fullInvoiceQuantity
        }()
        let invoiceUnit = invoiceLine.unitateMasura
        let lineName = invoiceLine.denumire
        let canConvert = allowsConversion ?? product?.tip.allowsStockConversion ?? true
        let overrideUnit = stockUnitOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let unit = overrideUnit.isEmpty
            ? stockUnit(
                product: product,
                invoiceUnit: invoiceUnit,
                lineName: lineName,
                allowsConversion: canConvert
            )
            : overrideUnit
        let factor: Decimal
        let stockQuantity: Decimal
        if let stockQuantityOverride, invoiceQuantity > 0 {
            stockQuantity = stockQuantityOverride
            factor = stockQuantity / invoiceQuantity
        } else {
            factor = factorOverride ?? defaultFactor(
                product: product,
                invoiceUnit: invoiceUnit,
                lineName: lineName,
                allowsConversion: canConvert
            )
            stockQuantity = invoiceQuantity * factor
        }
        let lineValue = NIRReceptionTracking.proportionalLineValue(
            fullValue: invoiceLine.sumaLinie,
            invoiceQuantity: invoiceQuantity,
            fullQuantity: fullInvoiceQuantity
        )
        let stockUnitPrice = stockQuantity > 0 ? lineValue / stockQuantity : invoiceLine.pretUnitar
        return Reception(
            invoiceQuantity: invoiceQuantity,
            invoiceUnit: invoiceUnit,
            factor: factor,
            stockQuantity: stockQuantity,
            stockUnit: unit,
            stockUnitPrice: stockUnitPrice,
            lineValue: lineValue,
            needsConversionReview: needsConversionReview(
                product: product,
                invoiceUnit: invoiceUnit,
                lineName: lineName,
                allowsConversion: canConvert
            )
        )
    }

    /// Factor + UM achiziție salvate pe articol = conversie confirmată.
    static func isProductConversionConfirmed(product: Product?, invoiceUnit: String) -> Bool {
        guard let product else { return false }
        guard matchesPurchaseUnit(product, invoiceUnit: invoiceUnit) else { return false }
        return product.factorConversie > 0 && product.factorConversie != 1
    }

    static func needsConversionReview(
        product: Product?,
        invoiceUnit: String,
        lineName: String,
        allowsConversion: Bool
    ) -> Bool {
        guard allowsConversion else { return false }
        if isProductConversionConfirmed(product: product, invoiceUnit: invoiceUnit) {
            return false
        }
        return InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit)
            && InvoiceNamePackHint.parse(lineName) != nil
    }

    static func reception(nirLine: SupplierNIRLine) -> Reception {
        let invoiceQuantity = nirLine.cantitateFactura > 0 ? nirLine.cantitateFactura : nirLine.cantitate
        let invoiceUnit = {
            let trimmed = nirLine.unitateFactura.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nirLine.unitateMasura : nirLine.unitateFactura
        }()
        let factor = nirLine.factorConversie > 0 ? nirLine.factorConversie : 1
        return Reception(
            invoiceQuantity: invoiceQuantity,
            invoiceUnit: invoiceUnit,
            factor: factor,
            stockQuantity: nirLine.cantitate,
            stockUnit: nirLine.unitateMasura,
            stockUnitPrice: nirLine.pretUnitar,
            lineValue: nirLine.sumaLinie
        )
    }

    nonisolated static func matchesPurchaseUnit(_ product: Product, invoiceUnit: String) -> Bool {
        let purchase = product.unitateAchizitie?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !purchase.isEmpty else { return false }
        return unitsMatch(purchase, invoiceUnit)
    }
}
