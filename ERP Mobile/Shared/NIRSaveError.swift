import Foundation

enum NIRSaveError: LocalizedError {
    case noReceivableLines
    case quantityExceedsRemaining

    var errorDescription: String? {
        switch self {
        case .noReceivableLines:
            return L10n.tr("nir.error_no_receivable_lines")
        case .quantityExceedsRemaining:
            return L10n.tr("nir.error_quantity_exceeds_remaining")
        }
    }
}

enum NIRQuantityAllocation {
    static func remaining(invoiceQuantity: Decimal, receivedOnOtherNIRs: Decimal) -> Decimal {
        let remaining = invoiceQuantity - receivedOnOtherNIRs
        return remaining > 0 ? remaining : 0
    }

    /// Cantitate pe factură efectiv acoperită de o linie NIR.
    /// Dacă UM factură = UM stoc, cantitatea din stoc e sursa de adevăr (recepție parțială
    /// prin reducerea cantității NIR, nu prin factor artificial tip 0,5).
    static func invoiceQuantityReceived(
        cantitateFactura: Decimal,
        cantitateStoc: Decimal,
        unitateFactura: String,
        unitateStoc: String
    ) -> Decimal {
        let storedInv = cantitateFactura > 0 ? cantitateFactura : cantitateStoc
        let invoiceUnit = unitateFactura.trimmingCharacters(in: .whitespacesAndNewlines)
        let stockUnit = unitateStoc.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedInvoiceUnit = invoiceUnit.isEmpty ? stockUnit : invoiceUnit
        if StockUnitConversion.unitsMatch(resolvedInvoiceUnit, stockUnit) {
            return cantitateStoc > 0 ? cantitateStoc : storedInv
        }
        return storedInv
    }
}

enum NIRLineEligibility {
    static func isGarantieLine(_ line: SupplierInvoiceLine) -> Bool {
        ProductService.isGarantieProductName(line.denumire)
    }

    static func isSelectable(_ line: SupplierInvoiceLine) -> Bool {
        line.cantitate > 0
    }

    static func isReceivable(_ line: SupplierInvoiceLine) -> Bool {
        isSelectable(line) && !isGarantieLine(line)
    }

    static func isAutoExcluded(_ line: SupplierInvoiceLine) -> Bool {
        isGarantieLine(line)
    }

    static func isQuantityExcluded(_ line: SupplierInvoiceLine) -> Bool {
        line.cantitate <= 0
    }
}
