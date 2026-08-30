import Foundation

struct EditableInvoiceLine: Identifiable, Equatable {
    let id: UUID
    var productId: UUID?
    var numarLinie: Int
    var denumire: String
    var cantitate: String
    var pretUnitar: String
    var sumaTva: String
    var unitateMasura: String

    init(from line: SupplierInvoiceLine) {
        id = line.id
        productId = line.productId
        numarLinie = line.numarLinie
        denumire = line.denumire
        cantitate = SupplierFormatting.amountString(line.cantitate)
        pretUnitar = SupplierFormatting.amountString(line.pretUnitar)
        sumaTva = SupplierFormatting.amountString(line.sumaTva)
        unitateMasura = line.unitateMasura
    }

    init(numarLinie: Int) {
        id = UUID()
        productId = nil
        self.numarLinie = numarLinie
        denumire = ""
        cantitate = "1"
        pretUnitar = ""
        sumaTva = "0"
        unitateMasura = "buc"
    }

    var parsedCantitate: Decimal? {
        SupplierFormatting.parseAmount(cantitate, maxFractionDigits: 4)
    }

    var parsedPretUnitar: Decimal? {
        SupplierFormatting.parseAmount(pretUnitar, maxFractionDigits: 4)
    }

    var parsedSumaTva: Decimal? {
        SupplierFormatting.parseAmount(sumaTva, maxFractionDigits: 2) ?? .zero
    }

    var computedLineTotal: Decimal? {
        guard let quantity = parsedCantitate, let unitPrice = parsedPretUnitar else { return nil }
        return SupplierFormatting.roundAmount(quantity * unitPrice)
    }

    var isValid: Bool {
        !denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedCantitate != nil
            && parsedPretUnitar != nil
            && (parsedCantitate ?? 0) != 0
    }

    func toCreateInput(numarLinie: Int, productId: UUID) -> SupplierService.InvoiceLineCreateInput? {
        guard isValid,
              let quantity = parsedCantitate,
              let unitPrice = parsedPretUnitar,
              let lineTotal = computedLineTotal else {
            return nil
        }
        return SupplierService.InvoiceLineCreateInput(
            productId: productId,
            numarLinie: numarLinie,
            denumire: denumire.trimmingCharacters(in: .whitespacesAndNewlines),
            cantitate: quantity,
            pretUnitar: unitPrice,
            sumaLinie: lineTotal,
            sumaTva: parsedSumaTva ?? .zero,
            cotaTva: InvoiceLineVAT.vatRate(amount: parsedSumaTva ?? .zero, lineTotal: lineTotal),
            unitateMasura: unitateMasura.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "buc" : unitateMasura
        )
    }
}

enum InvoiceLinesPersistence {
    static func saveLines(
        companyId: UUID,
        invoiceId: UUID,
        lines: [EditableInvoiceLine]
    ) async throws {
        var products = try await ProductService.fetchProducts(companyId: companyId)
        var createInputs: [SupplierService.InvoiceLineCreateInput] = []
        createInputs.reserveCapacity(lines.count)

        for (index, line) in lines.enumerated() where line.isValid {
            let unit = line.unitateMasura.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "buc"
                : line.unitateMasura
            let productResult = try await ProductService.findOrCreateProduct(
                companyId: companyId,
                cod: nil,
                codBare: nil,
                denumire: line.denumire.trimmingCharacters(in: .whitespacesAndNewlines),
                descriere: nil,
                unitateMasura: unit,
                cpv: nil,
                products: &products
            )
            if let input = line.toCreateInput(numarLinie: index + 1, productId: productResult.product.id) {
                createInputs.append(input)
            }
        }

        try await SupplierService.replaceInvoiceLines(
            companyId: companyId,
            invoiceId: invoiceId,
            lines: createInputs
        )
    }
}
