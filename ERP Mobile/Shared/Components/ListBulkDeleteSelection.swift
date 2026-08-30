import SwiftUI

struct BulkDeleteSelectionCheckbox: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundColor(isSelected ? .accentColor : AppColors.secondary)
    }
}

extension View {
    @ViewBuilder
    func bulkDeleteSelectionToolbar(
        enabled: Bool = true,
        isSelectionMode: Bool,
        allVisibleSelected: Bool,
        hasVisibleItems: Bool,
        selectedCount: Int,
        onEnterSelection: @escaping () -> Void,
        onExitSelection: @escaping () -> Void,
        onToggleSelectAll: @escaping () -> Void,
        onDeleteSelected: @escaping () -> Void
    ) -> some View {
        if enabled {
            if isSelectionMode {
                self.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.tr("common.cancel")) {
                            onExitSelection()
                        }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        if selectedCount > 0 {
                            Button(role: .destructive, action: onDeleteSelected) {
                                Label(L10n.tr("common.bulk_delete_selected", selectedCount), systemImage: "trash")
                            }
                        }
                        Button(allVisibleSelected ? L10n.tr("common.deselect_all") : L10n.tr("common.select_all")) {
                            onToggleSelectAll()
                        }
                        .disabled(!hasVisibleItems)
                    }
                }
            } else {
                self.toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: onEnterSelection) {
                            Label(L10n.tr("common.select_items"), systemImage: "checklist")
                        }
                    }
                }
            }
        } else {
            self
        }
    }
}

struct BulkDeleteSelectionBottomBar: View {
    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.tr("common.selected_count", selectedCount))
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Label(L10n.tr("common.bulk_delete_selected", selectedCount), systemImage: "trash")
            }
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .appBarBackground()
    }
}
