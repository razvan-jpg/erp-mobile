import SwiftUI
import UIKit

struct PhysicalInventoryLineEditView: View {
    let inventoryId: UUID
    let line: PhysicalInventoryLine
    let canEdit: Bool
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var countedText: String
    @State private var observatii: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        inventoryId: UUID,
        line: PhysicalInventoryLine,
        canEdit: Bool,
        onSaved: @escaping () async -> Void
    ) {
        self.inventoryId = inventoryId
        self.line = line
        self.canEdit = canEdit
        self.onSaved = onSaved
        if let counted = line.cantitateNumarata {
            _countedText = State(initialValue: SupplierFormatting.amountString(counted))
        } else {
            _countedText = State(initialValue: SupplierFormatting.amountString(line.stocScriptic))
        }
        _observatii = State(initialValue: line.observatii ?? "")
    }

    private var parsedCount: Decimal? {
        SupplierFormatting.parseAmount(
            countedText,
            maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
        )
    }

    private var previewDifference: Decimal? {
        guard let parsedCount else { return nil }
        return parsedCount - line.stocScriptic
    }

    var body: some View {
        NavigationView {
            ZStack {
                inventoryLineEditList
                LoadingOverlay(isLoading: isSaving)
            }
            .navigationTitle(L10n.tr("inventory.physical_line_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.back")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canEdit {
                        Button(L10n.tr("common.save")) {
                            beginSave()
                        }
                        .disabled(isSaving || parsedCount == nil)
                    }
                }
            }
        }
    }

    private var inventoryLineEditList: some View {
        List {
                Section {
                    AppLabeledContent(L10n.tr("inventory.physical_product"), value: line.productName)
                    if let cod = line.product?.cod, !cod.isEmpty {
                        AppLabeledContent(L10n.tr("inventory.physical_field_code"), value: cod)
                    }
                    if let barcode = line.product?.codBare, !barcode.isEmpty {
                        AppLabeledContent(L10n.tr("inventory.physical_field_barcode"), value: barcode)
                    }
                    AppLabeledContent(L10n.tr("inventory.physical_book_stock")) {
                        Text("\(SupplierFormatting.amountString(line.stocScriptic)) \(line.unitateMasura)")
                    }
                }

                Section(header: Text(L10n.tr("inventory.physical_counted_stock"))) {
                    if canEdit {
                        TextField(SupplierFormatting.amountPlaceholder, text: $countedText)
                            .keyboardType(.decimalPad)
                        Text(SupplierFormatting.invoiceAmountHint)
                            .font(.caption)
                            .foregroundColor(Self.secondaryTextColor)
                    } else if let counted = line.cantitateNumarata {
                        AppLabeledContent(L10n.tr("inventory.field_quantity")) {
                            Text("\(SupplierFormatting.amountString(counted)) \(line.unitateMasura)")
                        }
                    }
                }

                if let difference = previewDifference {
                    Section(header: Text(L10n.tr("inventory.physical_difference_section"))) {
                        Text(differenceLabel(difference))
                            .font(.headline)
                            .foregroundColor(differenceColor(for: difference))
                    }
                }

                Section(header: Text(L10n.tr("inventory.physical_field_notes"))) {
                    if canEdit {
                        MultilineTextField(placeholder: L10n.tr("inventory.physical_notes_placeholder"), text: $observatii)
                    } else {
                        Text(observatii.isEmpty ? "—" : observatii)
                    }
                }

                if let message = errorMessage {
                    Section {
                        Text(message)
                            .foregroundColor(Color(UIColor.systemRed))
                            .font(.caption)
                    }
                }
            }
    }

    private func differenceLabel(_ value: Decimal) -> String {
        if value == 0 {
            return L10n.tr("inventory.physical_difference_zero")
        }
        let sign = value > 0 ? "+" : "−"
        return L10n.tr(
            "inventory.physical_difference",
            "\(sign)\(SupplierFormatting.amountString(abs(value))) \(line.unitateMasura)"
        )
    }

    private func beginSave() {
        Task {
            await save()
        }
    }

    private func save() async {
        guard let parsedCount else {
            errorMessage = L10n.tr("inventory.physical_error_invalid_quantity")
            return
        }
        guard parsedCount >= 0 else {
            errorMessage = L10n.tr("inventory.physical_error_invalid_quantity")
            return
        }

        isSaving = true
        errorMessage = nil
        do {
            _ = try await PhysicalInventoryService.upsertLine(
                inventoryId: inventoryId,
                productId: line.productId,
                cantitateNumarata: parsedCount,
                observatii: observatii
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func differenceColor(for difference: Decimal) -> Color {
        if difference == 0 {
            return Self.secondaryTextColor
        }
        if difference > 0 {
            return Color(UIColor.systemGreen)
        }
        return Color(UIColor.systemRed)
    }

    private static var secondaryTextColor: Color {
        Color(UIColor.secondaryLabel)
    }
}
