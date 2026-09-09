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
    @State private var supplierSearch = ""
    @State private var selectedSupplierId: UUID?
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

                if kind == .plataFurnizor {
                    supplierSection
                }

                TextField(L10n.tr("module.cash_register.document_number"), text: $documentNumber)
                TextField(explanationPlaceholder, text: $explanation)
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
            .onChange(of: kind) { newKind in
                if newKind != .plataFurnizor {
                    selectedSupplierId = nil
                    supplierSearch = ""
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var supplierSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("module.cash_register.select_supplier"))
                .font(.subheadline)
            TextField(L10n.tr("module.cash_register.search_supplier"), text: $supplierSearch)
            if filteredSuppliers.isEmpty {
                Text(L10n.tr("module.cash_register.no_suppliers"))
                    .font(.caption)
                    .foregroundColor(AppColors.secondary)
            } else {
                ForEach(filteredSuppliers.prefix(20)) { supplier in
                    Button {
                        selectedSupplierId = supplier.id
                        supplierSearch = supplier.denumire
                    } label: {
                        HStack {
                            Text(supplier.denumire)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSupplierId == supplier.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filteredSuppliers: [Supplier] {
        let query = supplierSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = viewModel.suppliers
        guard !query.isEmpty else { return all }
        if selectedSupplierId != nil,
           let selected = all.first(where: { $0.id == selectedSupplierId }),
           selected.denumire.caseInsensitiveCompare(query) == .orderedSame {
            return [selected]
        }
        return all.filter { $0.denumire.localizedStandardContains(query) }
    }

    private var selectedSupplier: Supplier? {
        guard let selectedSupplierId else { return nil }
        return viewModel.suppliers.first { $0.id == selectedSupplierId }
    }

    private var explanationPlaceholder: String {
        switch kind {
        case .plataFurnizor:
            return L10n.tr("module.cash_register.explanation_optional")
        case .depunereBanca:
            return L10n.tr("module.cash_register.line_depunere_banca")
        default:
            return L10n.tr("module.cash_register.explanation")
        }
    }

    private var resolvedExplanation: String {
        let typed = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        switch kind {
        case .plataFurnizor:
            return L10n.tr("module.cash_register.line_plata_furnizor_advance", selectedSupplier?.denumire ?? "")
        case .depunereBanca:
            return L10n.tr("module.cash_register.line_depunere_banca")
        default:
            return typed
        }
    }

    private var canSave: Bool {
        let hasDocument = !documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasDocument, parsedAmount != nil else { return false }
        switch kind {
        case .plataFurnizor:
            return selectedSupplier != nil
        case .depunereBanca:
            return true
        default:
            return !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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
            explanation: resolvedExplanation,
            amount: amount,
            supplierId: kind == .plataFurnizor ? selectedSupplier?.id : nil,
            supplierName: kind == .plataFurnizor ? selectedSupplier?.denumire : nil
        )
        if saved {
            dismiss()
        }
    }
}
