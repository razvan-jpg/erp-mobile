import Foundation
import Testing
@testable import ERPMobile

struct NIRCalculationTests {
    @Test func ignoresCatalogSalePriceWithoutExplicitOverride() {
        let lineId = UUID()
        let productId = UUID()
        let line = makeLine(
            id: lineId,
            productId: productId,
            pretUnitar: Decimal(string: "3.59")!,
            sumaLinie: Decimal(string: "2.14")!,
            sumaTva: Decimal(string: "0.24")!,
            cantitate: Decimal(string: "0.59")!,
            cotaTva: Decimal(string: "11")!
        )
        let product = makeProduct(
            id: productId,
            tip: .materiePrima,
            pretVanzare: Decimal(string: "5.00")!
        )

        let computed = NIRCalculation.computeLines(
            invoiceLines: [line],
            productsById: [productId: product]
        ).first!

        #expect(computed.adaosSuma == .zero)
        #expect(computed.adaosProcent == .zero)
        #expect(computed.valoareAmanunt == .zero)
        #expect(computed.pretUnitarCuTvaAmanunt == .zero)
    }

    @Test func usesMarfaCatalogSalePriceWithoutOverride() {
        let lineId = UUID()
        let productId = UUID()
        let salePrice = Decimal(string: "28.00")!
        let line = makeLine(
            id: lineId,
            productId: productId,
            pretUnitar: Decimal(string: "16.50")!,
            sumaLinie: Decimal(string: "82.48")!,
            sumaTva: Decimal(string: "17.32")!,
            cantitate: Decimal(string: "5")!,
            cotaTva: Decimal(string: "21")!
        )
        let product = makeProduct(
            id: productId,
            tip: .marfa,
            pretVanzare: salePrice
        )

        let computed = NIRCalculation.computeLines(
            invoiceLines: [line],
            productsById: [productId: product]
        ).first!

        #expect(computed.pretUnitarCuTvaAmanunt == salePrice)
        #expect(computed.valoareAmanunt == Decimal(string: "140.00")!)
    }

    @Test func appliesMarkupOnlyWithExplicitOverride() {
        let lineId = UUID()
        let productId = UUID()
        let line = makeLine(
            id: lineId,
            productId: productId,
            pretUnitar: Decimal(string: "3.59")!,
            sumaLinie: Decimal(string: "2.14")!,
            sumaTva: Decimal(string: "0.24")!,
            cantitate: Decimal(string: "0.59")!,
            cotaTva: Decimal(string: "11")!
        )
        let product = makeProduct(
            id: productId,
            pretVanzare: Decimal(string: "5.00")!
        )

        let computed = NIRCalculation.computeLines(
            invoiceLines: [line],
            productsById: [productId: product],
            salePriceByLineId: [lineId: Decimal(string: "5.00")!]
        ).first!

        #expect(computed.adaosSuma != .zero)
        #expect(computed.adaosProcent != .zero)
    }

    @Test func keepsRetailColumnsForExplicitMarfaPriceWithoutMarkup() {
        let lineId = UUID()
        let productId = UUID()
        let purchaseWithVAT = Decimal(string: "6.23")!
        let line = makeLine(
            id: lineId,
            productId: productId,
            pretUnitar: Decimal(string: "5.61")!,
            sumaLinie: Decimal(string: "5.61")!,
            sumaTva: Decimal(string: "0.62")!,
            cantitate: Decimal(string: "1")!,
            cotaTva: Decimal(string: "11")!
        )
        let product = makeProduct(
            id: productId,
            tip: .marfa,
            pretVanzare: purchaseWithVAT
        )

        let computed = NIRCalculation.computeLines(
            invoiceLines: [line],
            productsById: [productId: product],
            salePriceByLineId: [lineId: purchaseWithVAT]
        ).first!

        #expect(computed.pretUnitarCuTvaAmanunt == purchaseWithVAT)
        #expect(computed.valoareAmanunt == purchaseWithVAT)
    }

    @Test func productKindIsRawMaterialWithoutMarkup() {
        let line = makeLine(
            pretUnitar: Decimal(string: "4.50")!,
            sumaLinie: Decimal(string: "27.00")!,
            sumaTva: Decimal(string: "2.97")!,
            cantitate: Decimal(string: "6")!,
            cotaTva: Decimal(string: "11")!
        )
        let state = NIRLinePricingState.make(line: line, product: nil)

        #expect(NIRLinePricing.suggestedProductKind(line: line, pricingState: state) == .materiePrima)
    }

    @Test func productKindIsMerchandiseWithMarkup() {
        let line = makeLine(
            pretUnitar: Decimal(string: "4.50")!,
            sumaLinie: Decimal(string: "27.00")!,
            sumaTva: Decimal(string: "2.97")!,
            cantitate: Decimal(string: "6")!,
            cotaTva: Decimal(string: "11")!
        )
        var state = NIRLinePricingState.make(line: line, product: nil)
        NIRLinePricing.applyMarkupEdit("10", line: line, to: &state)

        #expect(NIRLinePricing.suggestedProductKind(line: line, pricingState: state) == .marfa)
        #expect(state.productKind == .marfa)
    }

    @Test func resolvesMislinkedGarantieSGRProductForRetailPricing() {
        let lineId = UUID()
        let wrongProductId = UUID()
        let mirindaProductId = UUID()
        let salePrice = Decimal(string: "8.00")!
        let line = makeLine(
            id: lineId,
            productId: wrongProductId,
            denumire: "0.33L MIRINDA PORTOC DOZA SGR",
            pretUnitar: Decimal(string: "17.11")!,
            sumaLinie: Decimal(string: "17.11")!,
            sumaTva: Decimal(string: "3.59")!,
            cantitate: Decimal(string: "1")!,
            cotaTva: Decimal(string: "21")!
        )
        let garantieSGR = makeProduct(
            id: wrongProductId,
            denumire: "Garantie SGR",
            tip: .materiePrima,
            pretVanzare: .zero
        )
        let mirinda = makeProduct(
            id: mirindaProductId,
            denumire: "0.33L MIRINDA PORTOC DOZA SGR",
            tip: .marfa,
            pretVanzare: salePrice
        )

        let computed = NIRCalculation.computeLines(
            invoiceLines: [line],
            productsById: [wrongProductId: garantieSGR],
            allProducts: [garantieSGR, mirinda]
        ).first!

        #expect(computed.pretUnitarCuTvaAmanunt == salePrice)
        #expect(computed.valoareAmanunt == salePrice)
    }

    @Test func finishedProductImpliesCatalog() {
        #expect(ProductKind.produsFinit.impliesInCatalog)
        #expect(!ProductKind.marfa.impliesInCatalog)
    }

    @Test func defaultEditorSalePriceUsesCatalogForMerchandise() {
        let line = makeLine(
            pretUnitar: Decimal(string: "4.50")!,
            sumaLinie: Decimal(string: "27.00")!,
            sumaTva: Decimal(string: "2.97")!,
            cantitate: Decimal(string: "6")!,
            cotaTva: Decimal(string: "11")!
        )
        let catalogSalePrice = Decimal(string: "6.80")!
        let product = makeProduct(tip: .marfa, pretVanzare: catalogSalePrice)

        let defaultSalePrice = NIRLinePricing.defaultSalePrice(line: line, product: product)
        let state = NIRLinePricingState.make(line: line, product: product)

        #expect(defaultSalePrice == catalogSalePrice)
        #expect(NIRLinePricing.hasExplicitSalePriceOverride(salePrice: defaultSalePrice, line: line))
        #expect(NIRLinePricing.markupPercent(salePrice: defaultSalePrice, line: line) != .zero)
        #expect(state.salePriceText == SupplierFormatting.amountString(catalogSalePrice))
        #expect(state.markupPercentText != SupplierFormatting.amountString(.zero))
    }

    @Test func defaultEditorSalePriceUsesPurchaseForRawMaterial() {
        let line = makeLine(
            pretUnitar: Decimal(string: "4.50")!,
            sumaLinie: Decimal(string: "27.00")!,
            sumaTva: Decimal(string: "2.97")!,
            cantitate: Decimal(string: "6")!,
            cotaTva: Decimal(string: "11")!
        )
        let product = makeProduct(tip: .materiePrima, pretVanzare: Decimal(string: "9.00")!)

        let defaultSalePrice = NIRLinePricing.defaultSalePrice(line: line, product: product)

        #expect(defaultSalePrice == NIRLinePricing.purchaseUnitWithVAT(line: line))
        #expect(NIRLinePricing.hasExplicitSalePriceOverride(salePrice: defaultSalePrice, line: line) == false)
    }

    private func makeLine(
        id: UUID = UUID(),
        productId: UUID = UUID(),
        denumire: String = "Test product",
        pretUnitar: Decimal,
        sumaLinie: Decimal,
        sumaTva: Decimal,
        cantitate: Decimal,
        cotaTva: Decimal
    ) -> SupplierInvoiceLine {
        SupplierInvoiceLine(
            id: id,
            companyId: UUID(),
            invoiceId: UUID(),
            productId: productId,
            numarLinie: 1,
            denumire: denumire,
            cantitate: cantitate,
            pretUnitar: pretUnitar,
            sumaLinie: sumaLinie,
            sumaTva: sumaTva,
            cotaTva: cotaTva,
            unitateMasura: "Buc.",
            createdAt: nil
        )
    }

    private func makeProduct(
        id: UUID = UUID(),
        denumire: String = "Test product",
        tip: ProductKind = .marfa,
        pretVanzare: Decimal
    ) -> Product {
        Product(
            id: id,
            companyId: UUID(),
            cod: nil,
            codBare: nil,
            denumire: denumire,
            descriere: nil,
            unitateMasura: "Buc.",
            unitateAchizitie: nil,
            factorConversie: 1,
            tip: tip,
            cpv: nil,
            isActive: true,
            inCatalog: true,
            inStockSheet: false,
            hasRecipe: false,
            cotaTva: Decimal(string: "11")!,
            pretVanzare: pretVanzare,
            imagineUrl: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
