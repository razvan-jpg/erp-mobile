import Foundation

struct CompanyWorkLocation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let companyId: UUID
    var denumire: String
    var country: String?
    var county: String?
    var city: String?
    var street: String?
    var streetNumber: String?
    var block: String?
    var stair: String?
    var floor: String?
    var apartment: String?
    var postalCode: String?
    var telefon: String?
    var telefonMobil: String?
    var gln: String?
    var isActive: Bool
    var isDefault: Bool
    var operatesAtHeadquarters: Bool
    var isFiscalDomicile: Bool
    var useInDeclarations: Bool
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, denumire, country, county, city, street, block, stair, floor, apartment, telefon, gln
        case companyId = "company_id"
        case streetNumber = "street_number"
        case postalCode = "postal_code"
        case telefonMobil = "telefon_mobil"
        case isActive = "is_active"
        case isDefault = "is_default"
        case operatesAtHeadquarters = "operates_at_headquarters"
        case isFiscalDomicile = "is_fiscal_domicile"
        case useInDeclarations = "use_in_declarations"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var displaySubtitle: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let county, !county.isEmpty { parts.append(county) }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    var formattedPostalAddress: String? {
        var segments: [String] = []

        var streetLine = ""
        if let street = trimmedNonEmpty(street) {
            streetLine = street
            if let number = trimmedNonEmpty(streetNumber) {
                streetLine += " nr. \(number)"
            }
        }
        if !streetLine.isEmpty {
            segments.append(streetLine)
        }

        var blockLine = ""
        if let block = trimmedNonEmpty(block) { blockLine += "bl. \(block)" }
        if let stair = trimmedNonEmpty(stair) {
            blockLine += blockLine.isEmpty ? "sc. \(stair)" : ", sc. \(stair)"
        }
        if let floor = trimmedNonEmpty(floor) {
            blockLine += blockLine.isEmpty ? "et. \(floor)" : ", et. \(floor)"
        }
        if let apartment = trimmedNonEmpty(apartment) {
            blockLine += blockLine.isEmpty ? "ap. \(apartment)" : ", ap. \(apartment)"
        }
        if !blockLine.isEmpty {
            segments.append(blockLine)
        }

        if let city = trimmedNonEmpty(city) { segments.append(city) }
        if let county = trimmedNonEmpty(county) { segments.append(county) }
        if let postalCode = trimmedNonEmpty(postalCode) { segments.append(postalCode) }
        if let country = trimmedNonEmpty(country) { segments.append(country) }

        let value = segments.joined(separator: ", ")
        return value.isEmpty ? nil : value
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
