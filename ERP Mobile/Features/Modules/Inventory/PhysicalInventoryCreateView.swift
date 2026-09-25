import SwiftUI

struct PhysicalInventoryCreateView: View {
    let access: ModuleAccessRights
    let onSaved: () async -> Void

    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var companyManager: CompanyManager
    @EnvironmentObject private var session: SessionManager

    @State private var dataInventar = Date()
    @State private var observatii = ""
    @State private var populateFromStock = true
    @State private var warehouses: [CompanyWarehouse] = []
    @State private var warehouseId: UUID?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker(L10n.tr("inventory.field_warehouse"), selection: $warehouseId) {
                        Text(L10n.tr("common.select")).tag(Optional<UUID>.none)
                        ForEach(warehouses.filter(\.isActive)) { warehouse in
                            Text(warehouse.denumire).tag(Optional(warehouse.id))
                        }
                    }
                    DateInputField(title: L10n.tr("inventory.physical_field_date"), date: $dataInventar)
                    Toggle(L10n.tr("inventory.physical_populate_from_stock"), isOn: $populateFromStock)
                }

                Section(header: Text(L10n.tr("inventory.physical_field_notes"))) {
                    MultilineTextField(placeholder: L10n.tr("inventory.physical_notes_placeholder"), text: $observatii)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(L10n.tr("inventory.physical_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        Task { await createInventory() }
                    }
                    .disabled(isSaving || !access.canCreate || warehouseId == nil)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isSaving) }
            .appTask { await loadWarehouses() }
        }
    }

    private func loadWarehouses() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        warehouses = (try? await WarehouseService.fetchWarehouses(companyId: companyId)) ?? []
    }

    private func createInventory() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            let inventory = try await PhysicalInventoryService.createInventory(
                companyId: companyId,
                dataInventar: dataInventar,
                observatii: observatii,
                createdBy: session.currentProfile?.id,
                warehouseId: warehouseId,
                populateFromStock: populateFromStock
            )
            await onSaved()
            presentationMode.wrappedValue.dismiss()
            _ = inventory
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
