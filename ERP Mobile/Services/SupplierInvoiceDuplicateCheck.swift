import Foundation

protocol SupplierInvoiceDuplicateRecord {
    var id: UUID { get }
    var supplierId: UUID { get }
    var numarFactura: String { get }
    var dataFactura: Date { get }
    var sumaTotala: Decimal { get }
}

struct SupplierInvoiceDuplicateRef: Decodable, Sendable, SupplierInvoiceDuplicateRecord {
    let id: UUID
    let supplierId: UUID
    let numarFactura: String
    let dataFactura: Date
    @SupabaseDecimal var sumaTotala: Decimal

    enum CodingKeys: String, CodingKey {
        case id
        case supplierId = "supplier_id"
        case numarFactura = "numar_factura"
        case dataFactura = "data_factura"
        case sumaTotala = "suma_totala"
    }
}

extension SupplierInvoiceRow: SupplierInvoiceDuplicateRecord {}

enum SupplierInvoiceDuplicateCheck {
    static func normalizeInvoiceNumber(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func normalizedInvoiceDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func roundedAmount(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }

    static func duplicateKeys(
        supplierId: UUID,
        supplierCUI: String?,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> [String] {
        var keys = [
            duplicateKey(
                supplierId: supplierId,
                number: number,
                issueDate: issueDate,
                totalAmount: totalAmount
            )
        ]
        if let supplierCUI {
            keys.append(
                duplicateKeyByCUI(
                    cui: supplierCUI,
                    number: number,
                    issueDate: issueDate,
                    totalAmount: totalAmount
                )
            )
        }
        return keys
    }

    static func duplicateKeys(
        for supplier: Supplier,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> [String] {
        duplicateKeys(
            supplierId: supplier.id,
            supplierCUI: EFacturaInvoiceParser.normalizeCUI(supplier.cui),
            number: number,
            issueDate: issueDate,
            totalAmount: totalAmount
        )
    }

    static func duplicateKeys(
        for invoice: some SupplierInvoiceDuplicateRecord,
        supplierCuiById: [UUID: String]
    ) -> [String] {
        duplicateKeys(
            supplierId: invoice.supplierId,
            supplierCUI: supplierCuiById[invoice.supplierId],
            number: invoice.numarFactura,
            issueDate: invoice.dataFactura,
            totalAmount: invoice.sumaTotala
        )
    }

    static func duplicateKeySet(
        from invoices: [some SupplierInvoiceDuplicateRecord],
        suppliers: [Supplier],
        excludingInvoiceId: UUID? = nil
    ) -> Set<String> {
        let supplierCuiById = supplierCuiMap(from: suppliers)
        return Set(
            invoices
                .filter { $0.id != excludingInvoiceId }
                .flatMap { duplicateKeys(for: $0, supplierCuiById: supplierCuiById) }
        )
    }

    static func isDuplicate<Invoice: SupplierInvoiceDuplicateRecord>(
        supplier: Supplier,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        existingInvoices: [Invoice],
        suppliers: [Supplier],
        excludingInvoiceId: UUID? = nil
    ) -> Bool {
        findDuplicate(
            supplier: supplier,
            number: number,
            issueDate: issueDate,
            totalAmount: totalAmount,
            existingInvoices: existingInvoices,
            suppliers: suppliers,
            excludingInvoiceId: excludingInvoiceId
        ) != nil
    }

    static func findDuplicate<Invoice: SupplierInvoiceDuplicateRecord>(
        supplier: Supplier,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        existingInvoices: [Invoice],
        suppliers: [Supplier],
        excludingInvoiceId: UUID? = nil
    ) -> Invoice? {
        findExistingInvoice(
            supplierId: supplier.id,
            supplierCUI: EFacturaInvoiceParser.normalizeCUI(supplier.cui),
            number: number,
            issueDate: issueDate,
            totalAmount: totalAmount,
            existingInvoices: existingInvoices,
            suppliers: suppliers,
            excludingInvoiceId: excludingInvoiceId
        )
    }

    static func findExistingInvoice<Invoice: SupplierInvoiceDuplicateRecord>(
        supplierId: UUID,
        supplierCUI: String?,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        existingInvoices: [Invoice],
        suppliers: [Supplier],
        excludingInvoiceId: UUID? = nil
    ) -> Invoice? {
        let supplierCuiById = supplierCuiMap(from: suppliers)
        let candidateKeys = Set(
            duplicateKeys(
                supplierId: supplierId,
                supplierCUI: supplierCUI,
                number: number,
                issueDate: issueDate,
                totalAmount: totalAmount
            )
        )
        let normalizedNumber = normalizeInvoiceNumber(number)

        if let match = existingInvoices.first(where: { invoice in
            if invoice.id == excludingInvoiceId { return false }
            let keys = duplicateKeys(for: invoice, supplierCuiById: supplierCuiById)
            return keys.contains { candidateKeys.contains($0) }
        }) {
            return match
        }

        return existingInvoices.first { invoice in
            if invoice.id == excludingInvoiceId { return false }
            guard normalizeInvoiceNumber(invoice.numarFactura) == normalizedNumber else {
                return false
            }
            if invoice.supplierId == supplierId {
                return true
            }
            if let supplierCUI, supplierCuiById[invoice.supplierId] == supplierCUI {
                return true
            }
            return false
        }
    }

    static func duplicateMessage(
        supplierName: String,
        number: String,
        issueDate: Date,
        totalAmount: Decimal,
        currency: String
    ) -> String {
        L10n.tr(
            "invoices.error_duplicate",
            supplierName,
            normalizeInvoiceNumber(number),
            SupplierFormatting.compactDate(issueDate),
            SupplierFormatting.compactAmount(totalAmount, code: currency)
        )
    }

    private static func supplierCuiMap(from suppliers: [Supplier]) -> [UUID: String] {
        Dictionary(
            uniqueKeysWithValues: suppliers.compactMap { supplier -> (UUID, String)? in
                guard let cui = EFacturaInvoiceParser.normalizeCUI(supplier.cui) else { return nil }
                return (supplier.id, cui)
            }
        )
    }

    private static func duplicateKey(
        supplierId: UUID,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> String {
        let day = normalizedInvoiceDay(issueDate)
        let amount = roundedAmount(totalAmount)
        return "id|\(supplierId.uuidString)|\(normalizeInvoiceNumber(number))|\(day.timeIntervalSince1970)|\(amount)"
    }

    private static func duplicateKeyByCUI(
        cui: String,
        number: String,
        issueDate: Date,
        totalAmount: Decimal
    ) -> String {
        let day = normalizedInvoiceDay(issueDate)
        let amount = roundedAmount(totalAmount)
        return "cui|\(cui)|\(normalizeInvoiceNumber(number))|\(day.timeIntervalSince1970)|\(amount)"
    }
}
