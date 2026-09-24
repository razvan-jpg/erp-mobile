import Foundation

enum NIRSaveError: LocalizedError {
    case noReceivableLines
    case quantityExceedsRemaining(lineName: String, remaining: Decimal)

    var errorDescription: String? {
        switch self {
        case .noReceivableLines:
            return L10n.tr("nir.error_no_receivable_lines")
        case .quantityExceedsRemaining(let lineName, let remaining):
            return L10n.tr(
                "nir.error_qty_exceeds_remaining",
                lineName,
                SupplierFormatting.amountString(remaining)
            )
        }
    }
}

enum NIRLineEligibility {
    static func isGarantieLine(_ line: SupplierInvoiceLine) -> Bool {
        ProductService.isNIRReceptionExcludedName(line.denumire)
    }

    static func isSelectable(_ line: SupplierInvoiceLine) -> Bool {
        line.cantitate > 0
    }

    static func isReceivable(_ line: SupplierInvoiceLine) -> Bool {
        isSelectable(line) && !isGarantieLine(line)
    }

    /// Intră în calculul „factură complet recepționată” (excl. SGR / Amb.).
    static func countsTowardReceptionCompletion(_ line: SupplierInvoiceLine) -> Bool {
        isReceivable(line)
    }

    static func isAutoExcluded(_ line: SupplierInvoiceLine) -> Bool {
        isGarantieLine(line)
    }

    static func isQuantityExcluded(_ line: SupplierInvoiceLine) -> Bool {
        line.cantitate <= 0
    }
}
