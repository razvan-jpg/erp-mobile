import SwiftUI

struct ProductCreateView: View {
    @Binding var isPresented: Bool
    let onSaved: () async -> Void
    var onCreatedFromScan: ((Product) -> Void)? = nil

    @EnvironmentObject private var companyManager: CompanyManager

    @State private var denumire = ""
    @State private var cod = ""
    @State private var codBare = ""
    @State private var unitateMasura = ProductStockUnit.bucata.rawValue
    @State private var unitateAchizitie = ""
    @State private var factorConversieText = "1"
    @State private var tip: ProductKind = .materiePrima
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showAutoCreateScanner = false
    @State private var showFieldScanner = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button {
                        showAutoCreateScanner = true
                    } label: {
                        Label(L10n.tr("module.products.scan_and_create"), systemImage: "barcode.viewfinder")
                    }
                    .disabled(isLoading)

                    Text(L10n.tr("module.products.scan_and_create_hint"))
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }

                Section(header: Text(L10n.tr("module.products.create_manual_section"))) {
                    FormTextField(title: L10n.tr("module.products.field_name"), text: $denumire, isRequired: true)
                    FormTextField(title: L10n.tr("module.products.field_code"), text: $cod, autocapitalization: .characters)
                    FormTextField(
                        title: L10n.tr("inventory.physical_field_barcode"),
                        text: $codBare,
                        keyboardType: .asciiCapable,
                        autocapitalization: .never
                    )
                    Button {
                        showFieldScanner = true
                    } label: {
                        Label(L10n.tr("module.products.scan_fill_barcode"), systemImage: "barcode.viewfinder")
                    }
                    ProductMeasureUnitFields(
                        stockUnit: $unitateMasura,
                        purchaseUnit: $unitateAchizitie,
                        factorText: $factorConversieText
                    )
                    Picker(L10n.tr("products.field_category"), selection: $tip) {
                        ForEach(ProductKind.articleCategories) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                }

                if let successMessage {
                    Section {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(L10n.tr("module.products.create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) { Task { await saveManual() } }
                        .disabled(isLoading || denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .sheet(isPresented: $showAutoCreateScanner) {
                BarcodeScannerSheet { code in
                    Task { await createFromBarcode(code) }
                }
            }
            .sheet(isPresented: $showFieldScanner) {
                BarcodeScannerSheet { code in
                    codBare = BarcodeMatching.normalize(code)
                }
            }
        }
    }

    private func createFromBarcode(_ code: String) async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        let isVatPayer = companyManager.currentCompany?.isVatPayer ?? true
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            showAutoCreateScanner = false
            let product = try await ProductService.createProductFromBarcode(
                companyId: companyId,
                barcode: code,
                isVatPayer: isVatPayer
            )
            await onSaved()
            onCreatedFromScan?(product)
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveManual() async {
        guard let companyId = companyManager.currentCompany?.id else { return }
        let isVatPayer = companyManager.currentCompany?.isVatPayer ?? true
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let factor = SupplierFormatting.parseAmount(
                factorConversieText,
                maxFractionDigits: SupplierFormatting.invoiceAmountInputMaxFractionDigits
            ) ?? 1
            guard factor > 0 else {
                errorMessage = L10n.tr("products.error_invalid_conversion_factor")
                return
            }
            _ = try await ProductService.createProduct(
                companyId: companyId,
                input: ProductCreateInput(
                    denumire: denumire,
                    cod: emptyToNil(cod),
                    codBare: emptyToNil(codBare),
                    unitateMasura: unitateMasura,
                    unitateAchizitie: emptyToNil(unitateAchizitie),
                    factorConversie: factor,
                    tip: tip,
                    inCatalog: tip.impliesInCatalog,
                    cotaTva: ProductService.defaultVatRate(isVatPayer: isVatPayer)
                ),
                isVatPayer: isVatPayer
            )
            await onSaved()
            isPresented = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
