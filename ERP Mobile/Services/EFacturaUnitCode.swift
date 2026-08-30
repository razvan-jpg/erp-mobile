import Foundation

enum EFacturaUnitCode {
    /// Cheie de comparare: lowercase, fără diacritice, fără punct final.
    nonisolated static func lookupKey(_ value: String) -> String {
        var key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let replacements: [(String, String)] = [
            ("ă", "a"), ("â", "a"), ("î", "i"),
            ("ș", "s"), ("ş", "s"),
            ("ț", "t"), ("ţ", "t"),
        ]
        for (from, to) in replacements {
            key = key.replacingOccurrences(of: from, with: to)
        }
        while key.last == "." {
            key.removeLast()
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static let translations: [String: String] = [
        "h87": ProductStockUnit.bucata.rawValue,
        "c62": ProductStockUnit.bucata.rawValue,
        "ea": ProductStockUnit.bucata.rawValue,
        "pce": ProductStockUnit.bucata.rawValue,
        "pcs": ProductStockUnit.bucata.rawValue,
        "pc": ProductStockUnit.bucata.rawValue,
        "piece": ProductStockUnit.bucata.rawValue,
        "buc": ProductStockUnit.bucata.rawValue,
        "bucata": ProductStockUnit.bucata.rawValue,
        "bucati": ProductStockUnit.bucata.rawValue,

        "kgm": ProductStockUnit.kilogram.rawValue,
        "kg": ProductStockUnit.kilogram.rawValue,
        "kilogram": ProductStockUnit.kilogram.rawValue,
        "kilograme": ProductStockUnit.kilogram.rawValue,
        "kilo": ProductStockUnit.kilogram.rawValue,

        "ltr": ProductStockUnit.litru.rawValue,
        "l": ProductStockUnit.litru.rawValue,
        "lt": ProductStockUnit.litru.rawValue,
        "lit": ProductStockUnit.litru.rawValue,
        "litru": ProductStockUnit.litru.rawValue,
        "litri": ProductStockUnit.litru.rawValue,
        "litre": ProductStockUnit.litru.rawValue,
        "liter": ProductStockUnit.litru.rawValue,

        "xbx": "cutie",
        "box": "cutie",
        "cutie": "cutie",
        "cutii": "cutie",
        "xct": "cutie",
        "carton": "cutie",
        "xcr": "bax",
        "crate": "bax",
        "bax": "bax",
        "baxuri": "bax",
        "lada": "ladă",
        "cs": "ladă",
        "case": "ladă",
        "xpx": "palet",
        "palet": "palet",
        "paleta": "palet",
        "pallet": "palet",
        "xpk": "pachet",
        "pack": "pachet",
        "pak": "pachet",
        "pachet": "pachet",
        "xsa": "sac",
        "sack": "sac",
        "sac": "sac",
        "saci": "sac",
        "xbg": "pungă",
        "bag": "pungă",
        "punga": "pungă",
        "set": "set",
        "bidon": "bidon",
        "canistra": "bidon",
        "galeata": "găleată",
        "galeti": "găleată",
        "mtq": "m3",
    ]

    /// Traduce codul UN/ECE din e-Factura și sinonimele uzuale; gol → Buc.
    nonisolated static func normalize(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ProductStockUnit.bucata.rawValue }
        let key = lookupKey(trimmed)
        if let translated = translations[key] {
            return translated
        }
        return key.isEmpty ? ProductStockUnit.bucata.rawValue : key
    }
}
