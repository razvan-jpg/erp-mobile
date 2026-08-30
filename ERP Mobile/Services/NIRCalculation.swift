import Foundation

enum NIRCalculation {
    static func computeLines(
        invoiceLines: [SupplierInvoiceLine],
        productsById: [UUID: Product],
        salePriceByLineId: [UUID: Decimal] = [:],
        allProducts: [Product] = [],
        conversionByLineId: [UUID: StockUnitConversion.Reception] = [:],
        applyProductConversion: Bool = false
    ) -> [NIRComputedLine] {
        invoiceLines
            .sorted { $0.numarLinie < $1.numarLinie }
            .enumerated()
            .map { index, line in
                let product = ProductService.resolvedProductForNIRLine(
                    line: line,
                    productsById: productsById,
                    allProducts: allProducts
                )
                let reception: StockUnitConversion.Reception
                if let stored = conversionByLineId[line.id] {
                    reception = stored
                } else if applyProductConversion {
                    reception = StockUnitConversion.reception(invoiceLine: line, product: product)
                } else {
                    reception = StockUnitConversion.Reception(
                        invoiceQuantity: line.cantitate,
                        invoiceUnit: line.unitateMasura,
                        factor: 1,
                        stockQuantity: line.cantitate,
                        stockUnit: line.unitateMasura,
                        stockUnitPrice: line.pretUnitar,
                        lineValue: line.sumaLinie
                    )
                }
                return computeLine(
                    line: line,
                    index: index + 1,
                    product: product,
                    salePriceOverride: salePriceByLineId[line.id],
                    reception: reception
                )
            }
    }

    static func computeTotals(from lines: [NIRComputedLine]) -> NIRComputedTotals {
        let valoare = lines.reduce(0) { $0 + $1.valoare }
        let adaosSuma = lines.reduce(0) { $0 + $1.adaosSuma }
        let adaosProcent = valoare > 0
            ? SupplierFormatting.roundAmount((adaosSuma / valoare) * Decimal(100))
            : .zero

        return NIRComputedTotals(
            cantitate: lines.reduce(0) { $0 + $1.cantitate },
            valoare: valoare,
            tvaTotal: lines.reduce(0) { $0 + $1.tvaTotal },
            totalFactura: lines.reduce(0) { $0 + $1.totalFactura },
            adaosProcent: adaosProcent,
            adaosSuma: adaosSuma,
            tvaAfAdeaos: lines.reduce(0) { $0 + $1.tvaAfAdeaos },
            valoareAmanunt: lines.reduce(0) { $0 + $1.valoareAmanunt },
            tvaAmanuntTotal: lines.reduce(0) { $0 + $1.tvaAmanuntTotal }
        )
    }

    private static func computeLine(
        line: SupplierInvoiceLine,
        index: Int,
        product: Product?,
        salePriceOverride: Decimal? = nil,
        reception: StockUnitConversion.Reception
    ) -> NIRComputedLine {
        let cantitate = reception.stockQuantity
        let pretUnitar = reception.stockUnitPrice
        let valoare = SupplierFormatting.roundAmount(line.sumaLinie)
        let tvaTotal = SupplierFormatting.roundAmount(line.sumaTva)
        let tvaPeUnitate = cantitate > 0
            ? SupplierFormatting.roundAmount(tvaTotal / cantitate)
            : .zero
        let totalFactura = SupplierFormatting.roundAmount(valoare + tvaTotal)

        let vatRate = normalizedVatRate(line.cotaTva)
        let vatFactor = Decimal(1) + (vatRate / Decimal(100))

        if !hasExplicitSalePrice(
            line: line,
            product: product,
            salePriceOverride: salePriceOverride
        ) {
            return withoutMarkupColumns(
                NIRComputedLine(
                    index: index,
                    denumire: line.denumire,
                    unitateMasura: reception.stockUnit,
                    cotaTva: vatRate,
                    cantitate: cantitate,
                    pretUnitar: pretUnitar,
                    valoare: valoare,
                    tvaPeUnitate: tvaPeUnitate,
                    tvaTotal: tvaTotal,
                    totalFactura: totalFactura,
                    adaosProcent: .zero,
                    adaosSuma: .zero,
                    pretUnitarFaraTvaAmanunt: .zero,
                    tvaAfAdeaos: .zero,
                    pretUnitarCuTvaAmanunt: .zero,
                    valoareAmanunt: .zero,
                    tvaAmanuntPeUnitate: .zero,
                    tvaAmanuntTotal: .zero,
                    conversieNota: reception.note
                )
            )
        }

        let pretUnitarCuTvaAmanunt: Decimal = {
            if let salePriceOverride {
                return SupplierFormatting.roundAmount(salePriceOverride)
            }
            let salePrice = product?.pretVanzare ?? .zero
            if salePrice > 0 {
                return SupplierFormatting.roundAmount(salePrice)
            }
            return SupplierFormatting.roundAmount(pretUnitar * vatFactor)
        }()

        let pretUnitarFaraTvaAmanunt = vatFactor > 0
            ? SupplierFormatting.roundAmount(pretUnitarCuTvaAmanunt / vatFactor)
            : pretUnitarCuTvaAmanunt

        let valoareAmanunt = SupplierFormatting.roundAmount(cantitate * pretUnitarCuTvaAmanunt)
        let valoareFaraTvaAmanunt = SupplierFormatting.roundAmount(cantitate * pretUnitarFaraTvaAmanunt)
        let tvaAmanuntTotal = SupplierFormatting.roundAmount(valoareAmanunt - valoareFaraTvaAmanunt)
        let tvaAmanuntPeUnitate = cantitate > 0
            ? SupplierFormatting.roundAmount(tvaAmanuntTotal / cantitate)
            : .zero

        let adaosSuma = SupplierFormatting.roundAmount(valoareFaraTvaAmanunt - valoare)
        let adaosProcent = valoare > 0
            ? SupplierFormatting.roundAmount((adaosSuma / valoare) * Decimal(100))
            : .zero
        let tvaAfAdeaos = SupplierFormatting.roundAmount(tvaAmanuntTotal - tvaTotal)

        return withoutMarkupColumns(
            NIRComputedLine(
                index: index,
                denumire: line.denumire,
                unitateMasura: reception.stockUnit,
                cotaTva: vatRate,
                cantitate: cantitate,
                pretUnitar: pretUnitar,
                valoare: valoare,
                tvaPeUnitate: tvaPeUnitate,
                tvaTotal: tvaTotal,
                totalFactura: totalFactura,
                adaosProcent: adaosProcent,
                adaosSuma: adaosSuma,
                pretUnitarFaraTvaAmanunt: pretUnitarFaraTvaAmanunt,
                tvaAfAdeaos: tvaAfAdeaos,
                pretUnitarCuTvaAmanunt: pretUnitarCuTvaAmanunt,
                valoareAmanunt: valoareAmanunt,
                tvaAmanuntPeUnitate: tvaAmanuntPeUnitate,
                tvaAmanuntTotal: tvaAmanuntTotal,
                conversieNota: reception.note
            ),
            keepRetailWhenZeroMarkup: shouldKeepRetailWhenZeroMarkup(
                product: product,
                salePriceOverride: salePriceOverride
            )
        )
    }

    private static func shouldKeepRetailWhenZeroMarkup(
        product: Product?,
        salePriceOverride: Decimal?
    ) -> Bool {
        if salePriceOverride != nil {
            return true
        }
        if product?.tip == .marfa {
            return (product?.pretVanzare ?? 0) > 0
        }
        return false
    }

    private static func withoutMarkupColumns(
        _ line: NIRComputedLine,
        keepRetailWhenZeroMarkup: Bool = false
    ) -> NIRComputedLine {
        guard line.adaosSuma > 0 || keepRetailWhenZeroMarkup else {
            return NIRComputedLine(
                index: line.index,
                denumire: line.denumire,
                unitateMasura: line.unitateMasura,
                cotaTva: line.cotaTva,
                cantitate: line.cantitate,
                pretUnitar: line.pretUnitar,
                valoare: line.valoare,
                tvaPeUnitate: line.tvaPeUnitate,
                tvaTotal: line.tvaTotal,
                totalFactura: line.totalFactura,
                adaosProcent: .zero,
                adaosSuma: .zero,
                pretUnitarFaraTvaAmanunt: .zero,
                tvaAfAdeaos: .zero,
                pretUnitarCuTvaAmanunt: .zero,
                valoareAmanunt: .zero,
                tvaAmanuntPeUnitate: .zero,
                tvaAmanuntTotal: .zero,
                conversieNota: line.conversieNota
            )
        }
        return line
    }

    private static func hasExplicitSalePrice(
        line: SupplierInvoiceLine,
        product: Product?,
        salePriceOverride: Decimal?
    ) -> Bool {
        if NIRLinePricing.prefersPurchasePriceDefault(product: product) {
            return false
        }

        if salePriceOverride != nil {
            return true
        }

        if product?.tip == .marfa {
            return (product?.pretVanzare ?? 0) > 0
        }

        return false
    }

    private static func normalizedVatRate(_ value: Decimal) -> Decimal {
        value > 0 ? value : .zero
    }
}
