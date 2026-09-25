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
