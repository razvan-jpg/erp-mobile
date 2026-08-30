import SwiftUI
import UIKit

struct CompanyParametrizareView: View {
    let canEdit: Bool
    let onSaved: (Company) -> Void

    @EnvironmentObject private var companyManager: CompanyManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var denumire = ""
    @State private var cifCountryPrefix = "RO"
    @State private var cui = ""
    @State private var codCaen = ""
    @State private var nrRegCom = ""
    @State private var capitalSocial = ""
    @State private var splitTva = false
    @State private var codLei = ""
    @State private var telefon = ""
    @State private var fax = ""
    @State private var email = ""
    @State private var web = ""
    @State private var iban = ""
    @State private var platitorTva = true
    @State private var isActive = true

    @State private var hqCountry = "Romania"
    @State private var hqCounty = ""
    @State private var hqCity = ""
    @State private var hqPostalCode = ""
    @State private var hqStreet = ""
    @State private var hqStreetNumber = ""
    @State private var hqBlock = ""
    @State private var hqStair = ""
    @State private var hqApartment = ""
    @State private var hqGln = ""

    @State private var fiscalCountry = "Romania"
    @State private var fiscalCounty = ""
    @State private var fiscalCity = ""
    @State private var fiscalPostalCode = ""
    @State private var fiscalStreet = ""
    @State private var fiscalStreetNumber = ""
    @State private var fiscalBlock = ""
    @State private var fiscalStair = ""
    @State private var fiscalApartment = ""
    @State private var fiscalGln = ""
    @State private var useFiscalInDeclarations = false

    @State private var usesIntraCommunityVat = false
    @State private var intraCommunityVatCode = ""

    @State private var logoUrl: String?
    @State private var logoPreview: Image?
    @State private var showPhotoLibrary = false
#if targetEnvironment(macCatalyst)
    @State private var showLogoFilePicker = false
#endif
    @State private var companyId: UUID?
    @State private var isLoading = false
    @State private var isFetchingAnaf = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: DeviceLayout.isRegularWidth(horizontalSizeClass) ? 180 : 150), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if companyManager.canSwitchCompany {
                    CurrentCompanyPickerSection()
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                topIdentitySection
                companyDataSection
                headquartersAddressSection
                contactSection
                fiscalAddressSection
                intraCommunitySection

                if let successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                if canEdit {
                    Button {
                        Task { await save() }
                    } label: {
                        Text(L10n.tr("common.save"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyles.borderedProminent)
                    .padding()
                    .disabled(isLoading || isFetchingAnaf)
                }
            }
            .frame(maxWidth: DeviceLayout.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .appScrollBottomPadding()
        .appFullOverlay { LoadingOverlay(isLoading: isLoading) }
        .onAppear { populate(from: companyManager.currentCompany) }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            populate(from: companyManager.currentCompany)
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryPicker(isPresented: $showPhotoLibrary) { data, contentType in
                applyLogoData(data, contentType: contentType)
            }
        }
        .appLegacyAlert(
            isPresented: $showValidationAlert,
            title: L10n.tr("module.nomenclatoare.companies.validation_title"),
            message: validationMessage
        )
#if targetEnvironment(macCatalyst)
        .sheet(isPresented: $showLogoFilePicker) {
            DocumentImageFilePicker(
                isPresented: $showLogoFilePicker,
                onPick: { data, contentType in
                    applyLogoData(data, contentType: contentType)
                },
                onCancel: {}
            )
        }
#endif
    }

    private var topIdentitySection: some View {
        VStack(spacing: 0) {
            ParametrizareSectionHeader(title: L10n.tr("module.nomenclatoare.companies.section_identity"))
            VStack(spacing: 12) {
                if DeviceLayout.isRegularWidth(horizontalSizeClass) {
                    HStack(alignment: .top, spacing: 16) {
                        FormTextField(
                            title: L10n.tr("module.nomenclatoare.companies.field_name"),
                            text: $denumire,
                            isRequired: true
                        )
                        .disabled(!canEdit)

                        logoPicker
                    }
                } else {
                    FormTextField(
                        title: L10n.tr("module.nomenclatoare.companies.field_name"),
                        text: $denumire,
                        isRequired: true
                    )
                    .disabled(!canEdit)
                    logoPicker
                }
            }
            .padding(12)
        }
    }

    private var logoPicker: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .background(Color(.secondarySystemBackground))
                    .frame(width: 120, height: 120)

                if let logoPreview {
                    logoPreview
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundColor(AppColors.secondary)
                        Text(L10n.tr("module.nomenclatoare.companies.logo"))
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }

            if canEdit {
                Button {
                    showPhotoLibrary = true
                } label: {
                    Text(L10n.tr("module.nomenclatoare.companies.logo_pick"))
                        .font(.caption)
                }

#if targetEnvironment(macCatalyst)
                Button {
                    showLogoFilePicker = true
                } label: {
                    Text(L10n.tr("module.nomenclatoare.companies.logo_pick_file"))
                        .font(.caption)
                }
#endif

                if logoUrl == nil {
                    Button {
                        suggestLogo()
                    } label: {
                        Text(L10n.tr("module.nomenclatoare.companies.logo_suggest"))
                            .font(.caption)
                    }
                }

                if logoUrl != nil {
                    Button(L10n.tr("module.nomenclatoare.companies.logo_remove")) {
                        logoUrl = nil
                        logoPreview = nil
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var companyDataSection: some View {
        VStack(spacing: 0) {
            ParametrizareSectionHeader(title: L10n.tr("module.nomenclatoare.companies.section_company_data"))
            VStack(spacing: 12) {
                cifField
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_caen"), text: $codCaen)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("common.field_nr_reg_com"), text: $nrRegCom)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_capital"), text: $capitalSocial)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_cod_lei"), text: $codLei)
                        .disabled(!canEdit)
                }
                Toggle(isOn: $splitTva) {
                    Text(L10n.tr("module.nomenclatoare.companies.field_split_tva"))
                }
                .disabled(!canEdit)
            }
            .padding(12)
        }
    }

    private var cifField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("module.nomenclatoare.companies.field_cif"))
                .font(.caption)
                .foregroundColor(AppColors.secondary)
            HStack(spacing: 8) {
                TextField("RO", text: $cifCountryPrefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .autocapitalization(.allCharacters)
                    .disabled(!canEdit)

                TextField(L10n.tr("module.nomenclatoare.companies.field_cif"), text: $cui)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.allCharacters)
                    .disabled(!canEdit || isFetchingAnaf)

                if canEdit {
                    Button {
                        Task { await fetchFromAnaf() }
                    } label: {
                        if isFetchingAnaf {
                            ProgressView().appControlSize(.small).frame(width: 36)
                        } else {
                            Image(systemName: "globe")
                        }
                    }
                    .buttonStyle(AppButtonStyles.bordered)
                    .disabled(isFetchingAnaf || Validators.normalizedCUI(cui) == nil)
                }
            }
            Text(L10n.tr("company.anaf_hint"))
                .font(.caption2)
                .foregroundColor(AppColors.tertiary)
        }
    }

    private var headquartersAddressSection: some View {
        addressSection(
            title: L10n.tr("module.nomenclatoare.companies.section_hq_address"),
            country: $hqCountry,
            county: $hqCounty,
            city: $hqCity,
            postalCode: $hqPostalCode,
            street: $hqStreet,
            streetNumber: $hqStreetNumber,
            block: $hqBlock,
            stair: $hqStair,
            apartment: $hqApartment,
            gln: $hqGln
        )
    }

    private var contactSection: some View {
        VStack(spacing: 0) {
            ParametrizareSectionHeader(title: L10n.tr("module.nomenclatoare.companies.section_contact"))
            LazyVGrid(columns: gridColumns, spacing: 12) {
                FormTextField(title: L10n.tr("common.field_phone"), text: $telefon, keyboardType: .phonePad)
                    .disabled(!canEdit)
                FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_fax"), text: $fax, keyboardType: .phonePad)
                    .disabled(!canEdit)
                FormTextField(title: L10n.tr("common.field_email"), text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                    .disabled(!canEdit)
                FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_web"), text: $web, keyboardType: .URL, autocapitalization: .never)
                    .disabled(!canEdit)
            }
            .padding(12)
        }
    }

    private var fiscalAddressSection: some View {
        VStack(spacing: 0) {
            addressSection(
                title: L10n.tr("module.nomenclatoare.companies.section_fiscal_address"),
                country: $fiscalCountry,
                county: $fiscalCounty,
                city: $fiscalCity,
                postalCode: $fiscalPostalCode,
                street: $fiscalStreet,
                streetNumber: $fiscalStreetNumber,
                block: $fiscalBlock,
                stair: $fiscalStair,
                apartment: $fiscalApartment,
                gln: $fiscalGln
            )
            Toggle(isOn: $useFiscalInDeclarations) {
                Text(L10n.tr("module.nomenclatoare.companies.field_use_fiscal_in_declarations"))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .disabled(!canEdit)
        }
    }

    private var intraCommunitySection: some View {
        VStack(spacing: 0) {
            ParametrizareSectionHeader(title: L10n.tr("module.nomenclatoare.companies.section_intra_community"))
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $usesIntraCommunityVat) {
                    Text(L10n.tr("module.nomenclatoare.companies.field_use_intra_vat"))
                }
                .disabled(!canEdit)
                FormTextField(
                    title: L10n.tr("module.nomenclatoare.companies.field_intra_vat_code"),
                    text: $intraCommunityVatCode,
                    autocapitalization: .characters
                )
                .disabled(!canEdit || !usesIntraCommunityVat)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func addressSection(
        title: String,
        country: Binding<String>,
        county: Binding<String>,
        city: Binding<String>,
        postalCode: Binding<String>,
        street: Binding<String>,
        streetNumber: Binding<String>,
        block: Binding<String>,
        stair: Binding<String>,
        apartment: Binding<String>,
        gln: Binding<String>
    ) -> some View {
        VStack(spacing: 0) {
            ParametrizareSectionHeader(title: title)
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_country"), text: country)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_county"), text: county)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_city"), text: city)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_postal_code"), text: postalCode)
                        .disabled(!canEdit)
                }
                FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_street"), text: street)
                    .disabled(!canEdit)
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_street_number"), text: streetNumber)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_block"), text: block)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_stair"), text: stair)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_apartment"), text: apartment)
                        .disabled(!canEdit)
                    FormTextField(title: L10n.tr("module.nomenclatoare.companies.field_gln"), text: gln)
                        .disabled(!canEdit)
                }
            }
            .padding(12)
        }
    }

    private func populate(from company: Company?) {
        guard let company else {
            companyId = nil
            return
        }
        companyId = company.id
        denumire = company.denumire
        cifCountryPrefix = company.cifCountryPrefix
        cui = company.cui ?? ""
        codCaen = company.codCaen ?? ""
        nrRegCom = company.nrRegCom ?? ""
        capitalSocial = company.capitalSocial ?? ""
        splitTva = company.splitTva
        codLei = company.codLei ?? ""
        telefon = company.telefon ?? ""
        fax = company.fax ?? ""
        email = company.email ?? ""
        web = company.web ?? ""
        iban = company.iban ?? ""
        platitorTva = company.platitorTva
        isActive = company.isActive
        hqCountry = company.hqCountry ?? "Romania"
        hqCounty = company.hqCounty ?? ""
        hqCity = company.hqCity ?? ""
        hqPostalCode = company.hqPostalCode ?? ""
        hqStreet = company.hqStreet ?? ""
        hqStreetNumber = company.hqStreetNumber ?? ""
        hqBlock = company.hqBlock ?? ""
        hqStair = company.hqStair ?? ""
        hqApartment = company.hqApartment ?? ""
        hqGln = company.hqGln ?? ""
        fiscalCountry = company.fiscalCountry ?? company.hqCountry ?? "Romania"
        fiscalCounty = company.fiscalCounty ?? ""
        fiscalCity = company.fiscalCity ?? ""
        fiscalPostalCode = company.fiscalPostalCode ?? ""
        fiscalStreet = company.fiscalStreet ?? ""
        fiscalStreetNumber = company.fiscalStreetNumber ?? ""
        fiscalBlock = company.fiscalBlock ?? ""
        fiscalStair = company.fiscalStair ?? ""
        fiscalApartment = company.fiscalApartment ?? ""
        fiscalGln = company.fiscalGln ?? ""
        useFiscalInDeclarations = company.useFiscalInDeclarations
        usesIntraCommunityVat = company.usesIntraCommunityVat
        intraCommunityVatCode = company.intraCommunityVatCode ?? ""
        logoUrl = company.logoUrl
        logoPreview = CompanyLogoStorage.previewImage(fromStoredValue: company.logoUrl)
        errorMessage = nil
        successMessage = nil
    }

    private func buildCompanyForSave() -> Company? {
        guard let companyId else { return nil }
        return Company(
            id: companyId,
            denumire: denumire.trimmingCharacters(in: .whitespacesAndNewlines),
            cui: emptyToNil(cui),
            nrRegCom: emptyToNil(nrRegCom),
            adresa: formattedLegacyAddress(),
            iban: emptyToNil(iban),
            email: emptyToNil(email),
            telefon: emptyToNil(telefon),
            isActive: isActive,
            platitorTva: platitorTva,
            cifCountryPrefix: emptyToNil(cifCountryPrefix) ?? "RO",
            codCaen: emptyToNil(codCaen),
            capitalSocial: emptyToNil(capitalSocial),
            splitTva: splitTva,
            codLei: emptyToNil(codLei),
            fax: emptyToNil(fax),
            web: emptyToNil(web),
            logoUrl: logoUrl.flatMap { emptyToNil($0) },
            hqCountry: emptyToNil(hqCountry),
            hqCounty: emptyToNil(hqCounty),
            hqCity: emptyToNil(hqCity),
            hqPostalCode: emptyToNil(hqPostalCode),
            hqStreet: emptyToNil(hqStreet),
            hqStreetNumber: emptyToNil(hqStreetNumber),
            hqBlock: emptyToNil(hqBlock),
            hqStair: emptyToNil(hqStair),
            hqApartment: emptyToNil(hqApartment),
            hqGln: emptyToNil(hqGln),
            fiscalCountry: emptyToNil(fiscalCountry),
            fiscalCounty: emptyToNil(fiscalCounty),
            fiscalCity: emptyToNil(fiscalCity),
            fiscalPostalCode: emptyToNil(fiscalPostalCode),
            fiscalStreet: emptyToNil(fiscalStreet),
            fiscalStreetNumber: emptyToNil(fiscalStreetNumber),
            fiscalBlock: emptyToNil(fiscalBlock),
            fiscalStair: emptyToNil(fiscalStair),
            fiscalApartment: emptyToNil(fiscalApartment),
            fiscalGln: emptyToNil(fiscalGln),
            useFiscalInDeclarations: useFiscalInDeclarations,
            usesIntraCommunityVat: usesIntraCommunityVat,
            intraCommunityVatCode: emptyToNil(intraCommunityVatCode),
            adminUserId: companyManager.currentCompany?.adminUserId,
            createdAt: companyManager.currentCompany?.createdAt,
            updatedAt: companyManager.currentCompany?.updatedAt
        )
    }

    private func formattedLegacyAddress() -> String? {
        var parts: [String] = []
        if !hqStreet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Str. \(hqStreet.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !hqStreetNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("nr. \(hqStreetNumber.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !hqCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(hqCity.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !hqCounty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Jud. \(hqCounty.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if !hqPostalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(hqPostalCode.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let built = parts.joined(separator: ", ")
        return built.isEmpty ? companyManager.currentCompany?.adresa : built
    }

    private func validate() -> Bool {
        if denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationMessage = L10n.tr("module.nomenclatoare.companies.validation_name")
            showValidationAlert = true
            return false
        }
        return true
    }

    private func save() async {
        guard validate(), let company = buildCompanyForSave() else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        do {
            let updated = try await CompanyService.updateCompanyParametrizare(company)
            onSaved(updated)
            populate(from: updated)
            successMessage = L10n.tr("module.nomenclatoare.companies.save_success")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchFromAnaf() async {
        isFetchingAnaf = true
        errorMessage = nil
        do {
            let data = try await AnafService.fetchCompany(cui: cui)
            guard data.hasAnyData else { throw AnafServiceError.notFound }
            applyAnafData(data)
            successMessage = L10n.tr("suppliers.anaf_success")
        } catch {
            errorMessage = error.localizedDescription
        }
        isFetchingAnaf = false
    }

    private func applyAnafData(_ data: AnafCompanyLookup) {
        cui = data.cui
        denumire = data.denumire
        if let nrRegCom = data.nrRegCom { self.nrRegCom = nrRegCom }
        if let telefon = data.telefon { self.telefon = telefon }
        if let iban = data.iban { self.iban = iban }
        if let platitorTva = data.platitorTva { self.platitorTva = platitorTva }
        if let codCaen = data.codCaen { self.codCaen = codCaen }
        if let county = data.hqCounty { hqCounty = county; fiscalCounty = county }
        if let city = data.hqCity { hqCity = city; fiscalCity = city }
        if let postalCode = data.hqPostalCode { hqPostalCode = postalCode; fiscalPostalCode = postalCode }
        if let street = data.hqStreet { hqStreet = street; fiscalStreet = street }
        if let streetNumber = data.hqStreetNumber { hqStreetNumber = streetNumber; fiscalStreetNumber = streetNumber }
        if let adresa = data.adresa, hqStreet.isEmpty { hqStreet = adresa }
    }

    @MainActor
    private func applyLogoData(_ data: Data, contentType: String) {
        logoPreview = CompanyLogoStorage.previewImage(from: data)
        guard let stored = CompanyLogoStorage.dataURL(from: data, contentType: contentType) else {
            logoPreview = nil
            errorMessage = L10n.tr("module.nomenclatoare.companies.logo_error_size")
            return
        }
        applyStoredLogo(stored)
    }

    @MainActor
    private func applyStoredLogo(_ stored: String) {
        logoUrl = stored
        if logoPreview == nil {
            logoPreview = CompanyLogoStorage.previewImage(fromStoredValue: stored)
        }
        errorMessage = nil
        successMessage = nil
    }

    @MainActor
    private func suggestLogo() {
        let name = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            validationMessage = L10n.tr("module.nomenclatoare.companies.logo_suggest_needs_name")
            showValidationAlert = true
            return
        }
        guard let stored = CompanyLogoStorage.suggestedLogo(from: name) else {
            errorMessage = L10n.tr("module.nomenclatoare.companies.logo_error_generate")
            return
        }
        applyStoredLogo(stored)
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ParametrizareSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
    }
}

private extension Company {
    init(
        id: UUID,
        denumire: String,
        cui: String?,
        nrRegCom: String?,
        adresa: String?,
        iban: String?,
        email: String?,
        telefon: String?,
        isActive: Bool,
        platitorTva: Bool,
        cifCountryPrefix: String,
        codCaen: String?,
        capitalSocial: String?,
        splitTva: Bool,
        codLei: String?,
        fax: String?,
        web: String?,
        logoUrl: String?,
        hqCountry: String?,
        hqCounty: String?,
        hqCity: String?,
        hqPostalCode: String?,
        hqStreet: String?,
        hqStreetNumber: String?,
        hqBlock: String?,
        hqStair: String?,
        hqApartment: String?,
        hqGln: String?,
        fiscalCountry: String?,
        fiscalCounty: String?,
        fiscalCity: String?,
        fiscalPostalCode: String?,
        fiscalStreet: String?,
        fiscalStreetNumber: String?,
        fiscalBlock: String?,
        fiscalStair: String?,
        fiscalApartment: String?,
        fiscalGln: String?,
        useFiscalInDeclarations: Bool,
        usesIntraCommunityVat: Bool,
        intraCommunityVatCode: String?,
        adminUserId: UUID?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.denumire = denumire
        self.cui = cui
        self.nrRegCom = nrRegCom
        self.adresa = adresa
        self.iban = iban
        self.email = email
        self.telefon = telefon
        self.isActive = isActive
        self.platitorTva = platitorTva
        self.cifCountryPrefix = cifCountryPrefix
        self.codCaen = codCaen
        self.capitalSocial = capitalSocial
        self.splitTva = splitTva
        self.codLei = codLei
        self.fax = fax
        self.web = web
        self.logoUrl = logoUrl
        self.hqCountry = hqCountry
        self.hqCounty = hqCounty
        self.hqCity = hqCity
        self.hqPostalCode = hqPostalCode
        self.hqStreet = hqStreet
        self.hqStreetNumber = hqStreetNumber
        self.hqBlock = hqBlock
        self.hqStair = hqStair
        self.hqApartment = hqApartment
        self.hqGln = hqGln
        self.fiscalCountry = fiscalCountry
        self.fiscalCounty = fiscalCounty
        self.fiscalCity = fiscalCity
        self.fiscalPostalCode = fiscalPostalCode
        self.fiscalStreet = fiscalStreet
        self.fiscalStreetNumber = fiscalStreetNumber
        self.fiscalBlock = fiscalBlock
        self.fiscalStair = fiscalStair
        self.fiscalApartment = fiscalApartment
        self.fiscalGln = fiscalGln
        self.useFiscalInDeclarations = useFiscalInDeclarations
        self.usesIntraCommunityVat = usesIntraCommunityVat
        self.intraCommunityVatCode = intraCommunityVatCode
        self.adminUserId = adminUserId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
