import SwiftUI

struct NIRLinePricingFields: View {
    let line: SupplierInvoiceLine
    let product: Product?
    let reception: StockUnitConversion.Reception
    @Binding var state: NIRLinePricingState

    private var parsedSalePrice: Decimal? {
        ProductService.parseSalePrice(state.salePriceText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                categoryPicker
                salePriceField
                markupField
                markupAmountLabel
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.tr("products.field_category_short"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .lineLimit(1)
            Picker(L10n.tr("products.field_category"), selection: categoryBinding) {
                ForEach(ProductKind.articleCategories) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .compactLineControl()
            .frame(minWidth: 108, maxWidth: 140, alignment: .leading)
        }
    }

    private var salePriceField: some View {
        CompactFormField(
            title: L10n.tr("nir.editor_field_sale_price", reception.stockUnit),
            text: salePriceBinding,
            width: 92
        )
    }

    private var markupField: some View {
        CompactFormField(
            title: L10n.tr("nir.editor_field_markup_pct"),
            text: markupBinding,
            width: 64
        )
    }

    @ViewBuilder
    private var markupAmountLabel: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(L10n.tr("nir.editor_markup_amount_short"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
            if let salePrice = parsedSalePrice {
                Text(
                    SupplierFormatting.amountString(
                        NIRLinePricing.markupAmount(salePrice: salePrice, line: line, reception: reception)
                    )
                )
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            } else {
                Text("—")
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .frame(minWidth: 56, alignment: .trailing)
    }

    private var categoryBinding: Binding<ProductKind> {
        Binding(
            get: { state.productKind },
            set: { newValue in
                var updated = state
                NIRLinePricing.applyProductKindEdit(newValue, to: &updated)
                state = updated
            }
        )
    }

    private var salePriceBinding: Binding<String> {
        Binding(
            get: { state.salePriceText },
            set: { newValue in
                var updated = state
                NIRLinePricing.applySalePriceEdit(newValue, line: line, reception: reception, to: &updated)
                state = updated
            }
        )
    }

    private var markupBinding: Binding<String> {
        Binding(
            get: { state.markupPercentText },
            set: { newValue in
                var updated = state
                NIRLinePricing.applyMarkupEdit(newValue, line: line, reception: reception, to: &updated)
                state = updated
            }
        )
    }
}
