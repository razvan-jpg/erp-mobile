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

    @Test func remainingQuantityAfterOtherNIRs() {
        #expect(NIRQuantityAllocation.remaining(invoiceQuantity: 10, receivedOnOtherNIRs: 4) == 6)
        #expect(NIRQuantityAllocation.remaining(invoiceQuantity: 10, receivedOnOtherNIRs: 10) == 0)
        #expect(NIRQuantityAllocation.remaining(invoiceQuantity: 10, receivedOnOtherNIRs: 12) == 0)
    }

    @Test func invoiceQuantityReceivedUsesStockWhenSameUnit() {
        // Recepție pe jumătate: cantitate_factura a rămas 120, stoc 60, aceeași UM.
        let received = NIRQuantityAllocation.invoiceQuantityReceived(
            cantitateFactura: 120,
            cantitateStoc: 60,
            unitateFactura: "kg",
            unitateStoc: "KG"
        )
        #expect(received == 60)
        #expect(NIRQuantityAllocation.remaining(invoiceQuantity: 120, receivedOnOtherNIRs: received) == 60)
    }

    @Test func invoiceQuantityReceivedKeepsInvoiceQtyForConversion() {
        let received = NIRQuantityAllocation.invoiceQuantityReceived(
            cantitateFactura: 1,
            cantitateStoc: 10,
            unitateFactura: "buc",
            unitateStoc: "kg"
        )
        #expect(received == 1)
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
