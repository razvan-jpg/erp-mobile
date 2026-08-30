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
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
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
                    .disabled(isSaving || !access.canCreate)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isSaving) }
        }
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
