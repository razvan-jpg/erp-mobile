import Foundation
import Testing
@testable import ERPMobile

struct MeasureUnitTests {
    @Test func normalizesSaleAndConsumptionUnits() {
        #expect(EFacturaUnitCode.normalize("buc") == "Buc.")
        #expect(EFacturaUnitCode.normalize("Buc.") == "Buc.")
        #expect(EFacturaUnitCode.normalize("H87") == "Buc.")
        #expect(EFacturaUnitCode.normalize("kg.") == "Kg")
        #expect(EFacturaUnitCode.normalize("KGM") == "Kg")
        #expect(EFacturaUnitCode.normalize("l") == "Litru")
        #expect(EFacturaUnitCode.normalize("LTR") == "Litru")
        #expect(ProductStockUnit.resolve("litru") == .litru)
        #expect(ProductStockUnit.resolve("bax") == nil)
    }

    @Test func normalizesSupplierInvoicePacks() {
        #expect(EFacturaUnitCode.normalize("BAX") == "bax")
        #expect(EFacturaUnitCode.normalize("XCR") == "bax")
        #expect(EFacturaUnitCode.normalize("CUTIE") == "cutie")
        #expect(EFacturaUnitCode.normalize("XBX") == "cutie")
        #expect(EFacturaUnitCode.normalize("ladă") == "ladă")
        #expect(StockUnitConversion.unitsMatch("Buc.", "buc"))
        #expect(StockUnitConversion.unitsMatch("Kg.", "kg"))
        #expect(StockUnitConversion.unitsMatch("bax", "BAX"))
        #expect(StockUnitConversion.unitsMatch("Buc.", "bax") == false)
    }

    @Test func parsesPackSizeFromMetroNames() {
        let onion = InvoiceNamePackHint.parse("CEAPA GALBENA 10KG")
        #expect(onion?.quantity == 10)
        #expect(onion?.unit == .kilogram)

        let potatoes = InvoiceNamePackHint.parse("MC CARTOFI ALBI 10KG")
        #expect(potatoes?.quantity == 10)
        #expect(potatoes?.unit == .kilogram)

        let mayo = InvoiceNamePackHint.parse("5KG MC SOS MAIONEZA")
        #expect(mayo?.quantity == 5)
        #expect(mayo?.unit == .kilogram)

        let yogurt = InvoiceNamePackHint.parse("5KG MC IAURT 10%")
        #expect(yogurt?.quantity == 5)
        #expect(yogurt?.unit == .kilogram)

        let spray = InvoiceNamePackHint.parse("500ML TRIUMF DET BUCAT SPRAY")
        #expect(spray?.unit == .litru)
        #expect(spray?.quantity == Decimal(string: "0.5"))

        let detergent = InvoiceNamePackHint.parse("5L ARO DETERGENT LICHID GEAM")
        #expect(detergent?.quantity == 5)
        #expect(detergent?.unit == .litru)

        #expect(InvoiceNamePackHint.parse("PATRUNJEL") == nil)
    }

    @Test func pieceInvoiceWithPackNameConvertsToStockQty() {
        let line = SupplierInvoiceLine(
            id: UUID(),
            companyId: UUID(),
            invoiceId: UUID(),
            productId: UUID(),
            numarLinie: 1,
            denumire: "CEAPA GALBENA 10KG",
            cantitate: 1,
            pretUnitar: Decimal(string: "23.90")!,
            sumaLinie: Decimal(string: "23.90")!,
            sumaTva: Decimal(string: "2.63")!,
            cotaTva: 11,
            unitateMasura: "Buc.",
            createdAt: nil
        )
        let reception = StockUnitConversion.reception(invoiceLine: line, product: nil)
        #expect(reception.stockUnit == "Kg")
        #expect(reception.stockQuantity == 10)
        #expect(reception.factor == 10)
        #expect(SupplierFormatting.roundAmount(reception.stockUnitPrice) == Decimal(string: "2.39"))
        #expect(reception.lineValue == Decimal(string: "23.90"))
        #expect(reception.needsConversionReview)
    }

    @Test func sameUnitLineDoesNotNeedConversionReview() {
        let line = SupplierInvoiceLine(
            id: UUID(),
            companyId: UUID(),
            invoiceId: UUID(),
            productId: UUID(),
            numarLinie: 1,
            denumire: "ROSII RO",
            cantitate: Decimal(string: "9.98")!,
            pretUnitar: Decimal(string: "3.09")!,
            sumaLinie: Decimal(string: "30.82")!,
            sumaTva: Decimal(string: "3.39")!,
            cotaTva: 11,
            unitateMasura: "Kg",
            createdAt: nil
        )
        let reception = StockUnitConversion.reception(invoiceLine: line, product: nil)
        #expect(reception.needsConversionReview == false)
        #expect(reception.stockUnit == "Kg")
        #expect(reception.factor == 1)
    }

    @Test func expenseKindDoesNotConvertPackInName() {
        let line = SupplierInvoiceLine(
            id: UUID(),
            companyId: UUID(),
            invoiceId: UUID(),
            productId: UUID(),
            numarLinie: 1,
            denumire: "5L ARO DETERGENT LICHID GEAM",
            cantitate: 2,
            pretUnitar: Decimal(string: "18.00")!,
            sumaLinie: Decimal(string: "36.00")!,
            sumaTva: Decimal(string: "7.56")!,
            cotaTva: 21,
            unitateMasura: "Buc.",
            createdAt: nil
        )
        let converted = StockUnitConversion.reception(
            invoiceLine: line,
            product: nil,
            allowsConversion: true
        )
        #expect(converted.stockQuantity == 10)
        #expect(converted.stockUnit == "Litru")
        #expect(converted.needsConversionReview)

        let expense = StockUnitConversion.reception(
            invoiceLine: line,
            product: nil,
            allowsConversion: false
        )
        #expect(expense.stockQuantity == 2)
        #expect(expense.stockUnit == "Buc.")
        #expect(expense.factor == 1)
        #expect(expense.needsConversionReview == false)
    }
}
