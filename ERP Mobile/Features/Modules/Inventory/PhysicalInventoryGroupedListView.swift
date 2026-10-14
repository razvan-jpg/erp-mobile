import SwiftUI

struct PhysicalInventoryGroupedListView: View {
    let snapshot: PhysicalInventorySnapshot
    let onExportPDF: () async -> Void
    let onPrintPDF: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    private var groups: [(group: PhysicalInventoryCategoryGroup, lines: [PhysicalInventoryLine])] {
        PhysicalInventoryCategoryGroup.groupedLines(from: snapshot.lines)
    }

    var body: some View {
        NavigationView {
            Group {
                if groups.isEmpty {
                    AppEmptyStateView(
                        L10n.tr("inventory.physical_lines_empty"),
                        systemImage: "tray",
                        description: Text(L10n.tr("inventory.physical_lines_empty_readonly"))
                    )
                } else {
                    List {
                        ForEach(groups, id: \.group.id) { entry in
                            Section(
                                header: Text(
                                    L10n.tr("inventory.physical_category_section", entry.group.label, entry.lines.count)
                                )
                            ) {
                                ForEach(Array(entry.lines.enumerated()), id: \.element.id) { index, line in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(index + 1). \(line.productName)")
                                            .font(.subheadline.weight(.semibold))
                                        HStack(spacing: 10) {
                                            if let cod = line.product?.cod, !cod.isEmpty {
                                                Text(cod)
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.secondary)
                                            }
                                            Text("\(L10n.tr("inventory.physical_book_stock")): \(SupplierFormatting.stockQuantityString(line.stocScriptic)) \(line.unitateMasura)")
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondary)
                                            Spacer(minLength: 0)
                                            Text(countedLabel(for: line))
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(line.isCounted ? .primary : .orange)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(L10n.tr("inventory.physical_list_by_category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(L10n.tr("account.export_pdf"), systemImage: "doc.fill") {
                            Task { await onExportPDF() }
                        }
                        .appHoverTip(L10n.tr("account.export_pdf"))
                        Button(L10n.tr("account.print"), systemImage: "printer.fill") {
                            Task { await onPrintPDF() }
                        }
                        .appHoverTip(L10n.tr("account.print"))
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .appControlHint(L10n.tr("account.export_pdf"))
                }
            }
        }
    }

    private func countedLabel(for line: PhysicalInventoryLine) -> String {
        if let counted = line.cantitateNumarata {
            return "\(L10n.tr("inventory.physical_counted_stock")): \(SupplierFormatting.stockQuantityString(counted))"
        }
        return L10n.tr("inventory.physical_not_counted")
    }
}
