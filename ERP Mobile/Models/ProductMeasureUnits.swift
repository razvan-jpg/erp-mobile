import Foundation
import SwiftUI

/// UM de stoc: vânzare doar la bucată, consum doar Kg sau Litru.
enum ProductStockUnit: String, CaseIterable, Identifiable, Sendable {
    case bucata = "Buc."
    case kilogram = "Kg"
    case litru = "Litru"

    var id: String { rawValue }

    var label: String { rawValue }

    static func resolve(_ raw: String) -> ProductStockUnit? {
        Self(rawValue: EFacturaUnitCode.normalize(raw))
    }
}

/// UM de factură/achiziție uzuale (Metro, Lidl, B&B etc.).
enum ProductPurchaseSuggestion: String, CaseIterable, Identifiable, Sendable {
    case bax = "bax"
    case cutie = "cutie"
    case lada = "ladă"
    case palet = "palet"
    case pachet = "pachet"
    case sac = "sac"
    case bidon = "bidon"
    case set = "set"

    var id: String { rawValue }
    var label: String { rawValue }

    static func resolve(_ raw: String) -> ProductPurchaseSuggestion? {
        let normalized = EFacturaUnitCode.normalize(raw)
        return allCases.first { StockUnitConversion.unitsMatch($0.rawValue, normalized) }
    }
}

struct ProductMeasureUnitFields: View {
    @Binding var stockUnit: String
    @Binding var purchaseUnit: String
    @Binding var factorText: String
    var canEdit: Bool = true

    private let otherPurchaseTag = "__other__"

    var body: some View {
        if canEdit {
            editor
        } else {
            readOnly
        }
    }

    private var editor: some View {
        Group {
            Picker(L10n.tr("products.field_stock_unit"), selection: stockPickerBinding) {
                ForEach(stockPickerOptions, id: \.self) { value in
                    Text(value).tag(value)
                }
            }

            Text(L10n.tr("products.field_stock_unit_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)

            Picker(L10n.tr("products.field_purchase_unit"), selection: purchasePickerBinding) {
                Text(L10n.tr("products.purchase_unit_none")).tag("")
                ForEach(ProductPurchaseSuggestion.allCases) { unit in
                    Text(unit.label).tag(unit.rawValue)
                }
                Text(L10n.tr("products.purchase_unit_other")).tag(otherPurchaseTag)
            }

            if purchasePickerValue == otherPurchaseTag {
                FormTextField(
                    title: L10n.tr("products.field_purchase_unit_custom"),
                    text: $purchaseUnit,
                    autocapitalization: .never,
                    autocorrectionDisabled: true
                )
            }

            if showsConversionFactor {
                FormTextField(
                    title: conversionFactorTitle,
                    text: $factorText,
                    keyboardType: .decimalPad,
                    autocapitalization: .never,
                    autocorrectionDisabled: true
                )
            }

            Text(L10n.tr("products.field_conversion_hint"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
    }

    private var readOnly: some View {
        Group {
            AppLabeledContent(L10n.tr("products.field_stock_unit"), value: stockUnit)
            if !trimmedPurchase.isEmpty {
                AppLabeledContent(L10n.tr("products.field_purchase_unit"), value: purchaseUnit)
                if showsConversionFactor {
                    AppLabeledContent(conversionFactorTitle, value: factorText)
                }
            }
        }
    }

    private var trimmedPurchase: String {
        purchaseUnit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedStock: String {
        stockUnit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsConversionFactor: Bool {
        !trimmedPurchase.isEmpty && !StockUnitConversion.unitsMatch(trimmedPurchase, trimmedStock)
    }

    private var conversionFactorTitle: String {
        let purchase = trimmedPurchase.isEmpty ? L10n.tr("products.field_purchase_unit") : trimmedPurchase
        let stock = trimmedStock.isEmpty ? ProductStockUnit.bucata.rawValue : trimmedStock
        return L10n.tr("products.field_conversion_factor", stock, purchase)
    }

    private var stockPickerOptions: [String] {
        var options = ProductStockUnit.allCases.map(\.rawValue)
        let current = trimmedStock
        if !current.isEmpty, ProductStockUnit.resolve(current) == nil {
            options.append(current)
        }
        return options
    }

    private var stockPickerBinding: Binding<String> {
        Binding(
            get: {
                if let resolved = ProductStockUnit.resolve(stockUnit) {
                    return resolved.rawValue
                }
                return trimmedStock.isEmpty ? ProductStockUnit.bucata.rawValue : stockUnit
            },
            set: { stockUnit = $0 }
        )
    }

    private var purchasePickerValue: String {
        let trimmed = trimmedPurchase
        if trimmed.isEmpty { return "" }
        if let suggestion = ProductPurchaseSuggestion.resolve(trimmed) {
            return suggestion.rawValue
        }
        return otherPurchaseTag
    }

    private var purchasePickerBinding: Binding<String> {
        Binding(
            get: { purchasePickerValue },
            set: { newValue in
                if newValue == otherPurchaseTag {
                    if ProductPurchaseSuggestion.resolve(purchaseUnit) != nil || trimmedPurchase.isEmpty {
                        purchaseUnit = ""
                    }
                    return
                }
                purchaseUnit = newValue
                if newValue.isEmpty {
                    factorText = "1"
                }
            }
        )
    }
}
