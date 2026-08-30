import Foundation
import Testing
@testable import ERPMobile

struct NIRLineEligibilityTests {
    @Test func garantieProductNameMatchesGarantieInName() {
        #expect(ProductService.isGarantieProductName("Garantie"))
        #expect(ProductService.isGarantieProductName("GARANTIE"))
        #expect(ProductService.isGarantieProductName("  Garantie  "))
        #expect(ProductService.isGarantieProductName("Garantie SGR"))
        #expect(ProductService.isGarantieProductName("SGR Garantie ambalaj"))
        #expect(!ProductService.isGarantieProductName("Taxa SGR"))
        #expect(!ProductService.isGarantieProductName("0.33L MIRINDA PORTOC DOZA SGR"))
        #expect(!ProductService.isGarantieProductName("0.33L PEPSI DOZA SGR"))
        #expect(!ProductService.isGarantieProductName("Produs normal"))
    }

    @Test func beverageSGRProductsAreNotSkippedForNIRPricing() {
        #expect(!ProductService.shouldSkipNIRProductKindUpdate(lineName: "0.33L MIRINDA PORTOC DOZA SGR"))
        #expect(!ProductService.shouldSkipNIRProductKindUpdate(lineName: "0.33L PEPSI DOZA SGR"))
        #expect(ProductService.shouldSkipNIRProductKindUpdate(lineName: "Garantie SGR"))
    }

    @Test func autoExcludesGarantieLines() {
        let garantie = makeLine(denumire: "Garantie")
        let garantieSGR = makeLine(denumire: "Garantie SGR")
        let product = makeLine(denumire: "Apă minerală")

        #expect(NIRLineEligibility.isAutoExcluded(garantie))
        #expect(NIRLineEligibility.isAutoExcluded(garantieSGR))
        #expect(!NIRLineEligibility.isAutoExcluded(product))
        #expect(NIRLineEligibility.isReceivable(product))
        #expect(!NIRLineEligibility.isReceivable(garantie))
        #expect(!NIRLineEligibility.isReceivable(garantieSGR))
    }

    private func makeLine(denumire: String) -> SupplierInvoiceLine {
        SupplierInvoiceLine(
            id: UUID(),
            companyId: UUID(),
            invoiceId: UUID(),
            productId: UUID(),
            numarLinie: 1,
            denumire: denumire,
            cantitate: 1,
            pretUnitar: 1,
            sumaLinie: 1,
            sumaTva: 0,
            cotaTva: 19,
            unitateMasura: "Buc.",
            createdAt: nil
        )
    }
}
