import SwiftUI

struct CashRegisterManualEntrySheet: View {
    @ObservedObject var viewModel: CashRegisterModuleViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var casa: CashRegisterCasaTarget = .headquarters
    @State private var kind: CashRegisterManualEntryKind = .incasareClient
    @State private var documentNumber = ""
    @State private var explanation = ""
    @State private var amountText = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                DateInputField(title: L10n.tr("module.cash_register.from_date"), date: $date, isRequired: true)

                Picker(L10n.tr("module.cash_register.select_casa"), selection: $casa) {
                    ForEach(viewModel.availableCasas, id: \.id) { target in
                        Text(viewModel.casaTitle(target)).tag(target)
                    }
                }

                Picker(L10n.tr("module.cash_register.entry_kind"), selection: $kind) {
                    ForEach(CashRegisterManualEntryKind.allCases) { item in
                        Text(viewModel.kindLabel(item)).tag(item)
                    }
                }

                TextField(L10n.tr("module.cash_register.document_number"), text: $documentNumber)
                TextField(L10n.tr("module.cash_register.explanation"), text: $explanation)
                TextField(L10n.tr("module.cash_register.amount"), text: $amountText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(L10n.tr("module.cash_register.add_manual_entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("module.cash_register.save_entry")) {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSaving || viewModel.isSavingEntry)
                }
            }
            .onAppear {
                casa = viewModel.selectedCasa
            }
        }
        .navigationViewStyle(.stack)
    }

    private var canSave: Bool {
        !documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && parsedAmount != nil
    }

    private var parsedAmount: Decimal? {
        let normalized = amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized), value > 0 else { return nil }
        return value
    }

    private func save() async {
        guard let amount = parsedAmount else { return }
        isSaving = true
        defer { isSaving = false }
        let saved = await viewModel.addManualEntry(
            date: date,
            casa: casa,
            kind: kind,
            documentNumber: documentNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            explanation: explanation.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount
        )
        if saved {
            dismiss()
        }
    }
}
