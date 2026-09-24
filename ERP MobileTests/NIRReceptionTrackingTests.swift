import Foundation
import Testing
@testable import ERPMobile

struct NIRReceptionTrackingTests {
    @Test func remainingQuantityAccountsForPriorNIRs() {
        let line = makeLine(cantitate: 10)
        let received: [UUID: Decimal] = [line.id: 4]
        let remaining = NIRReceptionTracking.remainingInvoiceQuantity(
            line: line,
            receivedByInvoiceLineId: received
        )
        #expect(remaining == 6)
    }

    @Test func remainingExcludesCurrentNIRWhenEditing() {
        let line = makeLine(cantitate: 10)
        let received: [UUID: Decimal] = [line.id: 7]
        let current: [UUID: Decimal] = [line.id: 3]
        let remaining = NIRReceptionTracking.remainingInvoiceQuantity(
            line: line,
            receivedByInvoiceLineId: received,
            excludingNIRQuantities: current
        )
        #expect(remaining == 6)
    }

    @Test func incompleteReceptionIgnoresSGRAndAmb() {
        let product = makeLine(denumire: "Apă", cantitate: 5)
        let garantie = makeLine(denumire: "Garantie SGR", cantitate: 10)
        let amb = makeLine(denumire: "Amb. PET 0.5L", cantitate: 20)
        let received: [UUID: Decimal] = [product.id: 5]

        #expect(
            !NIRReceptionTracking.hasIncompleteReception(
                invoiceLines: [product, garantie, amb],
                receivedByInvoiceLineId: received
            )
        )

        let partialReceived: [UUID: Decimal] = [product.id: 2]
        #expect(
            NIRReceptionTracking.hasIncompleteReception(
                invoiceLines: [product, garantie, amb],
                receivedByInvoiceLineId: partialReceived
            )
        )
    }

    @Test func proportionalLineValueScales() {
        let value = NIRReceptionTracking.proportionalLineValue(
            fullValue: 100,
            invoiceQuantity: 2,
            fullQuantity: 4
        )
        #expect(value == 50)
    }

    private func makeLine(denumire: String = "Produs", cantitate: Decimal = 1) -> SupplierInvoiceLine {
        SupplierInvoiceLine(
            id: UUID(),
            companyId: UUID(),
            invoiceId: UUID(),
            productId: UUID(),
            numarLinie: 1,
            denumire: denumire,
            cantitate: cantitate,
            pretUnitar: 1,
            sumaLinie: cantitate,
            sumaTva: 0,
            cotaTva: 19,
            unitateMasura: "Buc.",
            createdAt: nil
        )
    }
}
