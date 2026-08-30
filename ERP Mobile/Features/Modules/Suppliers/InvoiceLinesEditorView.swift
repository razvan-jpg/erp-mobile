import SwiftUI

struct InvoiceLinesEditorView: View {
    @Binding var lines: [EditableInvoiceLine]
    let currency: String
    let canEdit: Bool

    var body: some View {
        Section {
            if lines.isEmpty {
                Text(L10n.tr("invoices.lines_empty"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            } else if canEdit {
                editableLinesList
            } else {
                readOnlyLinesList
            }

            if canEdit {
                Button {
                    addLine()
                } label: {
                    Label(L10n.tr("invoices.lines_add"), systemImage: "plus.circle")
                }
            }
        } header: {
            Text(L10n.tr("invoices.section_lines"))
        } footer: {
            if !lines.isEmpty {
                Text(L10n.tr("invoices.lines_hint"))
            }
        }
    }

    private var editableLinesList: some View {
        ForEach(lines.indices, id: \.self) { index in
            InvoiceLineEditorRow(
                line: $lines[index],
                currency: currency,
                canEdit: true,
                showsSeparator: index < lines.count - 1
            )
        }
        .onDelete(perform: deleteLines)
    }

    private var readOnlyLinesList: some View {
        ForEach(lines.indices, id: \.self) { index in
            InvoiceLineEditorRow(
                line: .constant(lines[index]),
                currency: currency,
                canEdit: false,
                showsSeparator: index < lines.count - 1
            )
        }
    }

    private func addLine() {
        lines.append(EditableInvoiceLine(numarLinie: lines.count + 1))
    }

    private func deleteLines(at offsets: IndexSet) {
        lines.remove(atOffsets: offsets)
        renumberLines()
    }

    private func renumberLines() {
        for index in lines.indices {
            lines[index].numarLinie = index + 1
        }
    }
}

private struct InvoiceLineEditorRow: View {
    @Binding var line: EditableInvoiceLine
    let currency: String
    let canEdit: Bool
    var showsSeparator: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        DeviceLayout.isRegularWidth(horizontalSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canEdit {
                if isRegularWidth {
                    compactSingleRow
                } else {
                    compactStacked
                }
            } else {
                readOnlyRow
            }

            if showsSeparator {
                Divider()
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var compactSingleRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            lineNumberLabel
            nameField
            CompactFormField(
                title: L10n.tr("invoices.line_field_quantity"),
                text: quantityBinding,
                width: 72
            )
            CompactFormField(
                title: L10n.tr("invoices.line_field_unit"),
                text: $line.unitateMasura,
                keyboardType: .default,
                width: 54,
                autocapitalization: .never
            )
            CompactFormField(
                title: L10n.tr("invoices.line_field_unit_price"),
                text: unitPriceBinding,
                width: 80
            )
            CompactFormField(
                title: L10n.tr("invoices.line_field_vat"),
                text: vatBinding,
                width: 72
            )
            lineTotalLabel
        }
    }

    private var compactStacked: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                lineNumberLabel
                nameField
                lineTotalLabel
            }
            HStack(alignment: .bottom, spacing: 8) {
                CompactFormField(
                    title: L10n.tr("invoices.line_field_quantity"),
                    text: quantityBinding,
                    width: 72
                )
                CompactFormField(
                    title: L10n.tr("invoices.line_field_unit"),
                    text: $line.unitateMasura,
                    keyboardType: .default,
                    width: 54,
                    autocapitalization: .never
                )
                CompactFormField(
                    title: L10n.tr("invoices.line_field_unit_price"),
                    text: unitPriceBinding,
                    width: 80
                )
                CompactFormField(
                    title: L10n.tr("invoices.line_field_vat"),
                    text: vatBinding,
                    width: 72
                )
            }
        }
    }

    private var readOnlyRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            lineNumberLabel
            VStack(alignment: .leading, spacing: 2) {
                Text(line.denumire)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(
                    L10n.tr(
                        "invoices.line_readonly_summary",
                        line.cantitate,
                        line.unitateMasura,
                        line.pretUnitar,
                        line.sumaTva
                    )
                )
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            lineTotalLabel
        }
    }

    private var lineNumberLabel: some View {
        Text(L10n.tr("invoices.line_number_short", line.numarLinie))
            .font(.caption.monospacedDigit())
            .foregroundColor(AppColors.secondary)
            .frame(minWidth: 20, alignment: .leading)
            .accessibilityLabel(L10n.tr("invoices.line_number", line.numarLinie))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L10n.tr("invoices.line_field_name"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
                .lineLimit(1)
            TextField(L10n.tr("invoices.line_field_name"), text: $line.denumire)
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1)
                .compactLineControl()
        }
        .frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var lineTotalLabel: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(L10n.tr("invoices.line_total_short"))
                .font(.caption2)
                .foregroundColor(AppColors.secondary)
            if let total = line.computedLineTotal {
                Text(SupplierFormatting.compactAmount(total, code: currency))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
            }
        }
        .frame(minWidth: 64, alignment: .trailing)
    }

    private var quantityBinding: Binding<String> {
        Binding(
            get: { line.cantitate },
            set: {
                line.cantitate = SupplierFormatting.limitAmountInputFractionDigits($0, maxFractionDigits: 4)
            }
        )
    }

    private var unitPriceBinding: Binding<String> {
        Binding(
            get: { line.pretUnitar },
            set: {
                line.pretUnitar = SupplierFormatting.limitAmountInputFractionDigits($0, maxFractionDigits: 4)
            }
        )
    }

    private var vatBinding: Binding<String> {
        Binding(
            get: { line.sumaTva },
            set: {
                line.sumaTva = SupplierFormatting.limitAmountInputFractionDigits($0, maxFractionDigits: 2)
            }
        )
    }
}
