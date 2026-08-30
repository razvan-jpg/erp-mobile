import Foundation

enum PunctLucru: String, CaseIterable, Identifiable, Codable {
    case agro = "Agro (București)"
    case ploiesti = "Ploiești"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .agro: return "Agro"
        case .ploiesti: return "Ploiesti"
        }
    }

    /// Cont casă punct de lucru (5311.1 Agro / 5311.2 Ploiești)
    var casaPunct: String {
        switch self {
        case .agro: return "5311.1"
        case .ploiesti: return "5311.2"
        }
    }

    var casaPunctTitlu: String {
        switch self {
        case .agro: return "Casa in lei Agro"
        case .ploiesti: return "Casa in lei Ploiesti"
        }
    }

    /// Prefix număr document: Agro = doar cifra, Ploiești = „z” + cifră
    func formatDocumentNumber(_ zNumber: Int) -> String {
        let padded = String(format: "%04d", zNumber)
        switch self {
        case .agro: return padded
        case .ploiesti: return "z\(padded)"
        }
    }

    /// Detectare automată din text OCR / adresă
    nonisolated static func detect(from text: String) -> PunctLucru? {
        let upper = text.uppercased()
        if upper.contains("PLOIESTI") || upper.contains("PLOIEȘTI") || upper.contains("PRAHOVA")
            || upper.contains("VICTORIEI") || upper.contains("DB4700040800") {
            return .ploiesti
        }
        if upper.contains("BUCURESTI") || upper.contains("BUCUREȘTI") || upper.contains("NEBIOLO")
            || upper.contains("SECTOR 1") || upper.contains("DB4700040799")
            || upper.contains("AGRONOMIEI") || upper.contains("AGRO") {
            return .agro
        }
        return nil
    }
}

/// Firme cunoscute — identificare după CIF/CUI (prioritar) sau nume OCR.
enum FirmaRegistry {
    struct Profile: Sendable {
        /// Cifre CUI fără prefix RO (ex. 51159591).
        let cui: String
        let displayName: String
        let isNectarie: Bool
        let partenerCod: String
        let partenerNume: String
        /// SCUTIT DE TVA - S → cont 446.2 BACSIS; încasări doar numerar + card (fără plată modernă).
        let scutitUsesBacsis: Bool
        /// Cont credit pentru vânzări 0% / SCUTIT (implicit 267.1 garanție).
        let scutitCredit: String?
        let scutitCreditTitlu: String?

        nonisolated var partenerCIF: String { "RO\(cui)" }

        nonisolated init(
            cui: String,
            displayName: String,
            isNectarie: Bool,
            partenerCod: String,
            partenerNume: String,
            scutitUsesBacsis: Bool = false,
            scutitCredit: String? = nil,
            scutitCreditTitlu: String? = nil
        ) {
            self.cui = cui
            self.displayName = displayName
            self.isNectarie = isNectarie
            self.partenerCod = partenerCod
            self.partenerNume = partenerNume
            self.scutitUsesBacsis = scutitUsesBacsis
            self.scutitCredit = scutitCredit
            self.scutitCreditTitlu = scutitCreditTitlu
        }
    }

    nonisolated static let known: [Profile] = [
        Profile(
            cui: "51159591",
            displayName: Conturi.firmaNectarie,
            isNectarie: true,
            partenerCod: "0000041",
            partenerNume: "Clienti"
        ),
        Profile(
            cui: "47240786",
            displayName: "BUNATATI LA MARIA S.R.L.",
            isNectarie: false,
            partenerCod: "0000023",
            partenerNume: "Clienti diversi"
        ),
        Profile(
            cui: "49209086",
            displayName: "HOTEL IMPEX S.R.L.",
            isNectarie: false,
            partenerCod: "0000003",
            partenerNume: "Clienti",
            scutitUsesBacsis: true
        ),
        Profile(
            cui: "30165469",
            displayName: "GENIC TEAM INTERNATIONAL S.R.L.",
            isNectarie: false,
            partenerCod: "0000813",
            partenerNume: "CLIENTI REST",
            scutitUsesBacsis: true
        ),
        Profile(
            cui: "52383839",
            displayName: "AMERICAN FC S.R.L.",
            isNectarie: false,
            partenerCod: "0000114",
            partenerNume: "Clienti"
        ),
        Profile(
            cui: "48962204",
            displayName: "CLINICA MEDICALA PROMETEU S.R.L.",
            isNectarie: false,
            partenerCod: Conturi.partenerCod,
            partenerNume: Conturi.partenerNume,
            scutitCredit: Conturi.venituriServicii,
            scutitCreditTitlu: Conturi.venituriServiciiTitlu
        ),
        Profile(
            cui: "49982919",
            displayName: "PMT ACHIZITII S.R.L.",
            isNectarie: false,
            partenerCod: Conturi.partenerCod,
            partenerNume: Conturi.partenerNume,
            scutitCredit: Conturi.venituri21,
            scutitCreditTitlu: Conturi.venituri21Titlu
        )
    ]

    /// Normalizează CIF/CUI din OCR: RO51159591, R051159591 → 51159591.
    nonisolated static func normalizeCUI(_ raw: String) -> String? {
        var s = raw.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
        if s.hasPrefix("RO") {
            s = String(s.dropFirst(2))
        } else if s.hasPrefix("R0") {
            s = String(s.dropFirst(2))
        }
        let digits = s.filter(\.isNumber)
        guard (6...10).contains(digits.count) else { return nil }
        return digits
    }

    nonisolated static func profile(forCUI cui: String) -> Profile? {
        guard let normalized = normalizeCUI(cui) else { return nil }
        return known.first { $0.cui == normalized }
    }

    /// Potrivire tolerantă OCR: cifre în ordine, ±1 caracter, zero în față.
    nonisolated static func profile(fuzzyCUI raw: String) -> Profile? {
        guard let candidate = normalizeCUI(raw) else { return nil }
        if let exact = profile(forCUI: candidate) { return exact }

        let trimmed = String(candidate.drop(while: { $0 == "0" }))
        if let exact = profile(forCUI: trimmed) { return exact }

        var best: (profile: Profile, score: Int)?
        for profile in known {
            let knownCUI = profile.cui
            if candidate == knownCUI || trimmed == knownCUI { return profile }

            if candidate.count == knownCUI.count {
                let diffs = zip(candidate, knownCUI).filter { $0 != $1 }.count
                if diffs <= 2 {
                    let score = 100 - diffs * 10
                    if best == nil || score > best!.score { best = (profile, score) }
                }
            }

            let subsequenceScore = cuiSubsequenceScore(known: knownCUI, candidate: candidate)
            if subsequenceScore >= knownCUI.count - 1 {
                let score = 80 + subsequenceScore
                if best == nil || score > best!.score { best = (profile, score) }
            }
        }
        return best?.profile
    }

    nonisolated private static func cuiSubsequenceScore(known: String, candidate: String) -> Int {
        var ki = known.startIndex
        for ch in candidate where ch.isNumber {
            if ki < known.endIndex, ch == known[ki] {
                ki = known.index(after: ki)
            }
        }
        return known.distance(from: known.startIndex, to: ki)
    }

    nonisolated static func profile(matchingName name: String) -> Profile? {
        let key = Conturi.compactFirmaKey(name)
        guard !key.isEmpty else { return nil }

        if key.contains("NECTARIE"), key.contains("20XX") {
            return known.first { $0.isNectarie }
        }
        if key.contains("MAGNOLIA") || (key.contains("COMPLEX") && key.contains("MAGNOLIA")) {
            return known.first { $0.isNectarie }
        }
        if key.contains("BUNATATI"), key.contains("MARIA") {
            return known.first { $0.cui == "47240786" }
        }
        if key.contains("HOTEL"), key.contains("IMPEX") {
            return known.first { $0.cui == "49209086" }
        }
        if key.contains("GENIC") {
            return known.first { $0.cui == "30165469" }
        }
        if key.contains("AMERICA"), key.contains("FC") || key.contains("F.C") {
            return known.first { $0.cui == "52383839" }
        }
        if key.contains("AMERICAF") || key.contains("AMERICAFC") {
            return known.first { $0.cui == "52383839" }
        }
        if key.contains("PROMETEU") {
            return known.first { $0.cui == "48962204" }
        }
        if key.contains("PMT"), key.contains("ACHIZIT") {
            return known.first { $0.cui == "49982919" }
        }
        return nil
    }

    /// Caută CUI-ul unei firme cunoscute în textul OCR (inclusiv R0… fără O).
    nonisolated static func profile(foundInOCR text: String) -> Profile? {
        let upper = text.uppercased()
        for profile in known {
            let patterns = [
                "RO\(profile.cui)",
                "R0\(profile.cui)",
                profile.cui
            ]
            if patterns.contains(where: { upper.contains($0) }) {
                return profile
            }
        }
        return nil
    }

    /// Rezolvă firma: CIF explicit → CIF fuzzy → CUI în text → nume în text → nume OCR → Nectarie.
    nonisolated static func resolve(cuiFromParser: String?, ocrName: String, ocrText: String) -> Profile? {
        if let cuiFromParser, let p = profile(forCUI: cuiFromParser) ?? profile(fuzzyCUI: cuiFromParser) {
            return p
        }
        if let p = profile(foundInOCR: ocrText) { return p }
        if let p = profile(matchingName: ocrText) { return p }
        if !isReceiptHeaderLabel(ocrName), let p = profile(matchingName: ocrName) { return p }
        if Conturi.isNectarieFirma(ocrName) || Conturi.isNectarieFirma(ocrText) {
            return known.first { $0.isNectarie }
        }
        return nil
    }

    /// Nu e nume de firmă — titlu tipărit pe bon (OCR îl pune uneori ca „firmă”).
    nonisolated static func isReceiptHeaderLabel(_ name: String) -> Bool {
        let key = Conturi.compactFirmaKey(name)
        guard !key.isEmpty else { return true }
        if key == "FISCALZILNIC" || key == "RAPORTFISCAL" || key == "RAPORTFISCALZILNIC" {
            return true
        }
        if key.hasPrefix("FISCALZIL") || key.hasPrefix("RAPORTFISCAL") {
            return true
        }
        if key == "FISCAL" || key == "RAPORT" || key == "ZILNIC" {
            return true
        }
        return false
    }

    nonisolated static func groupingKey(for report: ZReportData) -> String {
        // Profil cunoscut (CUI / nume OCR / text bon) — o singură cheie per societate,
        // chiar dacă un Z are CUI gol și altul are nume OCR diferit.
        if let profile = profile(for: report) {
            return "cui:\(profile.cui)"
        }
        if let normalized = normalizeCUI(report.cui) {
            return "cui:\(normalized)"
        }
        return Conturi.firmaGroupingKey(Conturi.normalizedFirmaDisplay(report.firma))
    }

    nonisolated static func displayName(for report: ZReportData) -> String {
        if let p = profile(forCUI: report.cui) { return p.displayName }
        let trimmed = report.firma.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Firma necunoscuta" : Conturi.normalizedFirmaDisplay(trimmed)
    }

    nonisolated static func profile(for report: ZReportData) -> Profile? {
        profile(forCUI: report.cui)
            ?? profile(matchingName: report.firma)
            ?? (report.ocrText.isEmpty ? nil : profile(foundInOCR: report.ocrText))
    }
}

enum Conturi {
    nonisolated static let clienti = "4111"
    nonisolated static let clientiTitlu = "Clienti"
    nonisolated static let tvaColectata = "4427"
    nonisolated static let tvaColectataTitlu = "TVA colectata"
    nonisolated static let venituri11 = "701"
    nonisolated static let venituri11Titlu = "Venituri din vanzarea produselor finite"
    nonisolated static let venituri21 = "707"
    nonisolated static let venituri21Titlu = "Venituri din vanzarea marfurilor"
    nonisolated static let venituriServicii = "704"
    nonisolated static let venituriServiciiTitlu = "Venituri din lucrari executate si servicii prestate"
    nonisolated static let garantie = "267.1"
    nonisolated static let garantieTitlu = "GARANTIE depusa"

    /// Cont credit pentru vânzări 0% / SCUTIT: per firmă (704 Prometeu, 707 PMT) sau 267.1 implicit.
    nonisolated static func scutitCredit(for report: ZReportData) -> (cont: String, titlu: String) {
        if let profile = FirmaRegistry.profile(for: report),
           let cont = profile.scutitCredit,
           let titlu = profile.scutitCreditTitlu {
            return (cont, titlu)
        }
        return (garantie, garantieTitlu)
    }
    nonisolated static let bacsisVenit = "462"
    nonisolated static let bacsisVenitTitlu = "Bacsis"
    nonisolated static let bacsis = "446.2"
    nonisolated static let bacsisTitlu = "BACSIS"
    nonisolated static let viramente = "581"
    nonisolated static let viramenteTitlu = "Viramente interne"
    nonisolated static let casaSediu = "5311.0"
    nonisolated static let casaSediuTitlu = "Casa in lei - sediu"
    /// Casă generică pentru alte firme (fără viramente 7–8)
    nonisolated static let casaGenerala = "5311"
    nonisolated static let casaGeneralaTitlu = "Casa in lei"
    nonisolated static let card = "5125"
    nonisolated static let cardTitlu = "Sume in curs de decontare"
    nonisolated static let plataModerna = "5113"
    nonisolated static let plataModernaTitlu = "Efecte de incasat"

    /// Default Nectarie / necunoscut.
    nonisolated static let partenerCod = "0000041"
    nonisolated static let partenerNume = "Clienti"

    nonisolated static let saft11 = "310351"
    nonisolated static let saft21 = "310344"
    nonisolated static let saft0 = "310324"
    nonisolated static let saft5 = "310352"

    /// Titlu cont pe baza simbolului (pentru conturi personalizate din setări Zetta).
    nonisolated static func title(for account: String) -> String {
        let normalized = account.trimmingCharacters(in: .whitespaces)
        switch normalized {
        case clienti: return clientiTitlu
        case tvaColectata: return tvaColectataTitlu
        case venituri11: return venituri11Titlu
        case venituri21: return venituri21Titlu
        case venituriServicii: return venituriServiciiTitlu
        case garantie, "267": return garantieTitlu
        case bacsisVenit: return bacsisVenitTitlu
        case bacsis: return bacsisTitlu
        case viramente: return viramenteTitlu
        case casaSediu: return casaSediuTitlu
        case casaGenerala: return casaGeneralaTitlu
        case card: return cardTitlu
        case plataModerna: return plataModernaTitlu
        default:
            if normalized.hasPrefix("5311") { return "Casa in lei" }
            if normalized.hasPrefix("701") { return venituri11Titlu }
            if normalized.hasPrefix("707") { return venituri21Titlu }
            if normalized.hasPrefix("704") { return venituriServiciiTitlu }
            if normalized.hasPrefix("706") { return "Venituri din chirii" }
            if normalized.hasPrefix("708") { return "Venituri diverse" }
            return normalized
        }
    }

    nonisolated static func saftCode(for rate: ZettaVatRateOption) -> String {
        switch rate {
        case .twentyOne: return saft21
        case .eleven: return saft11
        case .five: return saft5
        case .zero: return saft0
        }
    }

    /// Firma cu schema completă (5311.1/5311.2 + viramente 7–8)
    nonisolated static let firmaNectarie = "NECTARIE 20XXV S.R.L."

    struct PartenerNC {
        let cod: String
        let nume: String
        let cif: String
    }

    /// Cod + nume + CIF partener pe firmă (coloanele Excel Cod Partener / Partener Nume / Partener CIF).
    nonisolated static func partener(for report: ZReportData) -> PartenerNC {
        if let profile = FirmaRegistry.profile(forCUI: report.cui)
            ?? FirmaRegistry.profile(matchingName: report.firma) {
            return PartenerNC(cod: profile.partenerCod, nume: profile.partenerNume, cif: profile.partenerCIF)
        }
        return PartenerNC(cod: partenerCod, nume: partenerNume, cif: "")
    }

    nonisolated static func partener(forFirma firma: String) -> PartenerNC {
        var report = ZReportData()
        report.firma = firma
        return partener(for: report)
    }

    /// Cheie stabilă pentru grupare export (fără diacritice / case).
    nonisolated static func firmaGroupingKey(_ display: String) -> String {
        compactFirmaKey(display)
    }

    nonisolated static func normalizedFirmaDisplay(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Firma necunoscuta" }
        if let profile = FirmaRegistry.profile(matchingName: trimmed) {
            return profile.displayName
        }
        return trimmed
    }

    /// Detectează Nectarie 20XXV (toleranță OCR: 20XXU, spații, puncte).
    nonisolated static func isNectarieFirma(_ name: String) -> Bool {
        let compact = compactFirmaKey(name)
        // NECTARIE + 20XXV (sau 20XXU citit greșit de OCR pe bonurile model)
        guard compact.contains("NECTARIE") else { return false }
        return compact.contains("20XXV") || compact.contains("20XXU")
            || compact.contains("20XXW") || compact.contains("20XXY")
    }

    /// Corectează OCR tipic: 20XXU/W/Y → 20XXV și normalizează „S.R.L.”.
    nonisolated static func normalizedFirmaName(_ raw: String) -> String {
        let trimmed = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNectarieFirma(trimmed) || isNectarieFirma(raw) else { return trimmed }

        var name = trimmed.uppercased()
        name = name.replacingOccurrences(of: "20XXU", with: "20XXV")
        name = name.replacingOccurrences(of: "20XXW", with: "20XXV")
        name = name.replacingOccurrences(of: "20XXY", with: "20XXV")
        name = name.replacingOccurrences(of: "SRL", with: "S.R.L.")
        name = name.replacingOccurrences(of: "S.R.L", with: "S.R.L.")
        if !name.contains("S.R.L.") {
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            name += " S.R.L."
        }
        name = name.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        // Preferă forma canonică dacă e clar Nectarie.
        if name.contains("NECTARIE"), name.contains("20XXV") {
            return firmaNectarie
        }
        return name
    }

    nonisolated static func compactFirmaKey(_ name: String) -> String {
        name.uppercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "ro_RO"))
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "Ă", with: "A")
            .replacingOccurrences(of: "Â", with: "A")
            .replacingOccurrences(of: "Î", with: "I")
            .replacingOccurrences(of: "Ș", with: "S")
            .replacingOccurrences(of: "Ţ", with: "T")
            .replacingOccurrences(of: "Ț", with: "T")
    }
}

extension FirmaRegistry.Profile: Equatable {
    nonisolated static func == (lhs: FirmaRegistry.Profile, rhs: FirmaRegistry.Profile) -> Bool {
        lhs.cui == rhs.cui
            && lhs.displayName == rhs.displayName
            && lhs.isNectarie == rhs.isNectarie
            && lhs.partenerCod == rhs.partenerCod
            && lhs.partenerNume == rhs.partenerNume
            && lhs.scutitUsesBacsis == rhs.scutitUsesBacsis
            && lhs.scutitCredit == rhs.scutitCredit
            && lhs.scutitCreditTitlu == rhs.scutitCreditTitlu
    }
}
