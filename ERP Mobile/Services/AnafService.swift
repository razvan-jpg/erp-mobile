import Foundation

struct AnafCompanyLookup: Sendable {
    let cui: String
    let denumire: String
    let nrRegCom: String?
    let adresa: String?
    let telefon: String?
    let iban: String?
    let observatii: String?
    let platitorTva: Bool?
    let codCaen: String?
    let hqCounty: String?
    let hqCity: String?
    let hqPostalCode: String?
    let hqStreet: String?
    let hqStreetNumber: String?

    var hasAnyData: Bool {
        !denumire.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum AnafServiceError: LocalizedError {
    case invalidCUI
    case notFound
    case network(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidCUI:
            return "CUI invalid. Introduceți un cod fiscal numeric (cu sau fără prefix RO)."
        case .notFound:
            return "Nu s-au găsit date la ANAF pentru acest CUI."
        case .network(let code):
            return "Eroare la interogarea ANAF (cod \(code)). Încercați din nou."
        case .invalidResponse:
            return "Răspuns neașteptat de la ANAF."
        }
    }
}

enum AnafService {
    private static let endpoint = URL(string: "https://webservicesp.anaf.ro/api/PlatitorTvaRest/v9/tva")!

    private static let queryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func fetchCompany(cui: String) async throws -> AnafCompanyLookup {
        guard let normalized = Validators.normalizedCUI(cui),
              let cuiInt = Int(normalized) else {
            throw AnafServiceError.invalidCUI
        }

        let payload: [[String: Any]] = [[
            "cui": cuiInt,
            "data": queryDateFormatter.string(from: Date())
        ]]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnafServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AnafServiceError.network(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AnafVatResponse.self, from: data)
        guard let company = decoded.found?.first else {
            throw AnafServiceError.notFound
        }

        return company.toLookup(normalizedCUI: normalized)
    }
}

private struct AnafVatResponse: Decodable {
    let found: [AnafFoundCompany]?
}

private struct AnafFoundCompany: Decodable {
    let dateGenerale: AnafGeneralData
    let adresaSediuSocial: AnafOfficeAddress?
    let inregistrareScopTva: AnafVatRegistration?

    enum CodingKeys: String, CodingKey {
        case dateGenerale = "date_generale"
        case adresaSediuSocial = "adresa_sediu_social"
        case inregistrareScopTva = "inregistrare_scop_Tva"
    }

    func toLookup(normalizedCUI: String) -> AnafCompanyLookup {
        let general = dateGenerale
        let office = adresaSediuSocial
        let address = buildAddress(general: general, office: office)

        var notes: [String] = []
        if let caen = nonEmpty(general.codCAEN) {
            notes.append("CAEN: \(caen)")
        }
        if let forma = nonEmpty(general.formaJuridica) {
            notes.append(forma)
        }
        if let stare = nonEmpty(general.stareInregistrare) {
            notes.append(stare)
        }

        return AnafCompanyLookup(
            cui: normalizedCUI,
            denumire: nonEmpty(general.denumire) ?? "",
            nrRegCom: nonEmpty(general.nrRegCom),
            adresa: address,
            telefon: nonEmpty(general.telefon),
            iban: nonEmpty(general.iban),
            observatii: notes.isEmpty ? nil : notes.joined(separator: " | "),
            platitorTva: inregistrareScopTva?.scpTVA,
            codCaen: nonEmpty(general.codCAEN),
            hqCounty: nonEmpty(office?.countyName),
            hqCity: nonEmpty(office?.localityName),
            hqPostalCode: nonEmpty(office?.postalCode),
            hqStreet: nonEmpty(office?.streetName),
            hqStreetNumber: nonEmpty(office?.streetNumber)
        )
    }

    private func buildAddress(general: AnafGeneralData, office: AnafOfficeAddress?) -> String? {
        if let office {
            var parts: [String] = []
            if let street = nonEmpty(office.streetName) {
                parts.append("Str. \(street)")
            }
            if let number = nonEmpty(office.streetNumber) {
                parts.append("nr. \(number)")
            }
            if let locality = nonEmpty(office.localityName) {
                parts.append(locality)
            }
            if let county = nonEmpty(office.countyName) {
                parts.append("Jud. \(county)")
            }
            if let postal = nonEmpty(office.postalCode) {
                parts.append(postal)
            }
            let built = parts.joined(separator: ", ")
            if !built.isEmpty { return built }
        }
        return nonEmpty(general.adresa)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct AnafVatRegistration: Decodable {
    let scpTVA: Bool?
}

private struct AnafGeneralData: Decodable {
    let denumire: String?
    let adresa: String?
    let telefon: String?
    let nrRegCom: String?
    let iban: String?
    let codCAEN: String?
    let formaJuridica: String?
    let stareInregistrare: String?

    enum CodingKeys: String, CodingKey {
        case denumire, adresa, telefon, iban
        case nrRegCom = "nrRegCom"
        case codCAEN = "cod_CAEN"
        case formaJuridica = "forma_juridica"
        case stareInregistrare = "stare_inregistrare"
    }
}

private struct AnafOfficeAddress: Decodable {
    let streetName: String?
    let streetNumber: String?
    let localityName: String?
    let countyName: String?
    let postalCode: String?

    enum CodingKeys: String, CodingKey {
        case streetName = "sdenumire_Strada"
        case streetNumber = "snumar_Strada"
        case localityName = "sdenumire_Localitate"
        case countyName = "sdenumire_Judet"
        case postalCode = "scod_Postal"
    }
}
