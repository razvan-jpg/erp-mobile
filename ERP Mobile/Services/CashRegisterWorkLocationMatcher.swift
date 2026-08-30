import Foundation

enum CashRegisterWorkLocationMatcher {
    static func match(
        report: CompanyZReportRecord,
        locations: [CompanyWorkLocation]
    ) -> CashRegisterCasaTarget {
        let active = locations.filter(\.isActive)
        guard active.count > 1 else { return .headquarters }

        if let target = match(punctLucru: report.payload.punctLucru, locations: active) {
            return target
        }

        let labelKey = compact(report.payload.locatieLabel)
        if !labelKey.isEmpty,
           let target = match(labelKey: labelKey, locations: active) {
            return target
        }

        if let detected = PunctLucru.detect(from: report.payload.ocrText),
           let target = match(punctLucru: detected, locations: active) {
            return target
        }

        return .headquarters
    }

    static func displayName(
        for target: CashRegisterCasaTarget,
        locations: [CompanyWorkLocation]
    ) -> String {
        switch target {
        case .headquarters:
            return L10n.tr("module.cash_register.casa_sediu")
        case .workLocation(let id):
            return locations.first(where: { $0.id == id })?.denumire
                ?? L10n.tr("module.cash_register.casa_location_unknown")
        }
    }

    private static func match(
        punctLucru: PunctLucru,
        locations: [CompanyWorkLocation]
    ) -> CashRegisterCasaTarget? {
        switch punctLucru {
        case .ploiesti:
            return locations.first(where: {
                let name = compact($0.denumire)
                let city = compact($0.city ?? "")
                return name.contains("PLOIESTI") || city.contains("PLOIESTI")
            }).map { .workLocation($0.id) }
        case .agro:
            return locations.first(where: {
                let name = compact($0.denumire)
                let city = compact($0.city ?? "")
                return name.contains("AGRO") || name.contains("AGRONOMIE") || city.contains("BUCURESTI")
            }).map { .workLocation($0.id) }
        }
    }

    private static func match(
        labelKey: String,
        locations: [CompanyWorkLocation]
    ) -> CashRegisterCasaTarget? {
        if labelKey.contains("PLOIESTI") {
            return locations.first(where: {
                let name = compact($0.denumire)
                let city = compact($0.city ?? "")
                return name.contains("PLOIESTI") || city.contains("PLOIESTI")
            }).map { .workLocation($0.id) }
        }
        if labelKey.contains("AGRO") || labelKey.contains("AGRONOMIE") || labelKey.contains("BUCURESTI") {
            return locations.first(where: {
                let name = compact($0.denumire)
                let city = compact($0.city ?? "")
                return name.contains("AGRO") || name.contains("AGRONOMIE") || city.contains("BUCURESTI")
            }).map { .workLocation($0.id) }
        }

        if let exact = locations.first(where: {
            let name = compact($0.denumire)
            return !name.isEmpty && (labelKey.contains(name) || name.contains(labelKey))
        }) {
            return .workLocation(exact.id)
        }
        return nil
    }

    private static func compact(_ value: String) -> String {
        value
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "ro_RO"))
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
