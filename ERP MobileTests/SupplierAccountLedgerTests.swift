import Foundation
import Testing
@testable import ERPMobile

struct SupplierAccountLedgerTests {
    private let supplierId = UUID()
    private let companyId = UUID()

    @Test func remainingInvoiceBalanceKeepsLeftoverCreditNote() {
        #expect(
            AccountLedgerDisplay.remainingInvoiceBalance(status: .neplatita, restDePlata: -3_000) == -3_000
        )
        #expect(
            AccountLedgerDisplay.remainingInvoiceBalance(status: .neplatita, restDePlata: 7_000) == 7_000
        )
        #expect(
            AccountLedgerDisplay.remainingInvoiceBalance(status: .platita, restDePlata: 0) == nil
        )
    }

    @Test func allocatedCreditNoteReducesInvoiceBalanceWithoutDoubleCounting() {
        let invoiceId = UUID()
        let creditId = UUID()
        let invoice = makeInvoice(
            id: invoiceId,
            number: "F-100",
            day: 1,
            total: 10_000,
            paid: 3_000,
            status: .partial
        )
        let creditNote = makeInvoice(
            id: creditId,
            number: "NC-10",
            day: 15,
            total: -3_000,
            paid: 3_000,
            status: .platita
        )
        let offset = makeOffset(
            creditInvoiceId: creditId,
            targetInvoiceId: invoiceId,
            amount: 3_000
        )

        let built = SupplierAccountLedgerBuilder.build(
            invoices: [invoice, creditNote],
            payments: [],
            creditOffsets: [offset]
        )
        let displayed = SupplierAccountLedgerEntry.prepareForDisplay(
            from: built,
            periodFilter: .all,
            customFrom: Date(),
            customTo: Date(),
            openOnly: false
        )

        let invoiceRow = displayed.first { $0.id == invoiceId }
        let creditRow = displayed.first { $0.id == creditId }

        #expect(invoiceRow?.soldFactura == 7_000)
        #expect(invoiceRow?.soldFinal == 7_000)
        #expect(creditRow?.soldFactura == nil)
        #expect(creditRow?.balanceDelta == 0)
    }

    @Test func openOnlyHidesAllocatedCreditNoteAndKeepsReducedInvoiceRest() {
        let invoiceId = UUID()
        let creditId = UUID()
        let invoice = makeInvoice(
            id: invoiceId,
            number: "F-100",
            day: 1,
            total: 10_000,
            paid: 3_000,
            status: .partial
        )
        let creditNote = makeInvoice(
            id: creditId,
            number: "NC-10",
            day: 15,
            total: -3_000,
            paid: 3_000,
            status: .platita
        )
        let offset = makeOffset(
            creditInvoiceId: creditId,
            targetInvoiceId: invoiceId,
            amount: 3_000
        )

        let displayed = SupplierAccountLedgerEntry.prepareForDisplay(
            from: SupplierAccountLedgerBuilder.build(
                invoices: [invoice, creditNote],
                payments: [],
                creditOffsets: [offset]
            ),
            periodFilter: .all,
            customFrom: Date(),
            customTo: Date(),
            openOnly: true
        )

        #expect(displayed.contains(where: { $0.id == creditId }) == false)
        let invoiceRow = displayed.first { $0.id == invoiceId }
        #expect(invoiceRow?.soldFactura == 7_000)
        #expect(invoiceRow?.soldFinal == 7_000)
    }

    @Test func leftoverCreditNoteShowsNegativeInvoiceBalance() {
        let creditNote = makeInvoice(
            id: UUID(),
            number: "NC-20",
            day: 2,
            total: -5_000,
            paid: 0,
            status: .neplatita
        )

        let displayed = SupplierAccountLedgerEntry.prepareForDisplay(
            from: SupplierAccountLedgerBuilder.build(
                invoices: [creditNote],
                payments: [],
                creditOffsets: []
            ),
            periodFilter: .all,
            customFrom: Date(),
            customTo: Date(),
            openOnly: true
        )

        #expect(displayed.first?.soldFactura == -5_000)
        #expect(displayed.first?.soldFinal == -5_000)
    }

    @Test func allocatedCreditNoteCannotBeReplanned() {
        #expect(CreditNoteOffsetAllocation.isLocked(availableCredit: 0, existingOffsetCount: 2))
        #expect(CreditNoteOffsetAllocation.isLocked(availableCredit: 100, existingOffsetCount: 1) == false)
        #expect(CreditNoteOffsetAllocation.isLocked(availableCredit: 0, existingOffsetCount: 0) == false)

        let existingTarget = UUID()
        let extraTarget = UUID()
        let plan = PaymentAllocationPlan(
            invoiceLines: [
                PaymentAllocationLine(invoiceId: existingTarget, numarFactura: "F-1", amount: 100),
                PaymentAllocationLine(invoiceId: extraTarget, numarFactura: "F-2", amount: 50)
            ],
            advanceAmount: 0
        )
        let insertable = CreditNoteOffsetAllocation.insertablePlan(
            plan,
            excludingExistingTargetIds: [existingTarget]
        )
        #expect(insertable.invoiceLines.map(\.invoiceId) == [extraTarget])
    }

    private func makeInvoice(
        id: UUID,
        number: String,
        day: Int,
        total: Decimal,
        paid: Decimal,
        status: InvoiceStatus
    ) -> SupplierInvoice {
        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 3, day: day)
        )!
        return SupplierInvoice(
            id: id,
            supplierId: supplierId,
            numarFactura: number,
            dataFactura: date,
            dataScadenta: date,
            sumaTotala: total,
            sumaTva: 0,
            sumaPlatita: paid,
            moneda: "RON",
            status: status,
            observatii: nil,
            workLocationId: nil,
            warehouseId: nil,
            createdBy: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeOffset(
        creditInvoiceId: UUID,
        targetInvoiceId: UUID,
        amount: Decimal
    ) -> SupplierInvoiceCreditOffset {
        SupplierInvoiceCreditOffset(
            id: UUID(),
            companyId: companyId,
            creditInvoiceId: creditInvoiceId,
            targetInvoiceId: targetInvoiceId,
            amount: amount,
            createdAt: nil
        )
    }
}
