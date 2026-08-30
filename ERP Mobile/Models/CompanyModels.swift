import Foundation

struct Company: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var denumire: String
    var cui: String?
    var nrRegCom: String?
    var adresa: String?
    var iban: String?
    var email: String?
    var telefon: String?
    var isActive: Bool
    var platitorTva: Bool
    var cifCountryPrefix: String
    var codCaen: String?
    var capitalSocial: String?
    var splitTva: Bool
    var codLei: String?
    var fax: String?
    var web: String?
    var logoUrl: String?
    var hqCountry: String?
    var hqCounty: String?
    var hqCity: String?
    var hqPostalCode: String?
    var hqStreet: String?
    var hqStreetNumber: String?
    var hqBlock: String?
    var hqStair: String?
    var hqApartment: String?
    var hqGln: String?
    var fiscalCountry: String?
    var fiscalCounty: String?
    var fiscalCity: String?
    var fiscalPostalCode: String?
    var fiscalStreet: String?
    var fiscalStreetNumber: String?
    var fiscalBlock: String?
    var fiscalStair: String?
    var fiscalApartment: String?
    var fiscalGln: String?
    var useFiscalInDeclarations: Bool
    var usesIntraCommunityVat: Bool
    var intraCommunityVatCode: String?
    let adminUserId: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire, cui, adresa, iban, email, telefon, fax, web
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
        case adminUserId = "admin_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        denumire = try container.decode(String.self, forKey: .denumire)
        cui = try container.decodeIfPresent(String.self, forKey: .cui)
        nrRegCom = try container.decodeIfPresent(String.self, forKey: .nrRegCom)
        adresa = try container.decodeIfPresent(String.self, forKey: .adresa)
        iban = try container.decodeIfPresent(String.self, forKey: .iban)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        telefon = try container.decodeIfPresent(String.self, forKey: .telefon)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        platitorTva = try container.decodeIfPresent(Bool.self, forKey: .platitorTva) ?? true
        cifCountryPrefix = try container.decodeIfPresent(String.self, forKey: .cifCountryPrefix) ?? "RO"
        codCaen = try container.decodeIfPresent(String.self, forKey: .codCaen)
        capitalSocial = try container.decodeIfPresent(String.self, forKey: .capitalSocial)
        splitTva = try container.decodeIfPresent(Bool.self, forKey: .splitTva) ?? false
        codLei = try container.decodeIfPresent(String.self, forKey: .codLei)
        fax = try container.decodeIfPresent(String.self, forKey: .fax)
        web = try container.decodeIfPresent(String.self, forKey: .web)
        logoUrl = try container.decodeIfPresent(String.self, forKey: .logoUrl)
        hqCountry = try container.decodeIfPresent(String.self, forKey: .hqCountry)
        hqCounty = try container.decodeIfPresent(String.self, forKey: .hqCounty)
        hqCity = try container.decodeIfPresent(String.self, forKey: .hqCity)
        hqPostalCode = try container.decodeIfPresent(String.self, forKey: .hqPostalCode)
        hqStreet = try container.decodeIfPresent(String.self, forKey: .hqStreet)
        hqStreetNumber = try container.decodeIfPresent(String.self, forKey: .hqStreetNumber)
        hqBlock = try container.decodeIfPresent(String.self, forKey: .hqBlock)
        hqStair = try container.decodeIfPresent(String.self, forKey: .hqStair)
        hqApartment = try container.decodeIfPresent(String.self, forKey: .hqApartment)
        hqGln = try container.decodeIfPresent(String.self, forKey: .hqGln)
        fiscalCountry = try container.decodeIfPresent(String.self, forKey: .fiscalCountry)
        fiscalCounty = try container.decodeIfPresent(String.self, forKey: .fiscalCounty)
        fiscalCity = try container.decodeIfPresent(String.self, forKey: .fiscalCity)
        fiscalPostalCode = try container.decodeIfPresent(String.self, forKey: .fiscalPostalCode)
        fiscalStreet = try container.decodeIfPresent(String.self, forKey: .fiscalStreet)
        fiscalStreetNumber = try container.decodeIfPresent(String.self, forKey: .fiscalStreetNumber)
        fiscalBlock = try container.decodeIfPresent(String.self, forKey: .fiscalBlock)
        fiscalStair = try container.decodeIfPresent(String.self, forKey: .fiscalStair)
        fiscalApartment = try container.decodeIfPresent(String.self, forKey: .fiscalApartment)
        fiscalGln = try container.decodeIfPresent(String.self, forKey: .fiscalGln)
        useFiscalInDeclarations = try container.decodeIfPresent(Bool.self, forKey: .useFiscalInDeclarations) ?? false
        usesIntraCommunityVat = try container.decodeIfPresent(Bool.self, forKey: .usesIntraCommunityVat) ?? false
        intraCommunityVatCode = try container.decodeIfPresent(String.self, forKey: .intraCommunityVatCode)
        adminUserId = try container.decodeIfPresent(UUID.self, forKey: .adminUserId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(denumire, forKey: .denumire)
        try container.encodeIfPresent(cui, forKey: .cui)
        try container.encodeIfPresent(nrRegCom, forKey: .nrRegCom)
        try container.encodeIfPresent(adresa, forKey: .adresa)
        try container.encodeIfPresent(iban, forKey: .iban)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(telefon, forKey: .telefon)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(platitorTva, forKey: .platitorTva)
        try container.encode(cifCountryPrefix, forKey: .cifCountryPrefix)
        try container.encodeIfPresent(codCaen, forKey: .codCaen)
        try container.encodeIfPresent(capitalSocial, forKey: .capitalSocial)
        try container.encode(splitTva, forKey: .splitTva)
        try container.encodeIfPresent(codLei, forKey: .codLei)
        try container.encodeIfPresent(fax, forKey: .fax)
        try container.encodeIfPresent(web, forKey: .web)
        try container.encodeIfPresent(logoUrl, forKey: .logoUrl)
        try container.encodeIfPresent(hqCountry, forKey: .hqCountry)
        try container.encodeIfPresent(hqCounty, forKey: .hqCounty)
        try container.encodeIfPresent(hqCity, forKey: .hqCity)
        try container.encodeIfPresent(hqPostalCode, forKey: .hqPostalCode)
        try container.encodeIfPresent(hqStreet, forKey: .hqStreet)
        try container.encodeIfPresent(hqStreetNumber, forKey: .hqStreetNumber)
        try container.encodeIfPresent(hqBlock, forKey: .hqBlock)
        try container.encodeIfPresent(hqStair, forKey: .hqStair)
        try container.encodeIfPresent(hqApartment, forKey: .hqApartment)
        try container.encodeIfPresent(hqGln, forKey: .hqGln)
        try container.encodeIfPresent(fiscalCountry, forKey: .fiscalCountry)
        try container.encodeIfPresent(fiscalCounty, forKey: .fiscalCounty)
        try container.encodeIfPresent(fiscalCity, forKey: .fiscalCity)
        try container.encodeIfPresent(fiscalPostalCode, forKey: .fiscalPostalCode)
        try container.encodeIfPresent(fiscalStreet, forKey: .fiscalStreet)
        try container.encodeIfPresent(fiscalStreetNumber, forKey: .fiscalStreetNumber)
        try container.encodeIfPresent(fiscalBlock, forKey: .fiscalBlock)
        try container.encodeIfPresent(fiscalStair, forKey: .fiscalStair)
        try container.encodeIfPresent(fiscalApartment, forKey: .fiscalApartment)
        try container.encodeIfPresent(fiscalGln, forKey: .fiscalGln)
        try container.encode(useFiscalInDeclarations, forKey: .useFiscalInDeclarations)
        try container.encode(usesIntraCommunityVat, forKey: .usesIntraCommunityVat)
        try container.encodeIfPresent(intraCommunityVatCode, forKey: .intraCommunityVatCode)
        try container.encodeIfPresent(adminUserId, forKey: .adminUserId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct CompanyPermission: Codable, Identifiable, Hashable, Sendable {
    let id: UUID?
    let userId: UUID?
    let companyId: UUID
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companyId = "company_id"
        case canView = "can_view"
        case canCreate = "can_create"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
    }

    init(
        id: UUID? = nil,
        userId: UUID? = nil,
        companyId: UUID,
        canView: Bool = false,
        canCreate: Bool = false,
        canEdit: Bool = false,
        canDelete: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.companyId = companyId
        self.canView = canView
        self.canCreate = canCreate
        self.canEdit = canEdit
        self.canDelete = canDelete
    }

    var hasAnyPermission: Bool {
        canView || canCreate || canEdit || canDelete
    }
}

struct CompanyPermissionInput: Codable, Sendable {
    let companyId: UUID
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case canView = "can_view"
        case canCreate = "can_create"
        case canEdit = "can_edit"
        case canDelete = "can_delete"
    }
}

enum CompanyAccessLevel: String, CaseIterable, Identifiable, Sendable {
    case noAccess
    case read
    case write

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noAccess: return "Fără acces"
        case .read: return "Citire"
        case .write: return "Scriere"
        }
    }

    func toPermission(companyId: UUID) -> CompanyPermission? {
        switch self {
        case .noAccess:
            return nil
        case .read:
            return CompanyPermission(companyId: companyId, canView: true)
        case .write:
            return CompanyPermission(
                companyId: companyId,
                canView: true,
                canCreate: true,
                canEdit: true,
                canDelete: true
            )
        }
    }

    static func from(permission: CompanyPermission?) -> CompanyAccessLevel {
        guard let permission, permission.hasAnyPermission else { return .noAccess }
        if permission.canCreate || permission.canEdit || permission.canDelete {
            return .write
        }
        return .read
    }
}

enum CompanyWritableAccess {
    static func hasWriteAccess(_ permission: CompanyPermission) -> Bool {
        permission.canCreate || permission.canEdit || permission.canDelete
    }

    static func writableCompanyIds(
        profile: UserProfile,
        companies: [Company],
        permissions: [CompanyPermission]
    ) -> Set<UUID> {
        if profile.isSuperAdmin {
            return Set(companies.map(\.id))
        }

        var ids = Set<UUID>()
        for company in companies where company.adminUserId == profile.id {
            ids.insert(company.id)
        }
        for permission in permissions where hasWriteAccess(permission) {
            ids.insert(permission.companyId)
        }
        return ids
    }

    static func writableCompanies(
        profile: UserProfile,
        companies: [Company],
        permissions: [CompanyPermission]
    ) -> [Company] {
        let ids = writableCompanyIds(profile: profile, companies: companies, permissions: permissions)
        return companies.filter { ids.contains($0.id) }
    }
}

struct CompanyAccessRights: Sendable {
    var canView: Bool
    var canCreate: Bool
    var canEdit: Bool
    var canDelete: Bool

    static let full = CompanyAccessRights(canView: true, canCreate: true, canEdit: true, canDelete: true)
    static let none = CompanyAccessRights(canView: false, canCreate: false, canEdit: false, canDelete: false)

    static func load(companyId: UUID, profile: UserProfile) async throws -> CompanyAccessRights {
        if profile.isSuperAdmin { return .full }
        if profile.isCompanyAdmin {
            let companies: [Company] = try await CompanyService.fetchCompanies()
            if companies.contains(where: { $0.id == companyId && $0.adminUserId == profile.id }) {
                return .full
            }
        }
        let permissions = try await CompanyService.fetchUserCompanyPermissions(userId: profile.id)
        guard let permission = permissions.first(where: { $0.companyId == companyId }) else {
            return .none
        }
        return CompanyAccessRights(
            canView: permission.canView,
            canCreate: permission.canCreate,
            canEdit: permission.canEdit,
            canDelete: permission.canDelete
        )
    }
}

extension ModuleAccessRights {
    static func effective(module: ModuleAccessRights, company: CompanyAccessRights) -> ModuleAccessRights {
        ModuleAccessRights(
            canView: module.canView && company.canView,
            canCreate: module.canCreate && company.canCreate,
            canEdit: module.canEdit && company.canEdit,
            canDelete: module.canDelete && company.canDelete
        )
    }
}
