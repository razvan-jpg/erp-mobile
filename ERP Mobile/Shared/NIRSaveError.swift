import Foundation

enum NIRSaveError: LocalizedError {
    case noReceivableLines

    var errorDescription: String? {
        switch self {
        case .noReceivableLines:
            return L10n.tr("nir.error_no_receivable_lines")
        }
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
