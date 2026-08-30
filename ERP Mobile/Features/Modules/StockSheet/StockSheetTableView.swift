import SwiftUI

struct StockSheetTableView: View {
    let entries: [StockSheetLedgerEntry]

    private let borderColor = Color(.separator)
    private let columnWidths: [CGFloat] = [72, 88, 64, 72, 64, 72, 72, 80]

    private var headerValues: [String] {
        [
            L10n.tr("stock_sheet.col_date"),
            L10n.tr("stock_sheet.col_document"),
            L10n.tr("stock_sheet.col_in_qty"),
            L10n.tr("stock_sheet.col_in_value"),
            L10n.tr("stock_sheet.col_out_qty"),
            L10n.tr("stock_sheet.col_out_value"),
            L10n.tr("stock_sheet.col_stock_qty"),
            L10n.tr("stock_sheet.col_stock_value")
        ]
    }

    private var tableWidth: CGFloat {
        columnWidths.reduce(0, +)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                tableRow(values: headerValues, isHeader: true, background: Color.secondary.opacity(0.12), showsBottomBorder: true)

                if entries.isEmpty {
                    tableRow(
                        values: [L10n.tr("stock_sheet.ledger_empty")] + Array(repeating: "", count: headerValues.count - 1),
                        isHeader: false,
                        background: rowBackground(for: 0),
                        showsBottomBorder: false
                    )
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        tableRow(
                            values: rowValues(for: entry),
                            isHeader: false,
                            background: rowBackground(for: index),
                            showsBottomBorder: index < entries.count - 1
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

    private func rowValues(for entry: StockSheetLedgerEntry) -> [String] {
        [
            SupplierFormatting.compactDate(entry.dataTranzactie),
            entry.numarDocument,
            blankIfZero(entry.cantitateIntrare),
            blankIfZero(entry.valoareIntrare, currency: true),
            blankIfZero(entry.cantitateIesire),
            blankIfZero(entry.valoareIesire, currency: true),
            SupplierFormatting.amountString(entry.stocCantitate),
            SupplierFormatting.currency(entry.stocValoare)
        ]
    }

    private func blankIfZero(_ value: Decimal, currency: Bool = false) -> String {
        value == 0 ? "" : (currency ? SupplierFormatting.currency(value) : SupplierFormatting.amountString(value))
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color.secondary.opacity(0.10)
    }

    private func tableRow(
        values: [String],
        isHeader: Bool,
        background: Color,
        showsBottomBorder: Bool
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(isHeader ? .caption2.bold() : .caption2)
                    .foregroundColor(isHeader ? .secondary : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(index == 1 ? .leading : .trailing)
                    .padding(.horizontal, 4)
                    .padding(.vertical, isHeader ? 6 : 4)
                    .frame(width: columnWidths[index], alignment: index == 1 ? .leading : .trailing)
                    .frame(minHeight: isHeader ? 32 : 28)
                    .clipped()
                    .appOverlay(alignment: .trailing) {
                        if index < values.count - 1 {
                            Rectangle()
                                .fill(borderColor)
                                .frame(width: 0.5)
                        }
                    }
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
}
