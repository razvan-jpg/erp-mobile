import Foundation

enum ZettaVatSlot: String, CaseIterable, Identifiable, Codable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    var id: String { rawValue }
}

enum ZettaVatRateOption: Int, CaseIterable, Identifiable, Codable, Sendable {
    case zero = 0
    case five = 5
    case eleven = 11
    case twentyOne = 21

    var id: Int { rawValue }

    var label: String { "\(rawValue)%" }
}

enum ZettaSalesCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case marfa
    case produseFinite = "produse_finite"
    case servicii
    case chirii
    case venituriDiverse = "venituri_diverse"
    case sgr
    case bacsis

    var id: String { rawValue }

    var localizationKey: String {
        "settings.zetta.sales.\(rawValue)"
    }

    var label: String { L10n.tr(localizationKey) }

    var defaultAccount: String {
        switch self {
        case .marfa: return "707"
        case .produseFinite: return "7015"
        case .servicii: return "704"
        case .chirii: return "706"
        case .venituriDiverse: return "708"
        case .sgr: return "267"
        case .bacsis: return "462"
        }
    }

    /// Cont fix — nu se editează în setări (SGR=267, Bacșiș=462).
    var hasFixedAccount: Bool {
        self == .sgr || self == .bacsis
    }

    static var configurableCases: [ZettaSalesCategory] {
        allCases.filter { !$0.hasFixedAccount }
    }
}

struct ZettaSalesMapping: Codable, Hashable, Identifiable, Sendable {
    var category: ZettaSalesCategory
    var account: String
    var isEnabled: Bool

    var id: String { category.rawValue }

    static func defaults() -> [ZettaSalesMapping] {
        ZettaSalesCategory.allCases.map {
            ZettaSalesMapping(category: $0, account: $0.defaultAccount, isEnabled: false)
        }
    }
}

struct ZettaVatCategorySettings: Codable, Hashable, Sendable {
    var isEnabled: Bool
    var rate: ZettaVatRateOption
    var salesMappings: [ZettaSalesMapping]

    static func `default`(for slot: ZettaVatSlot) -> ZettaVatCategorySettings {
        let defaultRate: ZettaVatRateOption = switch slot {
        case .a: .twentyOne
        case .b: .eleven
        case .c: .five
        case .d: .zero
        }
        return ZettaVatCategorySettings(
            isEnabled: slot == .a,
            rate: defaultRate,
            salesMappings: ZettaSalesMapping.defaults()
        )
    }
}

struct ZettaLocationCasaAccount: Codable, Hashable, Identifiable, Sendable {
    var workLocationId: UUID
    var account: String

    var id: UUID { workLocationId }
}

struct ZettaSettingsPayload: Codable, Hashable, Sendable {
    var multipleShiftsPerRegister: Bool
    var shiftsPerRegisterCount: Int
    var usesRegistersOnMultipleWorkLocations: Bool
    var headquartersCasaAccount: String
    var locationCasaAccounts: [ZettaLocationCasaAccount]
    var cardPaymentAccount: String
    var modernPaymentAccount: String
    var vatCategories: [String: ZettaVatCategorySettings]

    static func defaults() -> ZettaSettingsPayload {
        var vat: [String: ZettaVatCategorySettings] = [:]
        for slot in ZettaVatSlot.allCases {
            vat[slot.rawValue] = .default(for: slot)
        }
        return ZettaSettingsPayload(
            multipleShiftsPerRegister: false,
            shiftsPerRegisterCount: 2,
            usesRegistersOnMultipleWorkLocations: false,
            headquartersCasaAccount: "5311.0",
            locationCasaAccounts: [],
            cardPaymentAccount: "5125",
            modernPaymentAccount: "5113",
            vatCategories: vat
        )
    }

    func vatSettings(for slot: ZettaVatSlot) -> ZettaVatCategorySettings {
        vatCategories[slot.rawValue] ?? .default(for: slot)
    }

    mutating func setVatSettings(_ settings: ZettaVatCategorySettings, for slot: ZettaVatSlot) {
        vatCategories[slot.rawValue] = settings
    }

    mutating func syncLocationAccounts(with locations: [CompanyWorkLocation]) {
        let byId = Dictionary(uniqueKeysWithValues: locationCasaAccounts.map { ($0.workLocationId, $0.account) })
        let singleDefault = "5311"
        locationCasaAccounts = locations.enumerated().map { index, location in
            let fallback = locations.count == 1 ? singleDefault : "5311.\(index + 1)"
            return ZettaLocationCasaAccount(
                workLocationId: location.id,
                account: byId[location.id] ?? fallback
            )
        }
    }

    func account(for locationId: UUID) -> String {
        locationCasaAccounts.first(where: { $0.workLocationId == locationId })?.account ?? "5311"
    }

    mutating func setAccount(_ account: String, for locationId: UUID) {
        if let index = locationCasaAccounts.firstIndex(where: { $0.workLocationId == locationId }) {
            locationCasaAccounts[index].account = account
        } else {
            locationCasaAccounts.append(ZettaLocationCasaAccount(workLocationId: locationId, account: account))
        }
    }

    enum CodingKeys: String, CodingKey {
        case multipleShiftsPerRegister, shiftsPerRegisterCount, usesRegistersOnMultipleWorkLocations
        case headquartersCasaAccount, locationCasaAccounts, cardPaymentAccount, modernPaymentAccount
        case vatCategories
    }

    init(
        multipleShiftsPerRegister: Bool,
        shiftsPerRegisterCount: Int,
        usesRegistersOnMultipleWorkLocations: Bool,
        headquartersCasaAccount: String,
        locationCasaAccounts: [ZettaLocationCasaAccount],
        cardPaymentAccount: String,
        modernPaymentAccount: String,
        vatCategories: [String: ZettaVatCategorySettings]
    ) {
        self.multipleShiftsPerRegister = multipleShiftsPerRegister
        self.shiftsPerRegisterCount = shiftsPerRegisterCount
        self.usesRegistersOnMultipleWorkLocations = usesRegistersOnMultipleWorkLocations
        self.headquartersCasaAccount = headquartersCasaAccount
        self.locationCasaAccounts = locationCasaAccounts
        self.cardPaymentAccount = cardPaymentAccount
        self.modernPaymentAccount = modernPaymentAccount
        self.vatCategories = vatCategories
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        multipleShiftsPerRegister = try c.decodeIfPresent(Bool.self, forKey: .multipleShiftsPerRegister) ?? false
        shiftsPerRegisterCount = try c.decodeIfPresent(Int.self, forKey: .shiftsPerRegisterCount) ?? 2
        usesRegistersOnMultipleWorkLocations = try c.decodeIfPresent(Bool.self, forKey: .usesRegistersOnMultipleWorkLocations) ?? false
        headquartersCasaAccount = try c.decodeIfPresent(String.self, forKey: .headquartersCasaAccount) ?? "5311.0"
        locationCasaAccounts = try c.decodeIfPresent([ZettaLocationCasaAccount].self, forKey: .locationCasaAccounts) ?? []
        cardPaymentAccount = try c.decodeIfPresent(String.self, forKey: .cardPaymentAccount) ?? "5125"
        modernPaymentAccount = try c.decodeIfPresent(String.self, forKey: .modernPaymentAccount) ?? "5113"
        vatCategories = try c.decodeIfPresent([String: ZettaVatCategorySettings].self, forKey: .vatCategories) ?? [:]
        if vatCategories.isEmpty {
            for slot in ZettaVatSlot.allCases {
                vatCategories[slot.rawValue] = .default(for: slot)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(multipleShiftsPerRegister, forKey: .multipleShiftsPerRegister)
        try c.encode(shiftsPerRegisterCount, forKey: .shiftsPerRegisterCount)
        try c.encode(usesRegistersOnMultipleWorkLocations, forKey: .usesRegistersOnMultipleWorkLocations)
        try c.encode(headquartersCasaAccount, forKey: .headquartersCasaAccount)
        try c.encode(locationCasaAccounts, forKey: .locationCasaAccounts)
        try c.encode(cardPaymentAccount, forKey: .cardPaymentAccount)
        try c.encode(modernPaymentAccount, forKey: .modernPaymentAccount)
        try c.encode(vatCategories, forKey: .vatCategories)
    }
}

struct CompanyZettaSettings: Codable, Hashable, Sendable {
    var companyId: UUID
    var payload: ZettaSettingsPayload
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case payload = "settings"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func defaults(companyId: UUID) -> CompanyZettaSettings {
        CompanyZettaSettings(
            companyId: companyId,
            payload: .defaults(),
            createdAt: nil,
            updatedAt: nil
        )
    }
}

/// Context pentru generarea NC din setările Zetta ale societății.
struct ZettaNCConfig: Sendable {
    let settings: ZettaSettingsPayload
    let workLocations: [CompanyWorkLocation]

    var hasMultipleWorkLocations: Bool { workLocations.count > 1 }
}

extension ZettaVatCategorySettings {
    func resolvedAccount(for category: ZettaSalesCategory) -> String {
        guard let mapping = salesMappings.first(where: { $0.category == category }) else {
            return category.defaultAccount
        }
        let trimmed = mapping.account.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? category.defaultAccount : trimmed
    }

    /// Cont venit pentru cote cu TVA ≠ 0% — opțiunea activă pe cotă.
    func revenueAccountForTaxedSales() -> (account: String, title: String) {
        if let mapping = salesMappings.first(where: \.isEnabled) {
            let account = resolvedAccount(for: mapping.category)
            return (account, Conturi.title(for: account))
        }
        return (Conturi.venituri21, Conturi.venituri21Titlu)
    }

    var hasBacsisEnabled: Bool {
        salesMappings.contains { $0.category == .bacsis && $0.isEnabled }
    }

    var hasSGREnabled: Bool {
        salesMappings.contains { $0.category == .sgr && $0.isEnabled }
    }
}
