import Foundation

enum InvoiceNamePackHint {
    struct Pack: Equatable, Sendable {
        var quantity: Decimal
        var unit: ProductStockUnit
    }

    private static let pattern: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"(\d+(?:[.,]\d+)?)\s*(kilograme|kilogram|kg|litri|litru|ml|l)(?![a-zA-Z%])"#,
            options: [.caseInsensitive]
        )
    }()

    /// Ex.: „CEAPA GALBENA 10KG”, „5KG MC SOS MAIONEZA”, „500ML …”, „3L …”.
    static func parse(_ name: String) -> Pack? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = pattern.firstMatch(in: trimmed, options: [], range: range),
              let amountRange = Range(match.range(at: 1), in: trimmed),
              let unitRange = Range(match.range(at: 2), in: trimmed),
              let amount = SupplierFormatting.parseAmount(
                String(trimmed[amountRange]),
                maxFractionDigits: 4
              ),
              amount > 0
        else { return nil }

        let unitKey = EFacturaUnitCode.lookupKey(String(trimmed[unitRange]))
        switch unitKey {
        case "ml":
            return Pack(quantity: amount / 1000, unit: .litru)
        case "l", "lt", "lit", "litru", "litri", "litre", "liter":
            return Pack(quantity: amount, unit: .litru)
        case "kg", "kilogram", "kilograme", "kilo":
            return Pack(quantity: amount, unit: .kilogram)
        default:
            return nil
        }
    }

    /// Bucată sau ambalaj de factură (sac, găleată, bax, cutie…), nu Kg/Litru.
    static func isPieceLikeInvoiceUnit(_ unit: String) -> Bool {
        let normalized = EFacturaUnitCode.normalize(unit)
        if ProductStockUnit.resolve(normalized) == .bucata {
            return true
        }
        let packs = ["bax", "cutie", "ladă", "sac", "pachet", "set", "palet", "bidon", "pungă", "găleată"]
        return packs.contains { StockUnitConversion.unitsMatch($0, normalized) }
    }
}
