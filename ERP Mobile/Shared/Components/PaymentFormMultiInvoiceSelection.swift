import SwiftUI
import UIKit

struct PaymentFormOpenInvoiceRow: Identifiable {
    let id: UUID
    let numarFactura: String
    let restDePlata: Decimal
    let dataFactura: Date
    let dataScadenta: Date?
}

struct PaymentFormMultiInvoiceSelectionSection: View {
    let emptyMessageKey: String
    let selectHintKey: String
    let selectedTotalKey: String
    let resetAmountKey: String
    let invoiceRestFormatKey: String
    let openInvoices: [PaymentFormOpenInvoiceRow]
    @Binding var selectedInvoiceIds: [UUID]
    @Binding var suma: String
    @Binding var sumaManuallyEdited: Bool
    @Binding var isApplyingAutoSuma: Bool
    var onSelectionChanged: () -> Void

    private var selectedTotal: Decimal {
        let byId = Dictionary(uniqueKeysWithValues: openInvoices.map { ($0.id, $0.restDePlata) })
        return selectedInvoiceIds.compactMap { byId[$0] }.reduce(0, +)
    }

    var body: some View {
        Group {
            if openInvoices.isEmpty {
                Text(L10n.tr(emptyMessageKey))
                    .font(.caption)
                    .foregroundColor(mutedTextColor)
            } else {
                Text(L10n.tr(selectHintKey))
                    .font(.caption)
                    .foregroundColor(mutedTextColor)

                ForEach(openInvoices) { invoice in
                    Button {
                        toggleSelection(invoice.id)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedInvoiceIds.contains(invoice.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(
                                    selectedInvoiceIds.contains(invoice.id)
                                        ? accentColor
                                        : mutedTextColor
                                )
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(invoice.numarFactura)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(primaryTextColor)
                                Text(L10n.tr(invoiceRestFormatKey, invoice.numarFactura, SupplierFormatting.currency(invoice.restDePlata)))
                                    .font(.caption)
                                    .foregroundColor(mutedTextColor)
                                Text(
                                    L10n.tr(
                                        "payments.invoice_dates_line",
                                        SupplierFormatting.date(invoice.dataFactura),
                                        SupplierFormatting.date(invoice.dataScadenta)
                                    )
                                )
                                .font(.caption2)
                                .foregroundColor(subtleTextColor)
                            }

                            Spacer(minLength: 0)

                            if let order = selectionOrder(for: invoice.id) {
                                Text("#\(order)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(mutedTextColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(mutedTextColor.opacity(0.12))
                                    )
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if !selectedInvoiceIds.isEmpty {
                    AppLabeledContent(L10n.tr(selectedTotalKey)) {
                        Text(SupplierFormatting.currency(selectedTotal))
                            .font(.subheadline.bold())
                    }

                    if sumaManuallyEdited {
                        Button(L10n.tr(resetAmountKey)) {
                            syncAmountFromSelection()
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func selectionOrder(for id: UUID) -> Int? {
        guard let index = selectedInvoiceIds.firstIndex(of: id) else { return nil }
        return index + 1
    }

    private func toggleSelection(_ id: UUID) {
        if let index = selectedInvoiceIds.firstIndex(of: id) {
            selectedInvoiceIds.remove(at: index)
        } else {
            selectedInvoiceIds.append(id)
        }
        syncAmountFromSelection()
    }

    private func syncAmountFromSelection() {
        sumaManuallyEdited = false
        isApplyingAutoSuma = true

        if selectedTotal > 0 {
            suma = SupplierFormatting.amountString(selectedTotal)
        } else {
            suma = ""
        }

        onSelectionChanged()

        Task { @MainActor in
            onSelectionChanged()
            isApplyingAutoSuma = false
        }
    }

    private var primaryTextColor: Color {
        Color(UIColor.label)
    }

    private var mutedTextColor: Color {
        Color(UIColor.secondaryLabel)
    }

    private var subtleTextColor: Color {
        Color(UIColor.tertiaryLabel)
    }

    private var accentColor: Color {
        Color(UIColor.systemBlue)
    }
}

extension SupplierInvoice {
    var paymentFormOpenInvoiceRow: PaymentFormOpenInvoiceRow {
        PaymentFormOpenInvoiceRow(
            id: id,
            numarFactura: numarFactura,
            restDePlata: restDePlata,
            dataFactura: dataFactura,
            dataScadenta: dataScadenta
        )
    }
}

extension ClientInvoice {
    var paymentFormOpenInvoiceRow: PaymentFormOpenInvoiceRow {
        PaymentFormOpenInvoiceRow(
            id: id,
            numarFactura: numarFactura,
            restDePlata: restDePlata,
            dataFactura: dataFactura,
            dataScadenta: dataScadenta
        )
    }
}
