import SwiftUI

struct ProductWarehouseCardTableView: View {
    let entries: [ProductWarehouseLedgerEntry]

    private let borderColor = Color(.separator)
    private let columnWidths: [CGFloat] = [72, 88, 72, 72, 64, 72]

    private var headerValues: [String] {
        [
            L10n.tr("inventory.card_col_date"),
            L10n.tr("inventory.card_col_document"),
            L10n.tr("inventory.card_col_kind"),
            L10n.tr("inventory.card_col_quantity"),
            L10n.tr("inventory.card_col_price"),
            L10n.tr("inventory.card_col_final_stock")
        ]
    }

    private var tableWidth: CGFloat {
        columnWidths.reduce(0, +)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                tableRow(
                    values: headerValues,
                    isHeader: true,
                    background: Color.secondary.opacity(0.12),
                    showsBottomBorder: true,
                    entry: nil
                )

                if entries.isEmpty {
                    tableRow(
                        values: Array(repeating: "—", count: headerValues.count),
                        isHeader: false,
                        background: rowBackground(for: 0),
                        showsBottomBorder: false,
                        entry: nil
                    )
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        tableRow(
                            values: rowValues(for: entry),
                            isHeader: false,
                            background: rowBackground(for: index),
                            showsBottomBorder: index < entries.count - 1,
                            entry: entry
                        )
                    }
                }
            }
            .frame(width: tableWidth)
            .appFullOverlay {
                Rectangle()
                    .strokeBorder(borderColor, lineWidth: 0.5)
            }
        }
    }

    private func rowValues(for entry: ProductWarehouseLedgerEntry) -> [String] {
        [
            SupplierFormatting.compactDate(entry.dataTranzactie),
            entry.numarDocument,
            entry.fel.label,
            entry.cantitateDisplay,
            entry.pretDisplay,
            entry.stocFinalDisplay
        ]
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color.secondary.opacity(0.10)
    }

    @ViewBuilder
    private func tableRow(
        values: [String],
        isHeader: Bool,
        background: Color,
        showsBottomBorder: Bool,
        entry: ProductWarehouseLedgerEntry?
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                tableCell(
                    text: value,
                    width: columnWidths[index],
                    isHeader: isHeader,
                    isQuantity: !isHeader && index == 3,
                    quantityValue: entry?.cantitate,
                    showsTrailingBorder: index < values.count - 1
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .appOverlay(alignment: .bottom) {
            if showsBottomBorder {
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 0.5)
            }
        }
    }

    private func tableCell(
        text: String,
        width: CGFloat,
        isHeader: Bool,
        isQuantity: Bool,
        quantityValue: Decimal?,
        showsTrailingBorder: Bool
    ) -> some View {
        Text(text)
            .font(isHeader ? .caption2.bold() : .caption2)
            .foregroundColor(cellColor(isHeader: isHeader, isQuantity: isQuantity, quantityValue: quantityValue))
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 4)
            .padding(.vertical, isHeader ? 6 : 4)
            .frame(width: width, alignment: .trailing)
            .frame(minHeight: isHeader ? 32 : 28)
            .clipped()
            .appOverlay(alignment: .trailing) {
                if showsTrailingBorder {
                    Rectangle()
                        .fill(borderColor)
                        .frame(width: 0.5)
                }
            }
    }

    private func cellColor(isHeader: Bool, isQuantity: Bool, quantityValue: Decimal?) -> Color {
        if isHeader { return .secondary }
        guard isQuantity, let quantityValue else { return .primary }
        if quantityValue > 0 { return .green }
        if quantityValue < 0 { return .red }
        return .primary
    }
}
