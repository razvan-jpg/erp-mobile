import SwiftUI
import UIKit

private enum AdminNameField: Hashable {
    case nume, prenume
}

enum CompanyFormMode: Identifiable {
    case create
    case edit(Company)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let company): return company.id.uuidString
        }
    }

    var title: String {
        switch self {
        case .create: return "Societate nouă"
        case .edit: return "Editare societate"
        }
    }
}

struct CompanyFormView: View {
    let mode: CompanyFormMode
    let onSaved: (Company) async -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var denumire = ""
    @State private var cui = ""
    @State private var nrRegCom = ""
    @State private var adresa = ""
    @State private var iban = ""
    @State private var email = ""
    @State private var telefon = ""
    @State private var isActive = true
    @State private var platitorTva = true
    @State private var originalPlatitorTva = true
    @State private var updateProductsVatOnSave = false
    @State private var showVatStatusChangeDialog = false
    @State private var pendingPlatitorTva: Bool?
    @State private var adminNume = ""
    @State private var adminPrenume = ""
    @State private var adminEmail = ""
    @State private var adminParola = ""
    @State private var adminTelefon = ""
    @State private var isLoading = false
    @State private var isFetchingAnaf = false
    @State private var errorMessage: String?
    @State private var anafSuccessMessage: String?
    @State private var showValidationAlert = false
    @State private var validationAlertMessage = ""
    @State private var showSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var pendingSavedCompany: Company?

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    var body: some View {
        NavigationView {
            AdaptiveFormContainer {
                Form {
                    Section {
                        Text(isCreate
                             ? "Completați datele societății și ale administratorului societății. Administratorul va putea gestiona doar această societate."
                             : "Modificați datele societății. Administratorul societății se gestionează din secțiunea Utilizatori.")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }

                    Section(header: Text("Date societate")) {
                        FormTextField(title: "Denumire", text: $denumire, isRequired: true)
                        cuiFieldWithAnafButton
                        FormTextField(title: "Nr. Reg. Com.", text: $nrRegCom)
                        FormTextField(title: "Adresă", text: $adresa, axis: .vertical)
                        FormTextField(title: "IBAN", text: $iban, autocapitalization: .characters)
                        FormTextField(title: "Email societate", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                        FormTextField(title: "Telefon societate", text: $telefon, keyboardType: .phonePad)
                        Toggle(L10n.tr("companies.field_vat_payer"), isOn: platitorTvaToggle)
                        Text(L10n.tr("companies.field_vat_payer_hint"))
                            .font(.caption2)
                            .foregroundColor(AppColors.tertiary)
                        Toggle("Activă", isOn: $isActive)
                    }

                    if isCreate {
                        Section(header: Text("Administrator societate")) {
                            FormTextField(title: "Nume", text: $adminNume, isRequired: true)
                            FormTextField(title: "Prenume", text: $adminPrenume, isRequired: true)
                            FormTextField(
                                title: "Email",
                                text: $adminEmail,
                                isRequired: true,
                                keyboardType: .emailAddress,
                                autocapitalization: .never
                            )
                            FormTextField(title: "Telefon", text: $adminTelefon, keyboardType: .phonePad)
                            FormTextField(title: "Parolă", text: $adminParola, isSecure: true)
                            Text("Parola este obligatorie doar pentru utilizatori noi. Dacă emailul există deja în sistem, administratorul este alocat automat fără confirmare email.")
                                .font(.caption2)
                                .foregroundColor(AppColors.tertiary)
                        }
                    }

                    if let anafSuccessMessage {
                        Section {
                            Text(anafSuccessMessage)
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anulează") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvează") { Task { await save() } }
                        .disabled(isLoading || isFetchingAnaf)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gata") {
                        dismissKeyboard()
                    }
                }
            }
            .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
            .onAppear { populateFields() }
            .onChange(of: cui) { _ in
                anafSuccessMessage = nil
            }
            .onChange(of: adminNume) { newValue in
                applyNameFormat(newValue, to: .nume)
            }
            .onChange(of: adminPrenume) { newValue in
                applyNameFormat(newValue, to: .prenume)
            }
            .alert("Verificați formularul", isPresented: $showValidationAlert) {
                Button("OK") {}
            } message: {
                Text(validationAlertMessage)
            }
            .alert("Societate salvată", isPresented: $showSuccessAlert) {
                Button("OK") {
                    guard let pendingSavedCompany else { return }
                    Task {
                        await onSaved(pendingSavedCompany)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } message: {
                Text(successAlertMessage)
            }
            .confirmationDialog(
                L10n.tr("companies.vat_status_change_title"),
                isPresented: $showVatStatusChangeDialog,
                titleVisibility: .visible
            ) {
                Button(L10n.tr("companies.vat_status_change_update_articles")) {
                    applyPendingVatStatus(updateArticles: true)
                }
                Button(L10n.tr("companies.vat_status_change_company_only")) {
                    applyPendingVatStatus(updateArticles: false)
                }
                Button(L10n.tr("common.cancel")) {
                    pendingPlatitorTva = nil
                }
            } message: {
                Text(vatStatusChangeMessage)
            }
        }
    }

    private var platitorTvaToggle: Binding<Bool> {
        Binding(
            get: { platitorTva },
            set: { newValue in
                if isCreate {
                    platitorTva = newValue
                    return
                }
                guard newValue != platitorTva else { return }
                pendingPlatitorTva = newValue
                showVatStatusChangeDialog = true
            }
        )
    }

    private var vatStatusChangeMessage: String {
        guard let pending = pendingPlatitorTva else { return "" }
        return pending
            ? L10n.tr("companies.vat_status_become_payer_message")
            : L10n.tr("companies.vat_status_become_non_payer_message")
    }

    private func applyPendingVatStatus(updateArticles: Bool) {
        guard let pending = pendingPlatitorTva else { return }
        platitorTva = pending
        pendingPlatitorTva = nil
        if platitorTva == originalPlatitorTva {
            updateProductsVatOnSave = false
        } else {
            updateProductsVatOnSave = updateArticles
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func applyNameFormat(_ value: String, to field: AdminNameField) {
        let formatted = NameFormatter.formatName(value)
        switch field {
        case .nume:
            if adminNume != formatted { adminNume = formatted }
        case .prenume:
            if adminPrenume != formatted { adminPrenume = formatted }
        }
    }

    private func validateForm() -> Bool {
        var messages: [String] = []

        if denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Denumire societate")
        }

        if isCreate {
            if adminNume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append("Nume administrator")
            }
            if adminPrenume.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append("Prenume administrator")
            }
            if adminEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append("Email administrator")
            }
        }

        guard messages.isEmpty else {
            validationAlertMessage = "Completați câmpurile obligatorii: \(messages.joined(separator: ", "))."
            showValidationAlert = true
            return false
        }

        return true
    }

    private var cuiFieldWithAnafButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CUI *")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            HStack(alignment: .center, spacing: 8) {
                TextField("CUI", text: $cui)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .keyboardType(.numbersAndPunctuation)
                    .disabled(isFetchingAnaf)

                Button {
                    Task { await fetchFromAnaf() }
                } label: {
                    if isFetchingAnaf {
                        ProgressView()
                            .appControlSize(.small)
                            .frame(width: 44)
                    } else {
                        Label("ANAF", systemImage: "building.columns")
                            .appLabelStyleTitleAndIcon()
                    }
                }
                .buttonStyle(AppButtonStyles.bordered)
                .appControlSize(.small)
                .disabled(isFetchingAnaf || Validators.normalizedCUI(cui) == nil)
            }
        }
    }

    private func fetchFromAnaf() async {
        isFetchingAnaf = true
        errorMessage = nil
        anafSuccessMessage = nil
        do {
            let data = try await AnafService.fetchCompany(cui: cui)
            guard data.hasAnyData else {
                throw AnafServiceError.notFound
            }
            applyAnafData(data)
            anafSuccessMessage = "Date preluate de la ANAF. Verificați și modificați dacă este necesar, apoi salvați."
        } catch {
            errorMessage = error.localizedDescription
        }
        isFetchingAnaf = false
    }

    private func applyAnafData(_ data: AnafCompanyLookup) {
        cui = data.cui
        denumire = data.denumire
        if let nrRegCom = data.nrRegCom { self.nrRegCom = nrRegCom }
        if let adresa = data.adresa { self.adresa = adresa }
        if let telefon = data.telefon { self.telefon = telefon }
        if let iban = data.iban { self.iban = iban }
        if let platitorTva = data.platitorTva { self.platitorTva = platitorTva }
    }

    private func populateFields() {
        guard case .edit(let company) = mode else { return }
        denumire = company.denumire
        cui = company.cui ?? ""
        nrRegCom = company.nrRegCom ?? ""
        adresa = company.adresa ?? ""
        iban = company.iban ?? ""
        email = company.email ?? ""
        telefon = company.telefon ?? ""
        isActive = company.isActive
        platitorTva = company.platitorTva
        originalPlatitorTva = company.platitorTva
        updateProductsVatOnSave = false
    }

    private func save() async {
        guard validateForm() else { return }

        isLoading = true
        errorMessage = nil
        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedAdminNume = NameFormatter.formatName(adminNume.trimmingCharacters(in: .whitespacesAndNewlines))
        let formattedAdminPrenume = NameFormatter.formatName(adminPrenume.trimmingCharacters(in: .whitespacesAndNewlines))
        do {
            let company: Company
            switch mode {
            case .create:
                let createResult = try await CompanyService.createCompanyWithAdmin(
                    CreateCompanyWithAdminRequest(
                        company: CreateCompanyPayload(
                            denumire: trimmedName,
                            cui: emptyToNil(cui),
                            nrRegCom: emptyToNil(nrRegCom),
                            adresa: emptyToNil(adresa),
                            iban: emptyToNil(iban),
                            email: emptyToNil(email),
                            telefon: emptyToNil(telefon),
                            isActive: isActive,
                            platitorTva: platitorTva
                        ),
                        companyAdmin: CreateCompanyAdminInput(
                            nume: formattedAdminNume,
                            prenume: formattedAdminPrenume,
                            email: adminEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            parola: adminParola,
                            cnp: Validators.gdprCNPPlaceholder,
                            telefon: adminTelefon.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                )
                company = createResult.company
                pendingSavedCompany = company
                if createResult.existingAdminLinked {
                    successAlertMessage = """
                    Societatea \(company.denumire) a fost creată.
                    Administratorul existent \(formattedAdminPrenume) \(formattedAdminNume) a fost alocat automat pe societate, fără confirmare email.
                    """
                } else {
                    successAlertMessage = """
                    Societatea \(company.denumire) a fost creată.
                    Administratorul \(formattedAdminPrenume) \(formattedAdminNume) va primi email de confirmare.
                    """
                }
                showSuccessAlert = true
                isLoading = false
                return
            case .edit(let existing):
                let vatStatusChanged = platitorTva != originalPlatitorTva
                company = try await CompanyService.updateCompany(
                    id: existing.id,
                    denumire: trimmedName,
                    cui: cui,
                    nrRegCom: nrRegCom,
                    adresa: adresa,
                    iban: iban,
                    email: email,
                    telefon: telefon,
                    isActive: isActive,
                    platitorTva: platitorTva
                )
                if vatStatusChanged && updateProductsVatOnSave {
                    let bulkRate = platitorTva
                        ? ProductVATRates.defaultPayerRate
                        : ProductVATRates.nonPayerRate
                    try await ProductService.setAllProductsVatRate(
                        companyId: company.id,
                        cotaTva: bulkRate
                    )
                }
            }
            await onSaved(company)
            presentationMode.wrappedValue.dismiss()
        } catch {
            errorMessage = error.localizedDescription
            validationAlertMessage = error.localizedDescription
            showValidationAlert = true
        }
        isLoading = false
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
