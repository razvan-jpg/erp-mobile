import SwiftUI

struct CashRegisterExportDirectorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CashRegisterZExtractViewModel

    @State private var parentFolder: URL?
    @State private var newFolderName = ""
    @State private var showParentPicker = false
    @State private var localError: String?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if let parentFolder {
                        Text(parentFolder.path)
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                            .textSelection(.enabled)
                    } else {
                        Text(L10n.tr("utilities.cash_register.export_folder_parent_hint"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Button(L10n.tr("utilities.cash_register.export_folder_choose_parent")) {
                        showParentPicker = true
                    }
                } header: {
                    Text(L10n.tr("utilities.cash_register.export_folder"))
                }

                Section {
                    TextField(L10n.tr("utilities.cash_register.export_folder_new_name_placeholder"), text: $newFolderName)
                } header: {
                    Text(L10n.tr("utilities.cash_register.export_folder_new_name_section"))
                } footer: {
                    Text(L10n.tr("utilities.cash_register.export_folder_new_name_footer"))
                        .font(.caption)
                }

                if let localError {
                    Section {
                        Text(localError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("utilities.cash_register.choose_export_folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
                        confirmSelection()
                    }
                    .disabled(parentFolder == nil)
                }
            }
            .sheet(isPresented: $showParentPicker) {
                DocumentDirectoryPicker(
                    isPresented: $showParentPicker,
                    onPick: { url in
                        parentFolder = url
                        localError = nil
                    },
                    onCancel: {}
                )
            }
        }
    }

    private func confirmSelection() {
        guard let parentFolder else { return }
        localError = nil
        model.confirmExportDirectory(parent: parentFolder, newFolderName: newFolderName)
        if model.errorMessage == nil {
            dismiss()
        } else {
            localError = model.errorMessage
        }
    }
}
