import SwiftUI

struct SupplierAccountTableView: View {
    let entries: [SupplierAccountLedgerEntry]
    let moneda: String
    var onInvoiceTap: ((UUID) -> Void)? = nil
    var onPaymentTap: ((UUID) -> Void)? = nil

    private struct TableCell: Hashable {
        let text: String
        let foregroundColor: Color?
    }

    private let borderColor = Color(.separator)
    private let horizontalInset: CGFloat = 6

    private static let columnWidthFractions: [CGFloat] = [
        0.05, 0.05, 0.11, 0.09, 0.09, 0.10, 0.10, 0.10, 0.06, 0.15
    ]

    private var headerValues: [String] {
        [
            L10n.tr("account.table_no"),
            L10n.tr("account.table_doc_type"),
            L10n.tr("account.table_doc_number"),
            L10n.tr("account.table_doc_date"),
            L10n.tr("account.table_due_date"),
            L10n.tr("account.table_amount"),
            L10n.tr("account.table_invoice_balance"),
            L10n.tr("account.table_final_balance"),
            L10n.tr("account.table_overdue_days"),
            L10n.tr("account.table_invoice_status")
        ]
    }

    private var tableHeight: CGFloat {
        let dataRows = entries.isEmpty ? 1 : entries.count
        return 32 + CGFloat(dataRows) * 28
    }

    var body: some View {
        GeometryReader { proxy in
            let tableWidth = max(0, proxy.size.width - horizontalInset * 2)
            let columnWidths = Self.columnWidths(for: tableWidth)
            tableContent(columnWidths: columnWidths)
                .frame(width: tableWidth)
                .frame(maxWidth: proxy.size.width, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: tableHeight)
    }

    private static func columnWidths(for totalWidth: CGFloat) -> [CGFloat] {
        var widths = columnWidthFractions.map { floor(totalWidth * $0) }
        let used = widths.reduce(0, +)
        widths[widths.count - 1] += max(0, totalWidth - used)
        return widths
    }

    @ViewBuilder
    private func tableContent(columnWidths: [CGFloat]) -> some View {
        VStack(spacing: 0) {
            tableRow(
                cells: headerValues.map { TableCell(text: $0, foregroundColor: nil) },
                columnWidths: columnWidths,
                isHeader: true,
                background: Color.secondary.opacity(0.12),
                showsBottomBorder: true,
                entry: nil
            )

            if entries.isEmpty {
                tableRow(
                    cells: Array(repeating: TableCell(text: "—", foregroundColor: nil), count: 10),
                    columnWidths: columnWidths,
                    isHeader: false,
                    background: rowBackground(for: 0),
                    showsBottomBorder: false,
                    entry: nil
                )
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    tableRow(
                        cells: rowCells(for: entry),
                        columnWidths: columnWidths,
                        isHeader: false,
                        background: rowBackground(for: index),
                        showsBottomBorder: index < entries.count - 1,
                        entry: entry
                    )
                }
            }
        }
        .appFullOverlay {
            Rectangle()
                .strokeBorder(borderColor, lineWidth: 0.5)
        }
    }

    private func rowCells(for entry: SupplierAccountLedgerEntry) -> [TableCell] {
        let amountColor: Color? = {
            if !entry.isInvoice { return .red }
            if entry.suma < 0 { return .red }
            return nil
        }()
        return [
            TableCell(text: "\(entry.nrCrt)", foregroundColor: nil),
            TableCell(text: entry.tipDocumentScurt, foregroundColor: nil),
            TableCell(text: entry.nrDocument, foregroundColor: nil),
            TableCell(text: SupplierFormatting.compactDate(entry.dataDocument), foregroundColor: nil),
            TableCell(text: SupplierFormatting.compactDate(entry.dataScadenta), foregroundColor: nil),
            TableCell(
                text: AccountLedgerDisplay.amountText(suma: entry.suma, isInvoice: entry.isInvoice, moneda: moneda),
                foregroundColor: amountColor
            ),
            TableCell(
                text: AccountLedgerDisplay.balanceText(entry.soldFactura, moneda: moneda),
                foregroundColor: Self.balanceColor(entry.soldFactura)
            ),
            TableCell(
                text: AccountLedgerDisplay.balanceText(entry.soldFinal, moneda: moneda),
                foregroundColor: Self.balanceColor(entry.soldFinal)
            ),
            TableCell(text: entry.zileIntarziereDisplay, foregroundColor: nil),
            TableCell(text: entry.statusDisplay, foregroundColor: nil)
        ]
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color(.systemBackground) : Color.secondary.opacity(0.10)
    }

    private static func balanceColor(_ value: Decimal?) -> Color? {
        guard let value else { return nil }
        if value < 0 { return .green }
        if value > 0 { return .orange }
        return nil
    }

    @ViewBuilder
    private func tableRow(
        cells: [TableCell],
        columnWidths: [CGFloat],
        isHeader: Bool,
        background: Color,
        showsBottomBorder: Bool,
        entry: SupplierAccountLedgerEntry?
    ) -> some View {
        let content = HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                tableCell(
                    text: cell.text,
                    width: columnWidths[index],
                    isHeader: isHeader,
                    foregroundColor: cell.foregroundColor,
                    showsTrailingBorder: index < cells.count - 1
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

        if let entry, entry.isInvoice, let onInvoiceTap {
            Button {
                onInvoiceTap(entry.id)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else if let entry, !entry.isInvoice, let onPaymentTap {
            Button {
                onPaymentTap(entry.id)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func tableCell(
        text: String,
        width: CGFloat,
        isHeader: Bool,
        foregroundColor: Color?,
        showsTrailingBorder: Bool
    ) -> some View {
        Text(text)
            .font(isHeader ? .caption2.bold() : .caption2)
            .foregroundColor(isHeader ? .secondary : (foregroundColor ?? .primary))
            .lineLimit(isHeader ? 2 : 2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.trailing)
            .padding(.horizontal, 2)
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
}
