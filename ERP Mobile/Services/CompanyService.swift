import Foundation
import Supabase

private struct CompanyInsert: Encodable {
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let isActive: Bool
    let platitorTva: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, cui, adresa, iban, email, telefon
        case nrRegCom = "nr_reg_com"
        case isActive = "is_active"
        case platitorTva = "platitor_tva"
    }
}

private struct CompanyUpdate: Encodable {
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let isActive: Bool
    let platitorTva: Bool
    let cifCountryPrefix: String
    let codCaen: String?
    let capitalSocial: String?
    let splitTva: Bool
    let codLei: String?
    let fax: String?
    let web: String?
    let logoUrl: String?
    let hqCountry: String?
    let hqCounty: String?
    let hqCity: String?
    let hqPostalCode: String?
    let hqStreet: String?
    let hqStreetNumber: String?
    let hqBlock: String?
    let hqStair: String?
    let hqApartment: String?
    let hqGln: String?
    let fiscalCountry: String?
    let fiscalCounty: String?
    let fiscalCity: String?
    let fiscalPostalCode: String?
    let fiscalStreet: String?
    let fiscalStreetNumber: String?
    let fiscalBlock: String?
    let fiscalStair: String?
    let fiscalApartment: String?
    let fiscalGln: String?
    let useFiscalInDeclarations: Bool
    let usesIntraCommunityVat: Bool
    let intraCommunityVatCode: String?

    enum CodingKeys: String, CodingKey {
        case denumire, cui, adresa, iban, email, telefon, fax, web
        case nrRegCom = "nr_reg_com"
        case isActive = "is_active"
        case platitorTva = "platitor_tva"
        case cifCountryPrefix = "cif_country_prefix"
        case codCaen = "cod_caen"
        case capitalSocial = "capital_social"
        case splitTva = "split_tva"
        case codLei = "cod_lei"
        case logoUrl = "logo_url"
        case hqCountry = "hq_country"
        case hqCounty = "hq_county"
        case hqCity = "hq_city"
        case hqPostalCode = "hq_postal_code"
        case hqStreet = "hq_street"
        case hqStreetNumber = "hq_street_number"
        case hqBlock = "hq_block"
        case hqStair = "hq_stair"
        case hqApartment = "hq_apartment"
        case hqGln = "hq_gln"
        case fiscalCountry = "fiscal_country"
        case fiscalCounty = "fiscal_county"
        case fiscalCity = "fiscal_city"
        case fiscalPostalCode = "fiscal_postal_code"
        case fiscalStreet = "fiscal_street"
        case fiscalStreetNumber = "fiscal_street_number"
        case fiscalBlock = "fiscal_block"
        case fiscalStair = "fiscal_stair"
        case fiscalApartment = "fiscal_apartment"
        case fiscalGln = "fiscal_gln"
        case useFiscalInDeclarations = "use_fiscal_in_declarations"
        case usesIntraCommunityVat = "uses_intra_community_vat"
        case intraCommunityVatCode = "intra_community_vat_code"
    }

    init(from company: Company) {
        denumire = company.denumire
        cui = company.cui
        nrRegCom = company.nrRegCom
        adresa = company.adresa
        iban = company.iban
        email = company.email
        telefon = company.telefon
        isActive = company.isActive
        platitorTva = company.platitorTva
        cifCountryPrefix = company.cifCountryPrefix
        codCaen = company.codCaen
        capitalSocial = company.capitalSocial
        splitTva = company.splitTva
        codLei = company.codLei
        fax = company.fax
        web = company.web
        logoUrl = company.logoUrl
        hqCountry = company.hqCountry
        hqCounty = company.hqCounty
        hqCity = company.hqCity
        hqPostalCode = company.hqPostalCode
        hqStreet = company.hqStreet
        hqStreetNumber = company.hqStreetNumber
        hqBlock = company.hqBlock
        hqStair = company.hqStair
        hqApartment = company.hqApartment
        hqGln = company.hqGln
        fiscalCountry = company.fiscalCountry
        fiscalCounty = company.fiscalCounty
        fiscalCity = company.fiscalCity
        fiscalPostalCode = company.fiscalPostalCode
        fiscalStreet = company.fiscalStreet
        fiscalStreetNumber = company.fiscalStreetNumber
        fiscalBlock = company.fiscalBlock
        fiscalStair = company.fiscalStair
        fiscalApartment = company.fiscalApartment
        fiscalGln = company.fiscalGln
        useFiscalInDeclarations = company.useFiscalInDeclarations
        usesIntraCommunityVat = company.usesIntraCommunityVat
        intraCommunityVatCode = company.intraCommunityVatCode
    }
}

private struct SelectedCompanyUpdate: Encodable {
    let selectedCompanyId: UUID?

    enum CodingKeys: String, CodingKey {
        case selectedCompanyId = "selected_company_id"
    }
}

struct CreateCompanyAdminInput: Encodable, Sendable {
    let nume: String
    let prenume: String
    let email: String
    let parola: String
    let cnp: String
    let telefon: String

    enum CodingKeys: String, CodingKey {
        case nume, prenume, email, parola, cnp, telefon
    }
}

struct CreateCompanyPayload: Encodable, Sendable {
    let denumire: String
    let cui: String?
    let nrRegCom: String?
    let adresa: String?
    let iban: String?
    let email: String?
    let telefon: String?
    let isActive: Bool
    let platitorTva: Bool

    enum CodingKeys: String, CodingKey {
        case denumire, cui, adresa, iban, email, telefon
        case nrRegCom = "nr_reg_com"
        case isActive = "is_active"
        case platitorTva = "platitor_tva"
    }
}

struct CreateCompanyWithAdminRequest: Encodable, Sendable {
    let company: CreateCompanyPayload
    let companyAdmin: CreateCompanyAdminInput

    enum CodingKeys: String, CodingKey {
        case company
        case companyAdmin = "company_admin"
    }
}

struct CreateCompanyWithAdminResult: Sendable {
    let company: Company
    let existingAdminLinked: Bool
    let emailVerificationRequired: Bool
}

private nonisolated struct CreateCompanyResponse: Decodable, Sendable {
    let company: Company?
    let error: String?
    let existingAdminLinked: Bool?
    let emailVerificationRequired: Bool?

    enum CodingKeys: String, CodingKey {
        case company, error
        case existingAdminLinked = "existing_admin_linked"
        case emailVerificationRequired = "email_verification_required"
    }
}

private nonisolated struct ErrorResponse: Decodable, Sendable {
    let error: String?
}

enum CompanyService {
    private static let client = SupabaseManager.client
    private static let responseDecoder = SupabaseDecoding.jsonDecoder

    static func fetchCompanies() async throws -> [Company] {
        try await client
            .from("companies")
            .select()
            .order("denumire", ascending: true)
            .execute()
            .value
    }

    static func fetchCompany(id: UUID) async throws -> Company {
        let rows: [Company] = try await client
            .from("companies")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let company = rows.first else { throw ServiceError.invalidResponse }
        return company
    }

    static func createCompanyWithAdmin(_ request: CreateCompanyWithAdminRequest) async throws -> CreateCompanyWithAdminResult {
        let response: CreateCompanyResponse
        do {
            response = try await client.functions.invoke(
                "admin-create-company",
                options: FunctionInvokeOptions(body: request),
                decoder: responseDecoder
            )
        } catch let error as FunctionsError {
            throw ServiceError.server(parseFunctionsError(error))
        }
        if let error = response.error { throw ServiceError.server(error) }
        guard let company = response.company else { throw ServiceError.invalidResponse }
        return CreateCompanyWithAdminResult(
            company: company,
            existingAdminLinked: response.existingAdminLinked ?? false,
            emailVerificationRequired: response.emailVerificationRequired ?? true
        )
    }

    static func updateCompany(
        id: UUID,
        denumire: String,
        cui: String?,
        nrRegCom: String?,
        adresa: String?,
        iban: String?,
        email: String?,
        telefon: String?,
        isActive: Bool,
        platitorTva: Bool
    ) async throws -> Company {
        var existing = try await fetchCompany(id: id)
        existing.denumire = denumire
        existing.cui = emptyToNil(cui)
        existing.nrRegCom = emptyToNil(nrRegCom)
        existing.adresa = emptyToNil(adresa)
        existing.iban = emptyToNil(iban)
        existing.email = emptyToNil(email)
        existing.telefon = emptyToNil(telefon)
        existing.isActive = isActive
        existing.platitorTva = platitorTva
        return try await updateCompanyParametrizare(existing)
    }

    static func updateCompanyParametrizare(_ company: Company) async throws -> Company {
        let payload = CompanyUpdate(from: company)
        let rows: [Company] = try await client
            .from("companies")
            .update(payload)
            .eq("id", value: company.id.uuidString)
            .select()
            .execute()
            .value
        guard let updated = rows.first else { throw ServiceError.invalidResponse }
        return updated
    }

    static func setSelectedCompany(id: UUID?) async throws {
        guard let userId = await AuthService.currentUserId() else {
            throw ServiceError.invalidResponse
        }
        let payload = SelectedCompanyUpdate(selectedCompanyId: id)
        try await client
            .from("user_profiles")
            .update(payload)
            .eq("id", value: userId.uuidString)
            .execute()
    }

    static func fetchUserCompanyPermissions(userId: UUID) async throws -> [CompanyPermission] {
        try await client
            .from("user_company_permissions")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
    }

    static func fetchAllCompanyPermissions() async throws -> [CompanyPermission] {
        try await client
            .from("user_company_permissions")
            .select()
            .execute()
            .value
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseFunctionsError(_ error: FunctionsError) -> String {
        switch error {
        case .relayError:
            return "Eroare de rețea la crearea societății."
        case .httpError(_, let data):
            if let payload = try? responseDecoder.decode(ErrorResponse.self, from: data),
               let message = payload.error, !message.isEmpty {
                return message
            }
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                return raw
            }
            return "Eroare server la crearea societății."
        }
    }
}
