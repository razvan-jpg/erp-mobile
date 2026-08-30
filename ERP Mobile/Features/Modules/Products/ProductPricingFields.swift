import SwiftUI

struct ProductPricingFields: View {
    let unit: String
    let isVatPayer: Bool
    let canEdit: Bool
    @Binding var selectedVatRate: Decimal
    @Binding var pretVanzareText: String
    var isSaving: Bool
    var showsSaveButton: Bool = true
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("module.products.section_pricing"))
                .font(.headline)

            if canEdit {
                vatField
                FormTextField(
                    title: L10n.tr("module.products.field_sale_price", unit),
                    text: $pretVanzareText,
                    keyboardType: .decimalPad
                )
                Text(L10n.tr("module.products.sale_price_inclusive_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
                if showsSaveButton {
                    Button(L10n.tr("common.save")) {
                        onSave()
                    }
                    .disabled(isSaving)
                }
            } else {
                AppLabeledContent(L10n.tr("module.products.field_vat_rate"), value: displayVat)
                AppLabeledContent(L10n.tr("module.products.field_sale_price", unit), value: displayPrice)
            }

            if isVatPayer {
                Text(L10n.tr("module.products.vat_payer_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            } else {
                Text(L10n.tr("module.products.vat_non_payer_hint"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            }

            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .onAppear {
            normalizeVatSelection()
        }
        .onChange(of: isVatPayer) { _ in
            normalizeVatSelection()
        }
    }

    @ViewBuilder
    private var vatField: some View {
        if isVatPayer {
            Picker(L10n.tr("module.products.field_vat_rate"), selection: $selectedVatRate) {
                ForEach(ProductVATRates.payerRates, id: \.self) { rate in
                    Text(ProductVATRates.label(for: rate)).tag(rate)
                }
            }
            .pickerStyle(.menu)
        } else {
            AppLabeledContent(L10n.tr("module.products.field_vat_rate"), value: displayVat)
        }
    }

    private var displayVat: String {
        ProductVATRates.label(for: normalizedVatRate)
    }

    private var displayPrice: String {
        SupplierFormatting.amountString(parsedPrice ?? .zero)
    }

    private var normalizedVatRate: Decimal {
        ProductVATRates.normalizedRate(selectedVatRate, isVatPayer: isVatPayer)
    }

    private var parsedPrice: Decimal? {
        ProductService.parseSalePrice(pretVanzareText)
    }

    private func normalizeVatSelection() {
        let normalized = ProductVATRates.normalizedRate(selectedVatRate, isVatPayer: isVatPayer)
        if selectedVatRate != normalized {
            selectedVatRate = normalized
        }
    }
}

extension Product {
    /// Preț de vânzare cu TVA inclus, per unitate (`pret_vanzare`).
    var pretVanzareInputText: String {
        SupplierFormatting.amountString(pretVanzare)
    }
}
