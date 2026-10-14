import SwiftUI

struct StockDecimalsSettingsView: View {
    @EnvironmentObject private var session: SessionManager
    @EnvironmentObject private var companyManager: CompanyManager

    @State private var digits = StockQuantityFormat.shared.fractionDigits
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker(L10n.tr("settings.stock_decimals.title"), selection: selection) {
                    ForEach(StockQuantityFormat.choices, id: \.self) { choice in
                        Text(L10n.tr("settings.stock_decimals.option", choice)).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!session.isAdmin || isSaving || companyManager.currentCompany == nil)
            } footer: {
                Text(L10n.tr("settings.stock_decimals.hint"))
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle(L10n.tr("settings.stock_decimals.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            digits = StockQuantityFormat.shared.fractionDigits
        }
    }

    private var selection: Binding<Int> {
        Binding(
            get: { digits },
            set: { newValue in
                guard newValue != digits, !isSaving, session.isAdmin else { return }
                let previous = digits
                digits = newValue
                Task { await save(newValue, revertTo: previous) }
            }
        )
    }

    private func save(_ newValue: Int, revertTo previous: Int) async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await CompanyStockSettingsService.saveFractionDigits(companyId: companyId, digits: newValue)
            StockQuantityFormat.shared.apply(newValue)
            errorMessage = nil
        } catch {
            digits = previous
            errorMessage = error.localizedDescription
        }
    }
}
