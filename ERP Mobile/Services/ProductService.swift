import Foundation
import Supabase

private struct ProductInsert: Encodable {
    let companyId: UUID
    let cod: String?
    let codBare: String?
    let denumire: String
    let descriere: String?
    let unitateMasura: String
    let unitateAchizitie: String?
    let factorConversie: Decimal
    let tip: String
    let cpv: String?
    let isActive: Bool
    let inCatalog: Bool
    let inStockSheet: Bool
    let hasRecipe: Bool
    let cotaTva: Decimal
    let pretVanzare: Decimal
    let pretVanzareOnline: Decimal
    let imagineUrl: String?
    let cantitateMinima: Decimal
    let cantitateOptima: Decimal

    enum CodingKeys: String, CodingKey {
        case cod, denumire, descriere, cpv, tip
        case companyId = "company_id"
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
        case unitateAchizitie = "unitate_achizitie"
        case factorConversie = "factor_conversie"
        case isActive = "is_active"
        case inCatalog = "in_catalog"
        case inStockSheet = "in_stock_sheet"
        case hasRecipe = "has_recipe"
        case cotaTva = "cota_tva"
        case pretVanzare = "pret_vanzare"
        case pretVanzareOnline = "pret_vanzare_online"
        case imagineUrl = "imagine_url"
        case cantitateMinima = "cantitate_minima"
        case cantitateOptima = "cantitate_optima"
    }
}

private struct ProductImportEnrichment: Encodable {
    let codBare: String?

    enum CodingKeys: String, CodingKey {
        case codBare = "cod_bare"
    }
}

private struct ProductCatalogSettingsPatch: Encodable {
    let inCatalog: Bool?
    let inStockSheet: Bool?
    let hasRecipe: Bool?

    enum CodingKeys: String, CodingKey {
        case inCatalog = "in_catalog"
        case inStockSheet = "in_stock_sheet"
        case hasRecipe = "has_recipe"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let inCatalog {
            try container.encode(inCatalog, forKey: .inCatalog)
        }
        if let inStockSheet {
            try container.encode(inStockSheet, forKey: .inStockSheet)
        }
        if let hasRecipe {
            try container.encode(hasRecipe, forKey: .hasRecipe)
        }
    }
}

private struct ProductDetailsPatch: Encodable {
    let denumire: String
    let cod: String?
    let codBare: String?
    let unitateMasura: String
    let unitateAchizitie: String?
    let factorConversie: Decimal
    let tip: String
    let cantitateMinima: Decimal
    let cantitateOptima: Decimal

    enum CodingKeys: String, CodingKey {
        case denumire, cod, tip
        case codBare = "cod_bare"
        case unitateMasura = "unitate_masura"
        case unitateAchizitie = "unitate_achizitie"
        case factorConversie = "factor_conversie"
        case cantitateMinima = "cantitate_minima"
        case cantitateOptima = "cantitate_optima"
    }
}

private struct ProductImagePatch: Encodable {
    let imagineUrl: String?

    enum CodingKeys: String, CodingKey {
        case imagineUrl = "imagine_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let imagineUrl {
            try container.encode(imagineUrl, forKey: .imagineUrl)
        } else {
            try container.encodeNil(forKey: .imagineUrl)
        }
    }
}

private struct ProductArticleCategoryPatch: Encodable {
    let tip: String
    let inCatalog: Bool?

    enum CodingKeys: String, CodingKey {
        case tip
        case inCatalog = "in_catalog"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tip, forKey: .tip)
        if let inCatalog {
            try container.encode(inCatalog, forKey: .inCatalog)
        }
    }
}

private struct ProductPricingPatch: Encodable {
    let cotaTva: Decimal?
    let pretVanzare: Decimal?
    let pretVanzareOnline: Decimal?
    let pretAchizitie: Decimal?
    let includePurchasePrice: Bool

    enum CodingKeys: String, CodingKey {
        case cotaTva = "cota_tva"
        case pretVanzare = "pret_vanzare"
        case pretVanzareOnline = "pret_vanzare_online"
        case pretAchizitie = "pret_achizitie"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let cotaTva {
            try container.encode(cotaTva, forKey: .cotaTva)
        }
        if let pretVanzare {
            try container.encode(pretVanzare, forKey: .pretVanzare)
        }
        if let pretVanzareOnline {
            try container.encode(pretVanzareOnline, forKey: .pretVanzareOnline)
        }
        if includePurchasePrice {
            if let pretAchizitie {
                try container.encode(pretAchizitie, forKey: .pretAchizitie)
            } else {
                try container.encodeNil(forKey: .pretAchizitie)
            }
        }
    }
}

enum ProductService {
    nonisolated static let garantieSGRProductName = "Garantie SGR"
    nonisolated static let garantieProductName = "Garantie"
    /// Materie primă — cartofi (variante factură / 10KG etc. se unifică aici; nu e în catalog).
    nonisolated static let canonicalWhitePotatoProductName = "CARTOFI ALBI"
    /// Fișă veche pe alte firme; fallback dacă lipsește CARTOFI ALBI.
    nonisolated static let legacyWhitePotatoProductName = "CARTOFI ALBI IMP"
    /// Materie primă — rosii (RO / P / MC ciorchine etc.; nu e in catalog).
    nonisolated static let canonicalTomatoProductName = "ROSII"
    nonisolated static let legacyTomatoProductName = "ROSII RO"
    nonisolated static let canonicalKapiaProductName = "ARDEI KAPIA ROSU"
    /// Materie primă — castraveți proaspeți (Fabio / variante factură; nu murături; nu e în catalog).
    nonisolated static let canonicalFreshCucumberProductName = "CASTRAVETI FABIO"
    /// Materie primă — castraveți murați (nu proaspeți; nu e în catalog).
    nonisolated static let canonicalPickledCucumberProductName = "CASTRAVETI MURATI"
    /// Materie primă — ceapă galbenă / albă (10KG etc.; nu roșie / prăjită; nu e în catalog).
    nonisolated static let canonicalYellowOnionProductName = "CEAPA GALBENA"
    nonisolated static let legacyYellowOnionProductName = "CEAPA GALBENA 10KG"
    /// Materie primă — ceapă prăjită / fulgi (nu galbenă crudă; nu e în catalog).
    nonisolated static let canonicalFriedOnionProductName = "CEAPA PRAJITA"
    nonisolated static let legacyFriedOnionProductName = "270G MC CEAPA PRAJITA FULGI"
    /// Materie primă — ceapă roșie (nu galbenă / prăjită; nu e în catalog).
    nonisolated static let canonicalRedOnionProductName = "CEAPA ROSIE"
    /// Materie primă — aluat / pizza Ceko (2.3KG bax etc.; nu e în catalog).
    nonisolated static let canonicalCekoPizzaProductName = "CEKO PIZZA"
    nonisolated static let legacyCekoPizzaProductName = "CEKO PIZZA FIRST 2.3KG 4 BUC/BAX"
    /// Materie primă — chifle mari (nu chifle de tip produs finit; nu e în catalog).
    nonisolated static let canonicalChifleMariProductName = "CHIFLE MARI"
    /// Materie primă — doner vită tocat (LOT pe factură se unifică aici; nu e în catalog).
    nonisolated static let canonicalDonerVitaTocatProductName = "DONER VITA TOCAT"
    /// Materie primă — bait / batter pentru șnițel (BATTER 300 FS etc.; nu e în catalog).
    nonisolated static let canonicalBaitSnitelProductName = "BAIT SNITEL"
    nonisolated static let legacyBaitSnitelProductName = "BATTER 300 FS 1/10 KG"
    /// Materie primă — Condimix (Gustos 1/1 KG etc.; nu e în catalog).
    nonisolated static let canonicalCondimixProductName = "CONDIMIX"
    nonisolated static let legacyCondimixProductName = "CONDIMIX GUSTOS 1/1 KG"
    /// Materie primă — crustă crispy (ACG 1/10 KG etc.; nu e în catalog).
    nonisolated static let canonicalCrustaCrispyProductName = "CRUSTA CRISPY"
    nonisolated static let legacyCrustaCrispyProductName = "CRUSTA CRISPY ACG 1/10 KG"
    /// Materie primă — falafel 450G (Edenia etc.; nu produsul finit din catalog).
    nonisolated static let canonicalFalafel450ProductName = "FALAFEL 450G"
    nonisolated static let legacyFalafel450ProductName = "FALAFEL 450G EDENIA"
    /// Materie primă — Hot Marinade (seasoning 1/1 KG etc.; nu e în catalog).
    nonisolated static let canonicalHotMarinadeProductName = "HOT MARINADE"
    nonisolated static let legacyHotMarinadeProductName = "HOT MARINADE SEASONING 1/1 KG"
    /// Materie primă — lămâi (plasă 500G etc.; nu băuturi / detergent; nu e în catalog).
    nonisolated static let canonicalLemonProductName = "LAMAI"
    nonisolated static let legacyLemonProductName = "LAMAI PLASA 500G"
    /// Materie primă — chips Lay's sare (40G/BLT/BAX/DTS etc.; nu sare de bucatarie; nu e in catalog).
    nonisolated static let canonicalLaysSareProductName = "LAY'S SARE"
    nonisolated static let legacyLaysSareProductName = "LAY'S SARE 40G/60 10BUC/BLT 6BLT/BAX"
    /// Materie primă — lipie tip C 750G (nu tip 600G / pita; nu e in catalog).
    nonisolated static let canonicalLipieTipC750ProductName = "LIPIE TIP C 750G"
    /// Materie primă — mini bagheta 120GR (nu e in catalog).
    nonisolated static let canonicalMiniBagheta120ProductName = "MINI BAGHETA 120GR"
    /// Materie primă — patrunjel (nu e in catalog).
    nonisolated static let canonicalPatrunjelProductName = "PATRUNJEL"
    /// Materie primă — piept de pui dezosat cu piele (nu pulpe; nu e in catalog).
    nonisolated static let canonicalPieptPuiDezProductName = "PIEPT DE PUI DEZ CU PIELE"
    /// Materie primă — pulpe de pui dezosate cu piele (nu piept; nu e in catalog).
    nonisolated static let canonicalPulpePuiDezProductName = "PULPE DE PUI DEZOSATE CU PIELE"
    /// Materie primă — pita (nu lipie tip C / PITA EXTRA; nu e in catalog).
    nonisolated static let canonicalPitaProductName = "PITA"
    /// Materie primă — portocale (cod 103921). Aliasuri: PORTOCALE 3-5 P și PORTOCALE SUC. Nu băuturi. Nu e în catalog.
    nonisolated static let canonicalPortocaleProductName = "PORTOCALE"
    /// Nume de pe factură pentru portocale suc; se leagă pe PORTOCALE.
    nonisolated static let canonicalPortocaleSucProductName = "PORTOCALE SUC"
    /// Nume vechi al fișei; se leagă pe PORTOCALE.
    nonisolated static let legacyPortocaleProductName = "PORTOCALE 3-5 P"
    /// Materie primă — salata verde (nu salate finite; nu e in catalog).
    nonisolated static let canonicalSalataVerdeProductName = "SALATA VERDE"
    /// Catalog CM — bere sticlă 0.33 (promo/SGR Metro etc. se unifică aici).
    nonisolated static let canonicalCarlsberg033ProductName = "BERE CARLSBERG 0.33 L"
    /// Catalog CM — bere doză 0.5 (promo/SGR Metro etc. se unifică aici).
    nonisolated static let canonicalCarlsberg05DozaProductName = "BERE CARLSBERG DOZA 0.5 L"
    /// Catalog CM — Bere Bucur blondă 0.35 (promo/SGR etc. se unifică aici).
    nonisolated static let canonicalBereBucur035ProductName = "BERE BUCUR BLONDA 0.35 L"
    /// Catalog CM — Tuborg doză 0.5 (promo/SGR etc. se unifică aici).
    nonisolated static let canonicalTuborg05DozaProductName = "BERE TUBORG DOZA 0.5 L"
    /// Catalog CM — Tuborg sticlă 0.33 (promo/SGR etc. se unifică aici).
    nonisolated static let canonicalTuborg033ProductName = "BERE TUBORG ST. 0.33 L"
    /// Catalog CM — Granini 0.33 (promo/SGR / arome etc. se unifică aici).
    nonisolated static let canonicalGranini033ProductName = "GRANINI 0.33 L"
    /// Catalog CM — Lipton lămâie 0.5 L (ICE TEA LEMON / QAB etc.; nu piersici / 250ML).
    nonisolated static let canonicalLiptonLamaie05ProductName = "LIPTON LAMAIE 0.5 L"
    /// Catalog CM — Lipton piersici 0.5 L (ICE TEA PEACH / QAB etc.; nu lămâie / 250ML).
    nonisolated static let canonicalLiptonPiersici05ProductName = "LIPTON PIERSICI 0.5 L"
    /// Catalog CM — Mirinda Orange 0.5 L (PET / QAB etc.; nu doză 0.33).
    nonisolated static let canonicalMirindaOrange05ProductName = "MIRINDA ORANGE 0.5 L"
    /// Catalog CM — Mirinda Orange doză 0.33 L (CAN / QAB etc.; nu PET 0.5).
    nonisolated static let canonicalMirindaOrange033DozaProductName = "MIRINDA ORANGE DOZA 0.33 L"
    /// Catalog CM — Mountain Dew 0.5 L (PET / SGR etc. se unifică aici).
    nonisolated static let canonicalMountainDew05ProductName = "MOUNTAIN DEW 0.5 L"
    /// Catalog CM — Pepsi Cola 0.5 L (PET / QAB etc.; nu Twist / Zero / doză 0.33).
    nonisolated static let canonicalPepsiCola05ProductName = "PEPSI COLA 0.5 L"
    /// Catalog CM — Pepsi Cola doză 0.33 L (CAN / QAB etc.; nu PET 0.5 / Twist / Zero).
    nonisolated static let canonicalPepsiCola033DozaProductName = "PEPSI COLA DOZA 0.33 L"
    /// Catalog CM — Pepsi Twist 0.5 L (PET / QAB etc.; nu Cola / Zero / doză).
    nonisolated static let canonicalPepsiTwist05ProductName = "PEPSI TWIST 0.5 L"
    /// Catalog CM — Pepsi Zero 0.5 L (PET / QAB etc.; nu Cola / Twist / Vanilie 330).
    nonisolated static let canonicalPepsiZero05ProductName = "PEPSI ZERO 0.5 L"
    /// Pepsi Zero Vanilie 0.33 L (CAN / DRS etc.; nu e în catalog; nu Zero 0.5).
    nonisolated static let canonicalPepsiZeroVanilie033ProductName = "PEPSI ZERO VANILIE 0.33 L"
    /// Catalog CM — 7UP Lemon Lime 0.5 L (promo/SGR etc. se unifică aici).
    nonisolated static let canonicalSevenUp05ProductName = "7UP LEMON LIME 0.5 L"
    /// Catalog CM — aqua minerala 0.5 L (carbo/SGR etc.; nu plata; se unifică aici).
    nonisolated static let canonicalAquaMinerala05ProductName = "AQUA MINERALA 0.5 L"
    /// Catalog CM — aqua plata 0.5 L (SGR etc.; nu minerala/carbo; se unifică aici).
    nonisolated static let canonicalAquaPlata05ProductName = "AQUA PLATA 0.5 L"
    /// Catalog CM — ayran (variante factură se unifică aici).
    nonisolated static let canonicalAyranProductName = "AYRAN"
    /// Materie primă — ulei floarea-soarelui (ULEI FL… / MC etc. se unifică aici; nu e în catalog).
    nonisolated static let canonicalSunflowerOilProductName = "ULEI FLOAREA SOARELUI"
    /// Catalog CM — Ursus Cooler 0.5 (A.URSUS Cooler… se unifică aici).
    nonisolated static let canonicalUrsusCooler05ProductName = "URSUS Cooler 0.5 L"
    /// Materie primă — boia dulce (1KG ARO… etc. se unifică aici; nu e în catalog).
    nonisolated static let canonicalBoiaDulceProductName = "BOIA DULCE"
    nonisolated static let legacyBoiaDulceProductName = "1KG ARO BOIA DULCE"
    /// Materie primă — făină albă tip 000 (1KG ARO FAINA 000 etc.; nu e în catalog).
    nonisolated static let canonicalFainaProductName = "FAINA"
    nonisolated static let legacyFainaProductName = "1KG ARO FAINA 000"
    /// Materie primă — piper negru măcinat (1000G ARO… etc.; nu e în catalog).
    nonisolated static let canonicalPiperNegruMacinatProductName = "PIPER NEGRU MACINAT"
    nonisolated static let legacyPiperNegruMacinatProductName = "1000G ARO PIPER NEGRU MACINAT"
    /// Materie primă — ketchup dulce (10KG ARO… etc.; nu e în catalog).
    nonisolated static let canonicalKetchupDulceProductName = "KETCHUP DULCE"
    nonisolated static let legacyKetchupDulceProductName = "10KG ARO KETCHUP DULCE"
    /// Materie primă — oregano (110G MC… etc.; nu e în catalog).
    nonisolated static let canonicalOreganoProductName = "OREGANO"
    nonisolated static let legacyOreganoProductName = "110G MC OREGANO MARUNTIT"
    /// Materie primă — sare (1KG SALROM… etc.; nu e în catalog).
    nonisolated static let canonicalSareProductName = "SARE"
    nonisolated static let legacySareProductName = "1KG SALROM SARE IOD RECRIST"
    /// Materie primă — zahar (1KG ARO HT etc.; stoc Kg; nu e in catalog).
    nonisolated static let canonicalZaharProductName = "ZAHAR"
    nonisolated static let legacyZaharProductName = "1KG ARO ZAHAR HT"
    /// Materie primă — tortilla 27cm curcuma (nu e in catalog).
    nonisolated static let canonicalTortillaCurcumaProductName = "TORTILLA 27CM CURCUMA"
    /// Materie primă — varza alba (noua etc.; nu rosie; nu e in catalog).
    nonisolated static let canonicalVarzaAlbaProductName = "VARZA ALBA"
    nonisolated static let legacyVarzaAlbaProductName = "VARZA NOUA"
    /// Materie primă — varza rosie (nu alba; nu e in catalog).
    nonisolated static let canonicalVarzaRosieProductName = "VARZA ROSIE"
    /// Materie primă — usturoi (1KG curățat etc.; nu e în catalog).
    nonisolated static let canonicalUsturoiProductName = "USTUROI"
    nonisolated static let legacyUsturoiProductName = "1KG USTUROI CURATAT"
    /// Materie primă — oțet (Bistrița OT etc.; nu e în catalog).
    nonisolated static let canonicalOtetProductName = "OTET"
    nonisolated static let legacyOtetProductName = "1L BISTRITA OT ALC+OT VIN 9G"
    /// Materie primă — curry (200G MC… etc.; nu e în catalog).
    nonisolated static let canonicalCurryProductName = "CURRY"
    nonisolated static let legacyCurryProductName = "200G MC CURRY"
    /// Materie primă — scorțișoară (200G MC… etc.; nu e în catalog).
    nonisolated static let canonicalScortisoaraProductName = "SCORTISOARA"
    nonisolated static let legacyScortisoaraProductName = "200G MC SCORTISOARA MACINAT"
    /// Materie primă — Delik'at (2KG legume / găină etc.; nu e în catalog).
    nonisolated static let canonicalDelikatProductName = "DELIKAT"
    nonisolated static let legacyDelikatProductName = "2KG DELIK'AT LEGUME"
    /// Materie primă — bulion (3.3KG SULTAN… etc.; nu e în catalog).
    nonisolated static let canonicalBulionProductName = "BULION"
    nonisolated static let legacyBulionProductName = "3.3KG SULTAN BULION 18%"
    /// Materie primă — măsline verzi cu gogoșari (3KG ARO… etc.; nu e în catalog).
    nonisolated static let canonicalMaslineVerziGogosariProductName = "MASLINE VERZI CU GOGOSARI"
    nonisolated static let legacyMaslineVerziGogosariProductName = "3KG ARO MASL VERZI+GOG181-200"
    /// Materie primă — Pakmaya drojdie (4×100G uscată etc.; nu e în catalog).
    nonisolated static let canonicalPakmayaDrojdieProductName = "PAKMAYA DROJDIE"
    nonisolated static let legacyPakmayaDrojdieProductName = "4X100G PAKMAYA DROJDIE USCATA"
    /// Materiale curățenie — soluție aragaz Triumf 3L.
    nonisolated static let canonicalSolutieAragazProductName = "3L TRIUMF SOLUTIE PT ARAGAZ"
    /// Materiale curățenie — detergent vase (FL lămâie).
    nonisolated static let canonicalDetergentVaseProductName = "500ML FL DETERGENT VASE LAMAIE"
    /// Materiale curățenie — spray aragaz Triumf.
    nonisolated static let canonicalSolAragazSprayProductName = "500ML TRIUMF SOL ARAGAZ SPRAY"
    /// Materie primă — maioneză (5KG MC SOS… etc.; nu e în catalog).
    nonisolated static let canonicalMaionezaProductName = "MAIONEZA"
    nonisolated static let legacyMaionezaProductName = "5KG MC SOS MAIONEZA"
    /// Materie primă — iaurt (5KG MC 10% etc.; nu e în catalog).
    nonisolated static let canonicalIaurtProductName = "IAURT"
    nonisolated static let legacyIaurtProductName = "5KG MC IAURT 10%"
    /// Materie primă — sos samurai (5KG UNIVER… etc.; nu e în catalog).
    nonisolated static let canonicalSosSamuraiProductName = "SOS SAMURAI"
    nonisolated static let legacySosSamuraiProductName = "5KG UNIVER SOS SAMURAI"
    /// Materie primă — sos cedar (galon 5 L etc.; stoc in Litru; nu e in catalog).
    nonisolated static let canonicalSosCedarProductName = "SOS CEDAR"
    nonisolated static let legacySosCedarProductName = "SOS CEDAR GAL 5 L"
    /// Materie primă — ulei de palmier (ALFA oleină etc.; nu e în catalog).
    nonisolated static let canonicalUleiPalmierProductName = "ULEI DE PALMIER"
    nonisolated static let legacyUleiPalmierProductName = "ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L"
    /// Materie primă — ardei iute (nu e în catalog).
    nonisolated static let canonicalArdeiIuteProductName = "ARDEI IUTE"
    /// Materie primă — aripi pui (marinate etc.; nu e în catalog).
    nonisolated static let canonicalAripiPuiProductName = "ARIPI PUI"
    nonisolated static let legacyAripiPuiProductName = "ARIPI MARINATE 1KG ED CHE"

    private static let client = SupabaseManager.client

    nonisolated static func isGarantieProductName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: garantieProductName, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }
        // Linii de ambalaj / depozit SGR pe factură (Amb. SGR …) → același master Garantie SGR
        let folded = foldedProductName(trimmed)
        if folded.hasPrefix("amb. sgr") || folded.hasPrefix("amb sgr") || folded.hasPrefix("ambalaj sgr") {
            return true
        }
        return false
    }

    nonisolated private static func foldedProductName(_ denumire: String) -> String {
        denumire
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
            .lowercased()
    }

    /// Cartofi materie primă din facturi (albi, noi, 10KG, MC…; nu dulci, congelați, pai etc.).
    nonisolated static func isFreshWhitePotatoImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("cartofi") else { return false }
        let excluded = [
            "rosii", "dulci", "congelat", "julienne", "mccain", "agristo",
            "cartofiori", "pai", "punga", "portii", "diferenta", "box cartofi"
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Roșii proaspete din facturi (RO, P, MC ciorchine etc.).
    nonisolated static func isFreshTomatoImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("rosii") else { return false }
        let excluded = ["sos", "pasta", "bulion", "ketchup", "conserv", "uscate"]
        return !excluded.contains(where: { folded.contains($0) })
    }

    /// Ardei kapia (roșu / fără calificativ).
    nonisolated static func isKapiaImportName(_ denumire: String) -> Bool {
        foldedProductName(denumire).contains("kapia")
    }

    /// Castraveți murați / murături din facturi (nu proaspeți Fabio).
    nonisolated static func isPickledCucumberImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPickledCucumberProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("castrav") || folded.contains("cucumber") || folded.contains("cornison") else {
            return false
        }
        return folded.contains("murat")
            || folded.contains("muratur")
            || folded.contains("pickl")
            || folded.contains("cornison")
    }

    /// Castraveți proaspeți din facturi (Fabio etc.); nu murături / conserve.
    nonisolated static func isFreshCucumberImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalFreshCucumberProductName) { return true }
        if isPickledCucumberImportName(denumire) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("castrav") || folded.contains("cucumber") else { return false }
        let excluded = ["conserve"]
        return !excluded.contains(where: { folded.contains($0) })
    }

    /// Pizza / aluat Ceko din facturi (FIRST 2.3KG etc.).
    nonisolated static func isCekoPizzaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalCekoPizzaProductName) { return true }
        if namesMatch(trimmed, legacyCekoPizzaProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ceko") else { return false }
        return folded.contains("pizza") || folded.contains("aluat")
    }

    /// Chifle mari (materie primă) din facturi; nu chifle de tip produs finit (pui/vită/sandwich).
    nonisolated static func isChifleMariImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalChifleMariProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("chifl") else { return false }
        let excluded = ["pui", "vita", "mixt", "sandwich", "snitel", "kebab", "falafel"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("mari") || folded.contains("mare")
    }

    /// Doner vită tocat din facturi (inclusiv sufix LOT…); nu pui.
    nonisolated static func isDonerVitaTocatImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalDonerVitaTocatProductName) { return true }
        let folded = foldedProductName(productNameIgnoringLot(trimmed))
        guard folded.contains("doner") || folded.contains("donner") || folded.contains("doener") else {
            return false
        }
        if folded.contains("pui") { return false }
        return (folded.contains("vita") || folded.contains("beef"))
            && (folded.contains("tocat") || folded.contains("tocata") || folded.contains("minced"))
    }

    /// Condimix din facturi (Gustos etc.).
    nonisolated static func isCondimixImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalCondimixProductName) { return true }
        if namesMatch(trimmed, legacyCondimixProductName) { return true }
        return foldedProductName(trimmed).contains("condimix")
    }

    /// Crustă crispy (materie primă) din facturi; nu meniuri crispy din catalog.
    nonisolated static func isCrustaCrispyImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalCrustaCrispyProductName) { return true }
        if namesMatch(trimmed, legacyCrustaCrispyProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("crusta") else { return false }
        let excluded = ["farfurie", "bucket", "shaorma", "shawarma", "meniu", "sandwich"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("crispy") || folded.contains("acg")
    }

    /// Falafel 450G (materie primă) din facturi; nu meniul finit „FALAFEL”.
    nonisolated static func isFalafel450ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalFalafel450ProductName) { return true }
        if namesMatch(trimmed, legacyFalafel450ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("falafel") else { return false }
        return folded.contains("450") || folded.contains("edenia")
    }

    /// Hot Marinade / seasoning din facturi.
    nonisolated static func isHotMarinadeImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalHotMarinadeProductName) { return true }
        if namesMatch(trimmed, legacyHotMarinadeProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("marinade") || folded.contains("marinada") else { return false }
        return folded.contains("hot") || folded.contains("seasoning") || folded.contains("iute")
    }

    /// Lămâi proaspete din facturi (plasă etc.); nu Lipton/7UP / detergent vase.
    nonisolated static func isLemonImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalLemonProductName) { return true }
        if namesMatch(trimmed, legacyLemonProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("lamai") || folded.contains("lamaie") || folded.contains("lemon") else {
            return false
        }
        let excluded = [
            "lipton", "7up", "ice tea", "icetea", "detergent", "vase", "pet", "can",
            "sgr", "bax", "drs", "ns ", "lime"
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Chips Lay's sare din facturi (40G / BLT / BAX / DTS); nu sare de bucatarie.
    nonisolated static func isLaysSareImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalLaysSareProductName) { return true }
        if namesMatch(trimmed, legacyLaysSareProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("sare") else { return false }
        return folded.contains("lay") || folded.contains("lays")
    }

    /// Lipie tip C 750G din facturi; nu tip 600G si nu pita.
    nonisolated static func isLipieTipC750ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalLipieTipC750ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("lipie") else { return false }
        if folded.contains("600") { return false }
        if folded.contains("pita") { return false }
        return folded.contains("tip c") || folded.contains("tipc") || folded.contains("750")
    }

    /// Mini bagheta 120GR din facturi.
    nonisolated static func isMiniBagheta120ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMiniBagheta120ProductName) { return true }
        let folded = foldedProductName(trimmed)
        let isBagheta = folded.contains("bagheta") || folded.contains("baghet") || folded.contains("baguette")
        guard isBagheta else { return false }
        return folded.contains("mini") || folded.contains("120")
    }

    /// Patrunjel din facturi (verde / legatura etc.).
    nonisolated static func isPatrunjelImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPatrunjelProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("patrunjel") || folded.contains("parsley")
    }

    /// Piept de pui dezosat (cu piele) din facturi; nu pulpe / farfurie / meniu.
    nonisolated static func isPieptPuiDezImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPieptPuiDezProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("piept") else { return false }
        let excluded = ["pulp", "farfurie", "sandwich", "meniu", "porție", "portie", "chifl", "shaorm"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("pui") || folded.contains("chicken") || folded.contains("breast")
    }

    /// Pulpe de pui dezosate (cu piele) din facturi; nu piept / farfurie / meniu.
    nonisolated static func isPulpePuiDezImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPulpePuiDezProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pulp") else { return false }
        let excluded = ["piept", "farfurie", "sandwich", "meniu", "porție", "portie", "chifl", "shaorm", "aripi"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("pui") || folded.contains("chicken") || folded.contains("thigh")
    }

    /// Pita din facturi; nu lipie tip C / tip 600G si nu PITA EXTRA (produs finit).
    nonisolated static func isPitaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPitaProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pita") else { return false }
        let excluded = ["lipie", "extra", "farfurie", "sandwich", "meniu", "porție", "portie", "chifl"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Salata verde / iceberg din facturi; nu salate finite (vinete, caesar etc.).
    nonisolated static func isSalataVerdeImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSalataVerdeProductName) { return true }
        let folded = foldedProductName(trimmed)
        let excluded = [
            "vinete", "boeuf", "ton", "caesar", "cesar", "fruct", "farfurie",
            "meniu", "sandwich", "porție", "portie", "sos", "dressing", "de "
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        if folded.contains("lettuce") || folded.contains("iceberg") { return true }
        guard folded.contains("salata") else { return false }
        return folded.contains("verde") || folded == "salata" || folded.hasPrefix("salata ")
    }

    /// Portocale suc din facturi; nu 3-5 P / Mirinda / Fanta etc.
    nonisolated static func isPortocaleSucImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPortocaleSucProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("portocal") || folded.contains("orange") else { return false }
        let drinkExcluded = [
            "mirinda", "fanta", "doza", "pet", "sgr", "bax",
            "lipton", "ice tea", "icetea", "farfurie", "meniu"
        ]
        if drinkExcluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("suc") || folded.contains("juice")
    }

    /// Portocale din facturi (inclusiv 3-5 P); nu PORTOCALE SUC / Mirinda / Fanta etc.
    nonisolated static func isPortocaleImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPortocaleProductName) { return true }
        if namesMatch(trimmed, legacyPortocaleProductName) { return true }
        if isPortocaleSucImportName(trimmed) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("portocal") || folded.contains("orange") else { return false }
        let excluded = [
            "suc", "juice", "mirinda", "fanta", "doza", "pet", "sgr", "bax",
            "lipton", "ice tea", "icetea", "farfurie", "meniu"
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Bait / batter pentru șnițel din facturi; nu produse finite tip șnițel / sandwich.
    nonisolated static func isBaitSnitelImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalBaitSnitelProductName) { return true }
        if namesMatch(trimmed, legacyBaitSnitelProductName) { return true }
        let folded = foldedProductName(trimmed)
        let excluded = ["farfurie", "sandwich", "chifl", "meniu", "porție", "portie"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        if folded.contains("bait") && (folded.contains("snit") || folded.contains("schnitzel")) {
            return true
        }
        if folded.contains("batter") {
            return folded.contains("300") || folded.contains("snit") || folded.contains("schnitzel") || folded.contains("fs")
        }
        return false
    }

    /// Ceapă roșie din facturi (nu galbenă / prăjită).
    nonisolated static func isRedOnionImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalRedOnionProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ceap") || folded.contains("onion") else { return false }
        if folded.contains("prajit") || folded.contains("fulgi") || folded.contains("fried") || folded.contains("croc") {
            return false
        }
        return folded.contains("rosie") || folded.contains("rosu") || folded.contains("red")
    }

    /// Ceapă prăjită / fulgi / crocantă din facturi (nu crudă galbenă / roșie).
    nonisolated static func isFriedOnionImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalFriedOnionProductName) { return true }
        if namesMatch(trimmed, legacyFriedOnionProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ceap") || folded.contains("onion") else { return false }
        return folded.contains("prajit")
            || folded.contains("fulgi")
            || folded.contains("fried")
            || folded.contains("croc")
    }

    /// Ceapă galbenă / albă din facturi; nu roșie, prăjită, caramelizată.
    nonisolated static func isYellowOnionImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalYellowOnionProductName) { return true }
        if namesMatch(trimmed, legacyYellowOnionProductName) { return true }
        if isFriedOnionImportName(denumire) { return false }
        if isRedOnionImportName(denumire) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ceap") || folded.contains("onion") else { return false }
        let excluded = [
            "rosie", "rosu", "red", "prajit", "caramel", "fulgi", "verde", "green", "ardei", "croc"
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Variante furnizor / promo SGR pentru Carlsberg 0.33 (nu doza 0.5).
    nonisolated static func isCarlsberg033ImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("carlsb") || folded.contains("carlsberg") else { return false }
        if folded.contains("0.5") || folded.contains("0,5") { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("0.33st")
            || folded.contains("0.33l")
    }

    /// Variante furnizor / promo SGR pentru Carlsberg doză 0.5 (nu sticlă 0.33).
    nonisolated static func isCarlsberg05DozaImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("carlsb") || folded.contains("carlsberg") else { return false }
        if folded.contains("0.33") || folded.contains("0,33") { return false }
        let isHalf = folded.contains("0.5") || folded.contains("0,5") || folded.contains("0.5dz")
        guard isHalf else { return false }
        // Doză / can / DZ; exclude accidental non-beer if ever needed
        return folded.contains("dz")
            || folded.contains("doza")
            || folded.contains("can")
            || folded.contains("promo")
            || namesMatch(denumire, canonicalCarlsberg05DozaProductName)
    }

    /// Variante furnizor / promo SGR pentru Bere Bucur blondă 0.35.
    nonisolated static func isBereBucur035ImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("bucur") else { return false }
        guard folded.contains("0.35") || folded.contains("0,35") else { return false }
        return folded.contains("blond")
            || folded.contains("blonda")
            || namesMatch(denumire, canonicalBereBucur035ProductName)
    }

    /// Variante furnizor / promo SGR pentru Tuborg doză 0.5 (nu sticlă 0.33).
    nonisolated static func isTuborg05DozaImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("tuborg") else { return false }
        if folded.contains("0.33") || folded.contains("0,33") { return false }
        let isHalf = folded.contains("0.5") || folded.contains("0,5") || folded.contains("0.5l")
        guard isHalf else { return false }
        return folded.contains("dz")
            || folded.contains("doza")
            || folded.contains("promo")
            || folded.contains("sgr")
            || namesMatch(denumire, canonicalTuborg05DozaProductName)
    }

    /// Variante furnizor / promo SGR pentru Tuborg sticlă 0.33 (nu doză 0.5).
    nonisolated static func isTuborg033ImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("tuborg") else { return false }
        if folded.contains("0.5") || folded.contains("0,5") { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("0.33st")
            || folded.contains("0.33l")
            || namesMatch(denumire, canonicalTuborg033ProductName)
    }

    /// Variante furnizor / promo SGR pentru Granini 0.33 (orice aromă după prefix).
    nonisolated static func isGranini033ImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("granini") else { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("0.33l")
            || namesMatch(denumire, canonicalGranini033ProductName)
    }

    /// Lipton lămâie / lemon ice tea 0.5 L; nu piersici / peach / 250ML.
    nonisolated static func isLiptonLamaie05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalLiptonLamaie05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("lipton") else { return false }
        if folded.contains("piersic") || folded.contains("peach") { return false }
        if folded.contains("250") || folded.contains("0.25") || folded.contains("0,25") { return false }
        let isLemon = folded.contains("lamaie") || folded.contains("lemon")
        guard isLemon else { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
    }

    /// Lipton piersici / peach ice tea 0.5 L; nu lămâie / lemon / 250ML.
    nonisolated static func isLiptonPiersici05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalLiptonPiersici05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("lipton") else { return false }
        if folded.contains("lamaie") || folded.contains("lemon") { return false }
        if folded.contains("250") || folded.contains("0.25") || folded.contains("0,25") { return false }
        let isPeach = folded.contains("piersic") || folded.contains("peach")
        guard isPeach else { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
    }

    /// Mirinda Orange 0.5 L PET / QAB; nu doză 0.33 / 330ML.
    nonisolated static func isMirindaOrange05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMirindaOrange05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("mirinda") else { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("330") { return false }
        if folded.contains("doza") || folded.contains("can") { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
            || namesMatch(denumire, canonicalMirindaOrange05ProductName)
    }

    /// Mirinda Orange doză / can 0.33 L; nu PET 0.5.
    nonisolated static func isMirindaOrange033DozaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMirindaOrange033DozaProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("mirinda") else { return false }
        if folded.contains("0.5") || folded.contains("0,5") || folded.contains("500") { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("330")
            || folded.contains("doza")
            || folded.contains("can")
    }

    /// Mountain Dew / MTN Dew 0.5 L; nu 0.33 / 1.5.
    nonisolated static func isMountainDew05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMountainDew05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        let isDew = (folded.contains("mountain") && folded.contains("dew"))
            || folded.contains("mtn dew")
            || folded.contains("mtndew")
        guard isDew else { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("330") { return false }
        if folded.contains("1.5") || folded.contains("1,5") || folded.contains("2l") { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
            || namesMatch(denumire, canonicalMountainDew05ProductName)
    }

    /// Pepsi Cola 0.5 L PET / QAB; nu Twist / Zero / doză 0.33.
    nonisolated static func isPepsiCola05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPepsiCola05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pepsi") else { return false }
        if folded.contains("twist") || folded.contains("zero") || folded.contains("max") { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("330") { return false }
        if folded.contains("doza") || folded.contains("can") { return false }
        let isHalf = folded.contains("0.5") || folded.contains("0,5") || folded.contains("500") || folded.contains("0.5l")
        guard isHalf else { return false }
        return folded.contains("cola") || namesMatch(denumire, canonicalPepsiCola05ProductName)
    }

    /// Pepsi Cola doză / can 0.33 L; nu PET 0.5 / Twist / Zero.
    nonisolated static func isPepsiCola033DozaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPepsiCola033DozaProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pepsi") else { return false }
        if folded.contains("twist") || folded.contains("zero") || folded.contains("max") { return false }
        if folded.contains("0.5") || folded.contains("0,5") || folded.contains("500") { return false }
        guard folded.contains("cola") else { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("330")
            || folded.contains("doza")
            || folded.contains("can")
    }

    /// Pepsi Twist 0.5 L PET / QAB; nu Cola / Zero / doză 0.33.
    nonisolated static func isPepsiTwist05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPepsiTwist05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pepsi") && folded.contains("twist") else { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("330") { return false }
        if folded.contains("doza") || folded.contains("can") { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
            || namesMatch(denumire, canonicalPepsiTwist05ProductName)
    }

    /// Pepsi Zero 0.5 L PET / QAB; nu Cola / Twist / Vanilie 330 / doză.
    nonisolated static func isPepsiZero05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPepsiZero05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pepsi") && folded.contains("zero") else { return false }
        if folded.contains("twist") { return false }
        if folded.contains("vanil") || folded.contains("vanilla") { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("330") { return false }
        if folded.contains("doza") || folded.contains("can") { return false }
        return folded.contains("0.5")
            || folded.contains("0,5")
            || folded.contains("500")
            || folded.contains("0.5l")
            || namesMatch(denumire, canonicalPepsiZero05ProductName)
    }

    /// Pepsi Zero Vanilie / Vanilla 0.33 L; nu Zero 0.5 PET.
    nonisolated static func isPepsiZeroVanilie033ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPepsiZeroVanilie033ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("pepsi") && folded.contains("zero") else { return false }
        if folded.contains("0.5") || folded.contains("0,5") || folded.contains("500") { return false }
        let isVanilla = folded.contains("vanil") || folded.contains("vanilla")
        guard isVanilla else { return false }
        return folded.contains("0.33")
            || folded.contains("0,33")
            || folded.contains("330")
            || folded.contains("doza")
            || folded.contains("can")
    }

    /// Variante furnizor / promo SGR pentru 7UP Lemon Lime 0.5 L.
    nonisolated static func isSevenUp05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSevenUp05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        let isSevenUp = folded.contains("7up") || folded.contains("7 up") || folded.contains("seven up") || folded.contains("sevenup")
        guard isSevenUp else { return false }
        if folded.contains("0.33") || folded.contains("0,33") || folded.contains("1.5") || folded.contains("2l") {
            return false
        }
        return folded.contains("0.5") || folded.contains("0,5") || folded.contains("lemon") || folded.contains("lime")
    }

    /// Aqua minerala / carbo 0.5 L din facturi; nu aqua plata / Red Com.
    nonisolated static func isAquaMinerala05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalAquaMinerala05ProductName) { return true }
        if isAquaPlata05ImportName(trimmed) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("aqua") || folded.contains("mineral") else { return false }
        let excluded = ["plata", "flat", "still", "red com", "com jun", "com jul", "com aug"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        let isHalf = folded.contains("0.5") || folded.contains("0,5")
        guard isHalf || namesMatch(trimmed, canonicalAquaMinerala05ProductName) else { return false }
        return folded.contains("mineral") || folded.contains("carbo") || folded.contains("sparkling")
    }

    /// Ayran din facturi (airan etc.); nu iaurt / farfurie.
    nonisolated static func isAyranImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalAyranProductName) { return true }
        let folded = foldedProductName(trimmed)
        let excluded = ["iaurt", "yogurt", "yoghurt", "farfurie", "meniu"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("ayran") || folded.contains("airan")
    }

    /// Aqua plata 0.5 L din facturi; nu minerala / carbo / Red Com / 1 L.
    nonisolated static func isAquaPlata05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalAquaPlata05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("aqua") else { return false }
        let excluded = [
            "mineral", "carbo", "sparkling", "red com", "com jun", "com jul", "com aug",
            "1l ", "1 l", "1l a"
        ]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        // „1L AQUA…” la început
        if folded.hasPrefix("1l ") || folded.hasPrefix("1 l ") { return false }
        let isHalf = folded.contains("0.5") || folded.contains("0,5")
        guard isHalf else { return false }
        return folded.contains("plata") || folded.contains("flat") || folded.contains("still")
    }

    /// Variante furnizor pentru ulei floarea-soarelui (ULEI FL…, MC ULEI FLOAREA SOARELUI etc.).
    /// Nu include ulei de palmier, măsline, picant etc.
    nonisolated static func isSunflowerOilImportName(_ denumire: String) -> Bool {
        let folded = foldedProductName(denumire)
        guard folded.contains("ulei") else { return false }
        let excluded = ["palmier", "palm", "oleina", "maslin", "olive", "cocos", "rapita", "picant"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        if namesMatch(denumire, canonicalSunflowerOilProductName) { return true }
        if folded.contains("floarea soarelui") || folded.contains("floarea-soarelui") {
            return true
        }
        // Abreviere tip „ULEI FL” / „ULEI FL SOARE” (nu „floarea…” ca un singur cuvânt).
        return folded.range(
            of: #"\bulei\s*fl\b"#,
            options: .regularExpression
        ) != nil
    }

    /// Variante furnizor / SGR pentru Ursus Cooler 0.5 (prefix A.URSUS Cooler…).
    nonisolated static func isUrsusCooler05ImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalUrsusCooler05ProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ursus") && folded.contains("cooler") else { return false }
        if folded.hasPrefix("a.ursus cooler") || folded.hasPrefix("a.ursuscooler") {
            return true
        }
        return folded.contains("0.5") || folded.contains("0,5")
    }

    /// Boia dulce din facturi (ARO 1KG etc.; nu iute / afumată).
    nonisolated static func isBoiaDulceImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalBoiaDulceProductName) { return true }
        if namesMatch(trimmed, legacyBoiaDulceProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("boia") else { return false }
        let excluded = ["iute", "afumat", "picant", "chili"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("dulce")
    }

    /// Făină albă tip 000 / ARO din facturi (nu porumb, integrală, graham etc.).
    nonisolated static func isFainaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalFainaProductName) { return true }
        if namesMatch(trimmed, legacyFainaProductName) { return true }
        if namesMatch(trimmed, "faina") { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("faina") else { return false }
        let excluded = ["porumb", "orez", "malai", "graham", "integral", "spelta", "secara", "neagra"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        if folded.contains("000") { return true }
        if folded.contains("aro") { return true }
        // Denumire scurtă tip „FAINA” / „faina alba”
        return folded == "faina" || folded == "faina alba" || folded.hasPrefix("faina alba")
    }

    /// Piper negru măcinat din facturi (ARO 1000G etc.; nu verde / boabe / cuburi).
    nonisolated static func isPiperNegruMacinatImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPiperNegruMacinatProductName) { return true }
        if namesMatch(trimmed, legacyPiperNegruMacinatProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("piper") else { return false }
        let excluded = ["verde", "boabe", "bob", "alb", "cayenne", "chili", "iute", "cub"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        guard folded.contains("negru") else { return false }
        return folded.contains("macinat") || folded.contains("macinata")
    }

    /// Ketchup dulce din facturi (ARO 10KG etc.; nu iute / picant).
    nonisolated static func isKetchupDulceImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalKetchupDulceProductName) { return true }
        if namesMatch(trimmed, legacyKetchupDulceProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ketchup") else { return false }
        let excluded = ["iute", "picant", "spicy", "bbq", "barbecue"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("dulce")
    }

    /// Oregano din facturi (MC 110G mărunțit etc.).
    nonisolated static func isOreganoImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalOreganoProductName) { return true }
        if namesMatch(trimmed, legacyOreganoProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("oregano")
    }

    /// Sare de bucătărie din facturi (SALROM iodată etc.; nu chips Lay's).
    nonisolated static func isSareImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSareProductName) { return true }
        if namesMatch(trimmed, legacySareProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("sare") else { return false }
        let excluded = ["lay", "chips", "blt", "bax", "snack", "cartofi", "zahar"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        // Denumire scurtă „SARE” / „Sare”
        if folded == "sare" { return true }
        return folded.contains("salrom")
            || folded.contains("iod")
            || folded.contains("recrist")
            || folded.contains("fin")
            || folded.contains("grosiera")
            || folded.contains("marina")
    }

    /// Zahar din facturi (ARO HT etc.); stoc Kg.
    nonisolated static func isZaharImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalZaharProductName) { return true }
        if namesMatch(trimmed, legacyZaharProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("zahar") || folded.contains("sugar")
    }

    /// Tortilla 27cm curcuma din facturi; nu farfurie / meniu.
    nonisolated static func isTortillaCurcumaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalTortillaCurcumaProductName) { return true }
        let folded = foldedProductName(trimmed)
        let isTortilla = folded.contains("tortilla") || folded.contains("tortillia") || folded.contains("tortiya")
        guard isTortilla else { return false }
        let excluded = ["farfurie", "meniu", "sandwich", "porție", "portie", "wrap meniu"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("curcuma") || folded.contains("turmeric") || folded.contains("27")
            || folded == "tortilla" || folded == "tortillia"
    }

    /// Varza alba / noua din facturi; nu varza rosie / murata / farfurie.
    nonisolated static func isVarzaAlbaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalVarzaAlbaProductName) { return true }
        if namesMatch(trimmed, legacyVarzaAlbaProductName) { return true }
        if isVarzaRosieImportName(trimmed) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("varza") || folded.contains("cabbage") else { return false }
        let excluded = ["rosie", "red", "murat", "farfurie", "meniu", "salata"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("alba") || folded.contains("noua") || folded.contains("white")
            || folded == "varza"
    }

    /// Varza rosie din facturi; nu varza alba / murata / farfurie.
    nonisolated static func isVarzaRosieImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalVarzaRosieProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("varza") || folded.contains("cabbage") else { return false }
        let excluded = ["alba", "noua", "white", "murat", "farfurie", "meniu", "salata"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("rosie") || folded.contains("red")
    }

    /// Usturoi (curățat) din facturi; nu sos / maioneză cu usturoi.
    nonisolated static func isUsturoiImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalUsturoiProductName) { return true }
        if namesMatch(trimmed, legacyUsturoiProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("usturoi") else { return false }
        let excluded = ["sos", "maioneza", "maionez", "reteta", "libanez"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return true
    }

    /// Oțet din facturi (Bistrița OT alcool / vin etc.).
    nonisolated static func isOtetImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalOtetProductName) { return true }
        if namesMatch(trimmed, legacyOtetProductName) { return true }
        let folded = foldedProductName(trimmed)
        if folded == "otet" || folded.contains("otet") { return true }
        // Abreviere tip „OT ALC” / „OT VIN” pe facturi Bistrița
        if folded.contains("bistrita") && (folded.contains("ot alc") || folded.contains("ot vin") || folded.contains("ot alc+ot vin")) {
            return true
        }
        return false
    }

    /// Curry (condiment) din facturi; nu sos curry.
    nonisolated static func isCurryImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalCurryProductName) { return true }
        if namesMatch(trimmed, legacyCurryProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("curry") else { return false }
        if folded.contains("sos") { return false }
        return true
    }

    /// Scorțișoară din facturi (MC măcinată etc.).
    nonisolated static func isScortisoaraImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalScortisoaraProductName) { return true }
        if namesMatch(trimmed, legacyScortisoaraProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("scortisoar")
    }

    /// Delik'at din facturi (legume / găină → același master DELIKAT).
    nonisolated static func isDelikatImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalDelikatProductName) { return true }
        if namesMatch(trimmed, legacyDelikatProductName) { return true }
        if namesMatch(trimmed, "750G DELIKAT GAINA") { return true }
        let folded = foldedProductName(trimmed)
            .replacingOccurrences(of: "'", with: "")
        return folded.contains("delikat")
    }

    /// Bulion de tomate din facturi (Sultan / ARO etc.).
    nonisolated static func isBulionImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalBulionProductName) { return true }
        if namesMatch(trimmed, legacyBulionProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("bulion")
    }

    /// Măsline verzi cu gogoșari din facturi (ARO MASL VERZI+GOG etc.).
    nonisolated static func isMaslineVerziGogosariImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMaslineVerziGogosariProductName) { return true }
        if namesMatch(trimmed, legacyMaslineVerziGogosariProductName) { return true }
        let folded = foldedProductName(trimmed)
            .replacingOccurrences(of: "+", with: " ")
        let hasMasline = folded.contains("masline") || folded.contains("masl")
        let hasVerzi = folded.contains("verzi") || folded.contains("verde")
        let hasGogosari = folded.contains("gogosar") || folded.contains("gog")
        return hasMasline && hasVerzi && hasGogosari
    }

    /// Pakmaya drojdie din facturi (uscată / proaspătă).
    nonisolated static func isPakmayaDrojdieImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalPakmayaDrojdieProductName) { return true }
        if namesMatch(trimmed, legacyPakmayaDrojdieProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("pakmaya") && folded.contains("drojdie")
    }

    /// Spray soluție aragaz (Triumf etc.) → Materiale curățenie.
    nonisolated static func isSolAragazSprayImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSolAragazSprayProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("aragaz") else { return false }
        guard folded.contains("spray") else { return false }
        return folded.contains("sol") || folded.contains("solutie") || folded.contains("triumf")
    }

    /// Soluție aragaz (bidon / fără spray) → Materiale curățenie.
    nonisolated static func isSolutieAragazImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSolutieAragazProductName) { return true }
        if isSolAragazSprayImportName(trimmed) { return false }
        let folded = foldedProductName(trimmed)
        guard folded.contains("aragaz") else { return false }
        return folded.contains("solutie")
            || folded.contains("solutie pt")
            || (folded.contains("sol") && folded.contains("triumf"))
    }

    /// Detergent vase → Materiale curățenie.
    nonisolated static func isDetergentVaseImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalDetergentVaseProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("detergent") else { return false }
        return folded.contains("vase") || folded.contains("vaselor") || folded.contains("lamaie")
    }

    /// Orice din familia Materiale curățenie (pentru tip la import / NIR).
    nonisolated static func isMaterialeCuratenieImportName(_ denumire: String) -> Bool {
        isSolAragazSprayImportName(denumire)
            || isSolutieAragazImportName(denumire)
            || isDetergentVaseImportName(denumire)
    }

    /// Tip implicit la creare din factură / NIR.
    nonisolated static func suggestedImportProductKind(for denumire: String) -> ProductKind {
        if isGarantieProductName(denumire) { return .garantie }
        if isMaterialeCuratenieImportName(denumire) { return .materialeCuratenie }
        return .materiePrima
    }

    /// Maioneză din facturi (MC / ARO / picantă / cu usturoi → același master MAIONEZA).
    nonisolated static func isMaionezaImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalMaionezaProductName) { return true }
        if namesMatch(trimmed, legacyMaionezaProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("maionez")
    }

    /// Iaurt din facturi (MC 10%, Olympus grecesc etc.).
    nonisolated static func isIaurtImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalIaurtProductName) { return true }
        if namesMatch(trimmed, legacyIaurtProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("iaurt") || folded.contains("iaourt") || folded.contains("yogurt") || folded.contains("yoghurt")
    }

    /// Sos samurai din facturi (UNIVER etc.) → materie primă (produsele finite nu se importă).
    nonisolated static func isSosSamuraiImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSosSamuraiProductName) { return true }
        if namesMatch(trimmed, legacySosSamuraiProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("samurai")
    }

    /// Sos cedar din facturi (galon 5 L etc.) → materie primă, stoc Litru.
    nonisolated static func isSosCedarImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalSosCedarProductName) { return true }
        if namesMatch(trimmed, legacySosCedarProductName) { return true }
        let folded = foldedProductName(trimmed)
        return folded.contains("cedar")
    }

    /// Ulei de palmier / oleină din facturi (nu floarea-soarelui).
    nonisolated static func isUleiPalmierImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalUleiPalmierProductName) { return true }
        if namesMatch(trimmed, legacyUleiPalmierProductName) { return true }
        let folded = foldedProductName(trimmed)
        if folded.contains("oleina") { return true }
        guard folded.contains("ulei") || folded.contains("oil") else { return false }
        return folded.contains("palmier") || folded.contains("palm")
    }

    /// Ardei iute din facturi (nu kapia / gras / gogoșar).
    nonisolated static func isArdeiIuteImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalArdeiIuteProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("ardei") else { return false }
        let excluded = ["kapia", "gras", "gogosar", "lung", "dulce"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("iute") || folded.contains("chili") || folded.contains("cayenne")
    }

    /// Aripi / aripioare pui din facturi (marinate etc.); nu farfurie / bucket (produs finit).
    nonisolated static func isAripiPuiImportName(_ denumire: String) -> Bool {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if namesMatch(trimmed, canonicalAripiPuiProductName) { return true }
        if namesMatch(trimmed, legacyAripiPuiProductName) { return true }
        let folded = foldedProductName(trimmed)
        guard folded.contains("aripi") || folded.contains("aripioar") else { return false }
        let excluded = ["farfurie", "bucket", "maxx"]
        if excluded.contains(where: { folded.contains($0) }) { return false }
        return folded.contains("pui") || folded.contains("marinate") || folded == "aripi" || folded == "aripioare"
    }

    static func resolvedProductName(for denumire: String) -> String {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        if isGarantieProductName(trimmed) { return garantieSGRProductName }
        return productNameIgnoringLot(trimmed)
    }

    /// Scoate sufixe de tip LOT / (LOT …) / (dată) din denumirea de pe factură.
    nonisolated static func productNameIgnoringLot(_ denumire: String) -> String {
        var name = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return name }

        let patterns = [
            #"\s*\(\s*LOT\s*[^)]*\)\s*$"#,
            #"\s+LOT\s+[A-Z0-9./_-]+\s*$"#,
            #"\s*\(\s*\d{6,8}\s*\)\s*$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
            }
        }

        name = name
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Uniformizează „18L” / „18 L” la final de denumire tip cutie
        if let regex = try? NSRegularExpression(pattern: #"(\d)\s*[Ll]\s*$"#, options: []) {
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "$1 L")
        }
        return name
    }

    /// Produsul „Garantie SGR” din catalog, folosit doar pentru liniile de garanție.
    nonisolated static func isCanonicalGarantieSGRProduct(_ product: Product) -> Bool {
        product.denumire.localizedCaseInsensitiveCompare(garantieSGRProductName) == .orderedSame
    }

    /// Factura a legat greșit produsul (ex. băuturi „DOZA SGR”) la articolul Garantie SGR.
    nonisolated static func isMislinkedGarantieSGRProduct(_ product: Product, lineName: String) -> Bool {
        isCanonicalGarantieSGRProduct(product) && !isGarantieProductName(lineName)
    }

    nonisolated static func resolvedProductForNIRLine(
        line: SupplierInvoiceLine,
        productsById: [UUID: Product],
        allProducts: [Product] = []
    ) -> Product? {
        guard let linked = productsById[line.productId] else {
            return nil
        }

        guard isMislinkedGarantieSGRProduct(linked, lineName: line.denumire) else {
            return linked
        }

        let trimmedName = line.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = EFacturaUnitCode.normalize(line.unitateMasura)
        if let match = allProducts.first(where: {
            $0.denumire.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
                && (
                    EFacturaUnitCode.normalize($0.unitateMasura) == trimmedUnit
                    || StockUnitConversion.matchesPurchaseUnit($0, invoiceUnit: trimmedUnit)
                )
        }) {
            return match
        }

        return linked
    }

    static func fetchProducts(
        companyId: UUID,
        inCatalog: Bool? = nil,
        inStockSheet: Bool? = nil,
        hasRecipe: Bool? = nil,
        tip: ProductKind? = nil
    ) async throws -> [Product] {
        return try await SupabasePaging.fetchAll { from, to in
            var query = client
                .from("products")
                .select()
                .eq("company_id", value: companyId.uuidString)
                .eq("is_active", value: true)

            if let inCatalog {
                query = query.eq("in_catalog", value: inCatalog)
            }
            if let inStockSheet {
                query = query.eq("in_stock_sheet", value: inStockSheet)
            }
            if let hasRecipe {
                query = query.eq("has_recipe", value: hasRecipe)
            }
            if let tip {
                query = query.eq("tip", value: tip.rawValue)
            }

            return try await query
                .order("denumire", ascending: true)
                .order("id", ascending: true)
                .range(from: from, to: to)
                .execute()
                .value
        }
    }

    static func fetchProducts(ids: [UUID]) async throws -> [Product] {
        let uniqueIds = Array(Set(ids))
        guard !uniqueIds.isEmpty else { return [] }
        var all: [Product] = []
        for chunk in uniqueIds.chunked(into: 200) {
            let rows: [Product] = try await client
                .from("products")
                .select()
                .in("id", values: chunk.map(\.uuidString))
                .execute()
                .value
            all.append(contentsOf: rows)
        }
        return all
    }

    static func fetchProduct(id: UUID) async throws -> Product {
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func updateCatalogSettings(
        productId: UUID,
        inCatalog: Bool? = nil,
        inStockSheet: Bool? = nil,
        hasRecipe: Bool? = nil
    ) async throws -> Product {
        let payload = ProductCatalogSettingsPatch(
            inCatalog: inCatalog,
            inStockSheet: inStockSheet,
            hasRecipe: hasRecipe
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func updateImage(productId: UUID, imagineUrl: String?) async throws -> Product {
        let payload = ProductImagePatch(imagineUrl: emptyToNil(imagineUrl))
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func uploadImage(
        companyId: UUID,
        productId: UUID,
        imageData: Data,
        contentType: String,
        previousImagineUrl: String?
    ) async throws -> Product {
        await ProductImageService.deleteIfStored(previousImagineUrl)
        let publicURL = try await ProductImageService.upload(
            companyId: companyId,
            productId: productId,
            imageData: imageData,
            contentType: contentType
        )
        return try await updateImage(productId: productId, imagineUrl: publicURL)
    }

    static func removeImage(productId: UUID, imagineUrl: String?) async throws -> Product {
        await ProductImageService.deleteIfStored(imagineUrl)
        return try await updateImage(productId: productId, imagineUrl: nil)
    }

    static func updateDetails(
        productId: UUID,
        companyId: UUID,
        input: ProductUpdateInput
    ) async throws -> Product {
        let trimmedName = input.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProductCreateError.missingName }

        if let barcode = normalizedBarcode(input.codBare),
           let existing = try await findProductByBarcode(companyId: companyId, barcode: barcode),
           existing.id != productId {
            throw ProductCreateError.duplicateBarcode(barcode)
        }

        let trimmedCode = input.cod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedCode.isEmpty else { throw ProductCreateError.missingCode }
        if let existing = try await findProductByCode(companyId: companyId, code: trimmedCode),
           existing.id != productId {
            throw ProductCreateError.duplicateCode(trimmedCode)
        }

        let minQty = input.tip == .produsFinit ? 0 : max(0, input.cantitateMinima)
        let optimalQty = input.tip == .produsFinit ? 0 : max(0, input.cantitateOptima)
        let payload = ProductDetailsPatch(
            denumire: resolvedProductName(for: trimmedName),
            cod: trimmedCode,
            codBare: normalizedBarcode(input.codBare),
            unitateMasura: normalizedUnit(input.unitateMasura),
            unitateAchizitie: emptyToNil(input.unitateAchizitie).map { normalizedUnit($0) },
            factorConversie: input.factorConversie > 0 ? input.factorConversie : 1,
            tip: input.tip.rawValue,
            cantitateMinima: minQty,
            cantitateOptima: optimalQty
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func deletionBlocker(productId: UUID) async throws -> ProductDeleteBlocker? {
        struct IdRow: Decodable { let id: UUID }

        let movements: [IdRow] = try await client
            .from("stock_movements")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !movements.isEmpty { return .hasStockMovements }

        let invoiceLines: [IdRow] = try await client
            .from("supplier_invoice_lines")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !invoiceLines.isEmpty { return .hasInvoiceLines }

        let inventoryLines: [IdRow] = try await client
            .from("physical_inventory_lines")
            .select("id")
            .eq("product_id", value: productId.uuidString)
            .limit(1)
            .execute()
            .value
        if !inventoryLines.isEmpty { return .hasPhysicalInventoryLines }

        return nil
    }

    static func deleteProduct(productId: UUID) async throws {
        if let blocker = try await deletionBlocker(productId: productId) {
            throw ProductDeleteError.blocked(blocker)
        }
        try await client
            .from("products")
            .delete()
            .eq("id", value: productId.uuidString)
            .execute()
    }

    static func lookup(forBarcode barcode: String) async -> BarcodeProductLookup? {
        guard let normalized = normalizedBarcode(barcode) else { return nil }
        return await BarcodeLookupService.lookup(barcode: normalized)
    }

    static func lookupName(forBarcode barcode: String) async -> String? {
        await lookup(forBarcode: barcode)?.resolvedName
    }

    static func lookupImageOnline(name: String, barcode: String?) async -> String? {
        await ProductImageLookupService.findBestImage(name: name, barcode: barcode)
    }

    static func updateArticleCategory(productId: UUID, tip: ProductKind) async throws -> Product {
        let payload = ProductArticleCategoryPatch(
            tip: tip.rawValue,
            inCatalog: tip.impliesInCatalog ? true : nil
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        if let product = rows.first {
            return product
        }
        return try await fetchProduct(id: productId)
    }

    static func updateKind(productId: UUID, tip: ProductKind) async throws -> Product {
        try await updateArticleCategory(productId: productId, tip: tip)
    }

    static func updatePricing(
        productId: UUID,
        cotaTva: Decimal? = nil,
        pretVanzare: Decimal? = nil,
        pretVanzareOnline: Decimal? = nil,
        pretAchizitie: Decimal? = nil,
        updatesPurchasePrice: Bool = false,
        isVatPayer: Bool
    ) async throws -> Product {
        var validatedVat: Decimal?
        if let cotaTva {
            guard let value = validateVatRate(cotaTva, isVatPayer: isVatPayer) else {
                throw ProductCreateError.invalidVatRate
            }
            validatedVat = value
        }
        let payload = ProductPricingPatch(
            cotaTva: validatedVat,
            pretVanzare: pretVanzare,
            pretVanzareOnline: pretVanzareOnline,
            pretAchizitie: pretAchizitie,
            includePurchasePrice: updatesPurchasePrice
        )
        let rows: [Product] = try await client
            .from("products")
            .update(payload)
            .eq("id", value: productId.uuidString)
            .select()
            .execute()
            .value
        if let product = rows.first {
            return product
        }
        return try await fetchProduct(id: productId)
    }

    static func setAllProductsVatRate(companyId: UUID, cotaTva: Decimal) async throws {
        let rate = roundCurrency(cotaTva)
        struct Patch: Encodable {
            let cotaTva: Decimal
            enum CodingKeys: String, CodingKey {
                case cotaTva = "cota_tva"
            }
        }
        try await client
            .from("products")
            .update(Patch(cotaTva: rate))
            .eq("company_id", value: companyId.uuidString)
            .execute()
    }

    static func parseVatRate(_ text: String, isVatPayer: Bool) -> Decimal? {
        guard let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 2) else { return nil }
        guard ProductVATRates.isValidRate(roundCurrency(value), isVatPayer: isVatPayer) else { return nil }
        return roundCurrency(value)
    }

    static func validateVatRate(_ rate: Decimal, isVatPayer: Bool) -> Decimal? {
        let rounded = roundCurrency(rate)
        guard ProductVATRates.isValidRate(rounded, isVatPayer: isVatPayer) else { return nil }
        return rounded
    }

    static func defaultVatRate(isVatPayer: Bool) -> Decimal {
        ProductVATRates.defaultRate(isVatPayer: isVatPayer)
    }

    static func parseSalePrice(_ text: String) -> Decimal? {
        guard let value = SupplierFormatting.parseAmount(text, maxFractionDigits: 4) else { return nil }
        guard value >= 0 else { return nil }
        return roundCurrency(value)
    }

    static func roundCurrency(_ value: Decimal) -> Decimal {
        var input = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded
    }

    static func findProductByBarcode(companyId: UUID, barcode: String) async throws -> Product? {
        guard let normalized = normalizedBarcode(barcode) else { return nil }
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("is_active", value: true)
            .eq("cod_bare", value: normalized)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func createProduct(
        companyId: UUID,
        input: ProductCreateInput,
        isVatPayer: Bool
    ) async throws -> Product {
        let trimmedName = input.denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProductCreateError.missingName }

        if let barcode = normalizedBarcode(input.codBare),
           try await findProductByBarcode(companyId: companyId, barcode: barcode) != nil {
            throw ProductCreateError.duplicateBarcode(barcode)
        }

        let requestedCode = input.cod?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedCode: String
        if requestedCode.isEmpty {
            resolvedCode = try await nextAvailableProductCode(companyId: companyId)
        } else if try await findProductByCode(companyId: companyId, code: requestedCode) != nil {
            throw ProductCreateError.duplicateCode(requestedCode)
        } else {
            resolvedCode = requestedCode
        }

        guard let cotaTva = validateVatRate(roundCurrency(input.cotaTva), isVatPayer: isVatPayer) else {
            throw ProductCreateError.invalidVatRate
        }
        let pretVanzare = roundCurrency(input.pretVanzare)
        guard pretVanzare >= 0 else { throw ProductCreateError.invalidSalePrice }

        let minQty = input.tip == .produsFinit ? 0 : max(0, input.cantitateMinima)
        let optimalQty = input.tip == .produsFinit ? 0 : max(0, input.cantitateOptima)
        let payload = ProductInsert(
            companyId: companyId,
            cod: resolvedCode,
            codBare: normalizedBarcode(input.codBare),
            denumire: resolvedProductName(for: trimmedName),
            descriere: emptyToNil(input.descriere),
            unitateMasura: normalizedUnit(input.unitateMasura),
            unitateAchizitie: emptyToNil(input.unitateAchizitie).map { normalizedUnit($0) },
            factorConversie: input.factorConversie > 0 ? input.factorConversie : 1,
            tip: input.tip.rawValue,
            cpv: nil,
            isActive: true,
            inCatalog: input.inCatalog,
            inStockSheet: input.inStockSheet,
            hasRecipe: input.hasRecipe,
            cotaTva: cotaTva,
            pretVanzare: pretVanzare,
            pretVanzareOnline: pretVanzare,
            imagineUrl: emptyToNil(input.imagineUrl),
            cantitateMinima: minQty,
            cantitateOptima: optimalQty
        )
        let rows: [Product] = try await client
            .from("products")
            .insert(payload)
            .select()
            .execute()
            .value
        guard let product = rows.first else { throw ServiceError.invalidResponse }
        return product
    }

    static func createProductFromBarcode(
        companyId: UUID,
        barcode: String,
        isVatPayer: Bool
    ) async throws -> Product {
        guard let normalized = normalizedBarcode(barcode) else {
            throw ProductCreateError.missingName
        }
        if let existing = try await findProductByBarcode(companyId: companyId, barcode: normalized) {
            return existing
        }

        let lookup = await lookup(forBarcode: normalized)
        let resolvedName = lookup?.resolvedName ?? defaultName(forBarcode: normalized)
        return try await createProduct(
            companyId: companyId,
            input: ProductCreateInput(
                denumire: resolvedName,
                codBare: normalized,
                unitateMasura: "Buc.",
                tip: .marfa,
                cotaTva: defaultVatRate(isVatPayer: isVatPayer),
                imagineUrl: lookup?.imageURL
            ),
            isVatPayer: isVatPayer
        )
    }

    static func defaultName(forBarcode barcode: String) -> String {
        L10n.tr("module.products.default_name_from_barcode", barcode)
    }

    struct ProductResolveResult: Sendable {
        let product: Product
        let created: Bool
        /// True = pe NIR trebuie confirmat articolul similar sau creat unul nou.
        let needsProductReview: Bool
    }

    /// Prag Dice pe bigrame: sub acesta considerăm că nu e același produs.
    nonisolated static let provisionalNameSimilarityThreshold: Double = 0.55

    static func findOrCreateProduct(
        companyId: UUID,
        cod: String?,
        codBare: String?,
        denumire: String,
        descriere: String?,
        unitateMasura: String,
        cpv: String?,
        products: inout [Product]
    ) async throws -> ProductResolveResult {
        let trimmedName = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        let isGarantieProduct = isGarantieProductName(trimmedName)
        // Fără LOT în denumire — aceeași fișă indiferent de lotul de pe factură
        let effectiveName = isGarantieProduct
            ? garantieSGRProductName
            : productNameIgnoringLot(trimmedName)
        let invoiceUnit = isGarantieProduct ? ProductStockUnit.bucata.rawValue : normalizedUnit(unitateMasura)
        let pack = InvoiceNamePackHint.parse(effectiveName)
        let pieceLikeInvoice = InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit)
        let resolvedStock = ProductStockUnit.resolve(invoiceUnit)
        let stockUnit: String
        let purchaseUnit: String?
        let factorConversie: Decimal
        if isGarantieProduct {
            stockUnit = ProductStockUnit.bucata.rawValue
            purchaseUnit = nil
            factorConversie = 1
        } else if pieceLikeInvoice, let pack {
            stockUnit = pack.unit.rawValue
            purchaseUnit = invoiceUnit
            factorConversie = pack.quantity
        } else if let resolvedStock {
            stockUnit = resolvedStock.rawValue
            purchaseUnit = nil
            factorConversie = 1
        } else {
            stockUnit = ProductStockUnit.bucata.rawValue
            purchaseUnit = invoiceUnit
            factorConversie = 1
        }
        let trimmedCod = emptyToNil(cod)
        let trimmedBarcode = normalizedBarcode(codBare)

        func certain(_ product: Product) -> ProductResolveResult {
            ProductResolveResult(product: product, created: false, needsProductReview: false)
        }

        // Cartofi / roșii / kapia din facturi → fișa canonică pe firmă
        if !isGarantieProduct {
            if let canonical = Self.canonicalProduceName(forImportName: effectiveName),
               let match = try await resolveCanonicalNamedProduct(
                companyId: companyId,
                canonicalName: canonical,
                isFamily: { Self.isSameProduceFamily(importName: effectiveName, productName: $0) },
                products: &products
               ) {
                let enriched = try await enrichProductFromImport(
                    product: match,
                    codBare: trimmedBarcode,
                    products: &products
                )
                return certain(enriched)
            }
        }

        if !isGarantieProduct {
            if let match = try await existingProduct(
                companyId: companyId,
                cod: trimmedCod,
                barcode: nil,
                products: &products
            ) {
                let enriched = try await enrichProductFromImport(
                    product: match,
                    codBare: trimmedBarcode,
                    products: &products
                )
                return certain(enriched)
            }

            if let match = try await existingProduct(
                companyId: companyId,
                cod: nil,
                barcode: trimmedBarcode,
                products: &products
            ) {
                return certain(match)
            }
        }

        // 1) Preferă denumire + UM compatibilă (ignoră LOT pe ambele părți); fără produs finit
        if let match = products.first(where: {
            Self.isImportEligibleProduct($0)
                && Self.namesMatch(productNameIgnoringLot($0.denumire), effectiveName)
                && (
                    isGarantieProduct
                    || normalizedUnit($0.unitateMasura) == invoiceUnit
                    || StockUnitConversion.matchesPurchaseUnit($0, invoiceUnit: invoiceUnit)
                    || (
                        ProductStockUnit.resolve($0.unitateMasura) != nil
                        && InvoiceNamePackHint.isPieceLikeInvoiceUnit(invoiceUnit)
                        && !StockUnitConversion.unitsMatch($0.unitateMasura, invoiceUnit)
                    )
                    || (pieceLikeInvoice && pack != nil)
                )
        }) {
            let enriched = try await enrichProductFromImport(
                product: match,
                codBare: trimmedBarcode,
                products: &products
            )
            return certain(enriched)
        }

        // 2) Aceeași denumire pe firmă (fără LOT), indiferent de UM; fără produs finit
        if let match = products.first(where: {
            Self.isImportEligibleProduct($0)
                && Self.namesMatch(productNameIgnoringLot($0.denumire), effectiveName)
        }) {
            let enriched = try await enrichProductFromImport(
                product: match,
                codBare: trimmedBarcode,
                products: &products
            )
            return certain(enriched)
        }

        if let match = try await findProductByName(companyId: companyId, denumire: effectiveName),
           Self.isImportEligibleProduct(match) {
            remember(match, in: &products)
            let enriched = try await enrichProductFromImport(
                product: match,
                codBare: trimmedBarcode,
                products: &products
            )
            return certain(enriched)
        }

        // 3) Denumire similară existentă — nu crea fișă nouă; legă provisional și cere confirmare pe NIR
        if !isGarantieProduct,
           let similar = bestSimilarProduct(to: effectiveName, in: products),
           nameSimilarity(similar.denumire, effectiveName) >= provisionalNameSimilarityThreshold {
            let enriched = try await enrichProductFromImport(
                product: similar,
                codBare: trimmedBarcode,
                products: &products
            )
            return ProductResolveResult(product: enriched, created: false, needsProductReview: true)
        }

        let insertName = (!isGarantieProduct ? Self.canonicalProduceName(forImportName: effectiveName) : nil)
            ?? effectiveName

        let insertCode: String?
        if isGarantieProduct {
            insertCode = nil // trigger DB alocă următorul liber
        } else if let trimmedCod, !trimmedCod.isEmpty {
            insertCode = trimmedCod
        } else {
            insertCode = nil // trigger DB alocă următorul liber
        }

        let payload = ProductInsert(
            companyId: companyId,
            cod: insertCode,
            codBare: isGarantieProduct ? nil : emptyToNil(trimmedBarcode),
            denumire: insertName,
            descriere: isGarantieProduct ? nil : emptyToNil(descriere),
            unitateMasura: stockUnit,
            unitateAchizitie: purchaseUnit,
            factorConversie: factorConversie,
            tip: suggestedImportProductKind(for: effectiveName).rawValue,
            cpv: isGarantieProduct ? nil : emptyToNil(cpv),
            isActive: true,
            inCatalog: false,
            inStockSheet: false,
            hasRecipe: false,
            cotaTva: 21,
            pretVanzare: 0,
            pretVanzareOnline: 0,
            imagineUrl: nil,
            cantitateMinima: 0,
            cantitateOptima: 0
        )
        do {
            let rows: [Product] = try await client
                .from("products")
                .insert(payload)
                .select()
                .execute()
                .value
            guard let product = rows.first else { throw ServiceError.invalidResponse }
            remember(product, in: &products)
            return ProductResolveResult(product: product, created: true, needsProductReview: false)
        } catch {
            guard isProductUniqueConstraintViolation(error),
                  let existing = try await existingProduct(
                    companyId: companyId,
                    cod: isGarantieProduct ? nil : trimmedCod,
                    barcode: isGarantieProduct ? nil : trimmedBarcode,
                    products: &products
                  ) else {
                throw error
            }
            let enriched = try await enrichProductFromImport(
                product: existing,
                codBare: trimmedBarcode,
                products: &products
            )
            return certain(enriched)
        }
    }

    nonisolated static func bestSimilarProduct(to name: String, in products: [Product]) -> Product? {
        let target = productNameIgnoringLot(name)
        guard !target.isEmpty else { return nil }
        return products
            .filter { isImportEligibleProduct($0) && !isGarantieProductName($0.denumire) }
            .map { ($0, nameSimilarity($0.denumire, target)) }
            .filter { $0.1 < 1 && $0.1 >= provisionalNameSimilarityThreshold }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    /// Similaritate Dice pe bigrame (0…1), după normalizare (fără LOT, fără diacritice).
    nonisolated static func nameSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let a = foldedProductName(productNameIgnoringLot(lhs))
        let b = foldedProductName(productNameIgnoringLot(rhs))
        if a.isEmpty || b.isEmpty { return 0 }
        if a == b { return 1 }
        if a.contains(b) || b.contains(a) {
            let shorter = Double(min(a.count, b.count))
            let longer = Double(max(a.count, b.count))
            return max(0.6, shorter / longer)
        }
        let ba = bigrams(a)
        let bb = bigrams(b)
        guard !ba.isEmpty, !bb.isEmpty else { return 0 }
        let overlap = ba.intersection(bb).count
        return (2.0 * Double(overlap)) / Double(ba.count + bb.count)
    }

    nonisolated private static func bigrams(_ value: String) -> Set<String> {
        let chars = Array(value)
        guard chars.count >= 2 else { return chars.isEmpty ? [] : [String(chars)] }
        var result = Set<String>()
        for i in 0..<(chars.count - 1) {
            result.insert(String(chars[i...i + 1]))
        }
        return result
    }

    nonisolated static func shouldSkipNIRProductKindUpdate(lineName: String) -> Bool {
        isGarantieProductName(lineName)
    }

    nonisolated static func isProductUniqueConstraintViolation(_ error: Error) -> Bool {
        if let postgrest = error as? PostgrestError, postgrest.code == "23505" {
            return true
        }
        let text = [
            (error as? PostgrestError)?.code,
            (error as? PostgrestError)?.message,
            (error as? PostgrestError)?.detail,
            error.localizedDescription
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
        return text.contains("duplicate key")
            || text.contains("unique constraint")
            || text.contains("idx_products_company_cod")
            || text.contains("idx__products_company_cod")
    }

    private static func existingProduct(
        companyId: UUID,
        cod: String?,
        barcode: String?,
        products: inout [Product]
    ) async throws -> Product? {
        if let cod, !cod.isEmpty {
            if let match = products.first(where: {
                isImportEligibleProduct($0)
                    && $0.cod?.caseInsensitiveCompare(cod) == .orderedSame
            }) {
                return match
            }
            if let match = try await findProductByCode(companyId: companyId, code: cod),
               isImportEligibleProduct(match) {
                remember(match, in: &products)
                return match
            }
        }

        if let barcode, !barcode.isEmpty {
            if let match = products.first(where: {
                isImportEligibleProduct($0)
                    && $0.codBare?.caseInsensitiveCompare(barcode) == .orderedSame
            }) {
                return match
            }
            if let match = try await findProductByBarcodeAnyStatus(companyId: companyId, barcode: barcode),
               isImportEligibleProduct(match) {
                remember(match, in: &products)
                return match
            }
        }

        return nil
    }

    private static func findProductByCode(companyId: UUID, code: String) async throws -> Product? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .ilike("cod", pattern: trimmed)
            .limit(20)
            .execute()
            .value
        return rows.first {
            $0.cod?.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    /// Următorul cod numeric liber pe societate (1, 2, 3…).
    static func nextAvailableProductCode(companyId: UUID) async throws -> String {
        struct CodRow: Decodable { let cod: String? }
        let rows: [CodRow] = try await client
            .from("products")
            .select("cod")
            .eq("company_id", value: companyId.uuidString)
            .execute()
            .value
        var maxValue: Int64 = 0
        for row in rows {
            guard let raw = row.cod?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty,
                  raw.allSatisfy(\.isNumber),
                  let value = Int64(raw) else { continue }
            maxValue = max(maxValue, value)
        }
        return String(maxValue + 1)
    }

    /// Potrivire pe denumire (case-insensitive) pe firmă — evită fișe duplicate la import.
    /// Exclude produs finit (nu se importă pe catalog / rețete).
    private static func findProductByName(companyId: UUID, denumire: String) async throws -> Product? {
        let trimmed = denumire.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .ilike("denumire", pattern: trimmed)
            .neq("tip", value: ProductKind.produsFinit.rawValue)
            .order("created_at", ascending: true)
            .limit(5)
            .execute()
            .value
        return rows.first(where: { namesMatch($0.denumire, trimmed) && isImportEligibleProduct($0) })
            ?? rows.first(where: isImportEligibleProduct)
    }

    private static func resolveCanonicalWhitePotato(
        companyId: UUID,
        products: inout [Product]
    ) async throws -> Product? {
        for name in [canonicalWhitePotatoProductName, legacyWhitePotatoProductName] {
            if let match = products.first(where: { namesMatch($0.denumire, name) }) {
                return match
            }
            if let match = try await findProductByName(companyId: companyId, denumire: name) {
                remember(match, in: &products)
                return match
            }
        }
        // Preferă materie primă; nu lega pe produs finit tip „CARTOFI” din catalog.
        if let match = products.first(where: {
            $0.tip == .materiePrima && isFreshWhitePotatoImportName($0.denumire)
        }) {
            return match
        }
        return nil
    }

    nonisolated static func canonicalProduceName(forImportName denumire: String) -> String? {
        if isFreshWhitePotatoImportName(denumire) { return canonicalWhitePotatoProductName }
        if isFreshTomatoImportName(denumire) { return canonicalTomatoProductName }
        if isKapiaImportName(denumire) { return canonicalKapiaProductName }
        if isPickledCucumberImportName(denumire) { return canonicalPickledCucumberProductName }
        if isFreshCucumberImportName(denumire) { return canonicalFreshCucumberProductName }
        if isFriedOnionImportName(denumire) { return canonicalFriedOnionProductName }
        if isRedOnionImportName(denumire) { return canonicalRedOnionProductName }
        if isYellowOnionImportName(denumire) { return canonicalYellowOnionProductName }
        if isCekoPizzaImportName(denumire) { return canonicalCekoPizzaProductName }
        if isChifleMariImportName(denumire) { return canonicalChifleMariProductName }
        if isDonerVitaTocatImportName(denumire) { return canonicalDonerVitaTocatProductName }
        if isBaitSnitelImportName(denumire) { return canonicalBaitSnitelProductName }
        if isCondimixImportName(denumire) { return canonicalCondimixProductName }
        if isCrustaCrispyImportName(denumire) { return canonicalCrustaCrispyProductName }
        if isFalafel450ImportName(denumire) { return canonicalFalafel450ProductName }
        if isHotMarinadeImportName(denumire) { return canonicalHotMarinadeProductName }
        if isLemonImportName(denumire) { return canonicalLemonProductName }
        if isLaysSareImportName(denumire) { return canonicalLaysSareProductName }
        if isLipieTipC750ImportName(denumire) { return canonicalLipieTipC750ProductName }
        if isMiniBagheta120ImportName(denumire) { return canonicalMiniBagheta120ProductName }
        if isPatrunjelImportName(denumire) { return canonicalPatrunjelProductName }
        if isPieptPuiDezImportName(denumire) { return canonicalPieptPuiDezProductName }
        if isPulpePuiDezImportName(denumire) { return canonicalPulpePuiDezProductName }
        if isPitaImportName(denumire) { return canonicalPitaProductName }
        if isPortocaleSucImportName(denumire) { return canonicalPortocaleProductName }
        if isPortocaleImportName(denumire) { return canonicalPortocaleProductName }
        if isSalataVerdeImportName(denumire) { return canonicalSalataVerdeProductName }
        if isCarlsberg033ImportName(denumire) { return canonicalCarlsberg033ProductName }
        if isCarlsberg05DozaImportName(denumire) { return canonicalCarlsberg05DozaProductName }
        if isBereBucur035ImportName(denumire) { return canonicalBereBucur035ProductName }
        if isTuborg05DozaImportName(denumire) { return canonicalTuborg05DozaProductName }
        if isTuborg033ImportName(denumire) { return canonicalTuborg033ProductName }
        if isGranini033ImportName(denumire) { return canonicalGranini033ProductName }
        if isLiptonLamaie05ImportName(denumire) { return canonicalLiptonLamaie05ProductName }
        if isLiptonPiersici05ImportName(denumire) { return canonicalLiptonPiersici05ProductName }
        if isMirindaOrange05ImportName(denumire) { return canonicalMirindaOrange05ProductName }
        if isMirindaOrange033DozaImportName(denumire) { return canonicalMirindaOrange033DozaProductName }
        if isMountainDew05ImportName(denumire) { return canonicalMountainDew05ProductName }
        if isPepsiCola05ImportName(denumire) { return canonicalPepsiCola05ProductName }
        if isPepsiCola033DozaImportName(denumire) { return canonicalPepsiCola033DozaProductName }
        if isPepsiTwist05ImportName(denumire) { return canonicalPepsiTwist05ProductName }
        if isPepsiZero05ImportName(denumire) { return canonicalPepsiZero05ProductName }
        if isPepsiZeroVanilie033ImportName(denumire) { return canonicalPepsiZeroVanilie033ProductName }
        if isSevenUp05ImportName(denumire) { return canonicalSevenUp05ProductName }
        if isAquaMinerala05ImportName(denumire) { return canonicalAquaMinerala05ProductName }
        if isAquaPlata05ImportName(denumire) { return canonicalAquaPlata05ProductName }
        if isAyranImportName(denumire) { return canonicalAyranProductName }
        if isSunflowerOilImportName(denumire) { return canonicalSunflowerOilProductName }
        if isUrsusCooler05ImportName(denumire) { return canonicalUrsusCooler05ProductName }
        if isBoiaDulceImportName(denumire) { return canonicalBoiaDulceProductName }
        if isFainaImportName(denumire) { return canonicalFainaProductName }
        if isPiperNegruMacinatImportName(denumire) { return canonicalPiperNegruMacinatProductName }
        if isKetchupDulceImportName(denumire) { return canonicalKetchupDulceProductName }
        if isOreganoImportName(denumire) { return canonicalOreganoProductName }
        if isZaharImportName(denumire) { return canonicalZaharProductName }
        if isTortillaCurcumaImportName(denumire) { return canonicalTortillaCurcumaProductName }
        if isVarzaRosieImportName(denumire) { return canonicalVarzaRosieProductName }
        if isVarzaAlbaImportName(denumire) { return canonicalVarzaAlbaProductName }
        if isSareImportName(denumire) { return canonicalSareProductName }
        if isUsturoiImportName(denumire) { return canonicalUsturoiProductName }
        if isOtetImportName(denumire) { return canonicalOtetProductName }
        if isCurryImportName(denumire) { return canonicalCurryProductName }
        if isScortisoaraImportName(denumire) { return canonicalScortisoaraProductName }
        if isDelikatImportName(denumire) { return canonicalDelikatProductName }
        if isBulionImportName(denumire) { return canonicalBulionProductName }
        if isMaslineVerziGogosariImportName(denumire) { return canonicalMaslineVerziGogosariProductName }
        if isPakmayaDrojdieImportName(denumire) { return canonicalPakmayaDrojdieProductName }
        // Materiale curățenie — spray înainte de soluție (altfel „sol aragaz spray” cade pe bidon)
        if isSolAragazSprayImportName(denumire) { return canonicalSolAragazSprayProductName }
        if isSolutieAragazImportName(denumire) { return canonicalSolutieAragazProductName }
        if isDetergentVaseImportName(denumire) { return canonicalDetergentVaseProductName }
        if isMaionezaImportName(denumire) { return canonicalMaionezaProductName }
        if isIaurtImportName(denumire) { return canonicalIaurtProductName }
        if isSosSamuraiImportName(denumire) { return canonicalSosSamuraiProductName }
        if isSosCedarImportName(denumire) { return canonicalSosCedarProductName }
        if isUleiPalmierImportName(denumire) { return canonicalUleiPalmierProductName }
        if isArdeiIuteImportName(denumire) { return canonicalArdeiIuteProductName }
        if isAripiPuiImportName(denumire) { return canonicalAripiPuiProductName }
        return nil
    }

    nonisolated static func isSameProduceFamily(importName: String, productName: String) -> Bool {
        if isFreshWhitePotatoImportName(importName) {
            return namesMatch(productName, canonicalWhitePotatoProductName)
                || namesMatch(productName, legacyWhitePotatoProductName)
                || isFreshWhitePotatoImportName(productName)
        }
        if isFreshTomatoImportName(importName) {
            return namesMatch(productName, canonicalTomatoProductName)
                || namesMatch(productName, legacyTomatoProductName)
                || isFreshTomatoImportName(productName)
        }
        if isKapiaImportName(importName) { return isKapiaImportName(productName) }
        if isPickledCucumberImportName(importName) {
            return namesMatch(productName, canonicalPickledCucumberProductName)
                || isPickledCucumberImportName(productName)
        }
        if isFreshCucumberImportName(importName) {
            return namesMatch(productName, canonicalFreshCucumberProductName)
                || isFreshCucumberImportName(productName)
        }
        if isFriedOnionImportName(importName) {
            return namesMatch(productName, canonicalFriedOnionProductName)
                || namesMatch(productName, legacyFriedOnionProductName)
                || isFriedOnionImportName(productName)
        }
        if isRedOnionImportName(importName) {
            return namesMatch(productName, canonicalRedOnionProductName)
                || isRedOnionImportName(productName)
        }
        if isYellowOnionImportName(importName) {
            return namesMatch(productName, canonicalYellowOnionProductName)
                || namesMatch(productName, legacyYellowOnionProductName)
                || isYellowOnionImportName(productName)
        }
        if isCekoPizzaImportName(importName) {
            return namesMatch(productName, canonicalCekoPizzaProductName)
                || namesMatch(productName, legacyCekoPizzaProductName)
                || isCekoPizzaImportName(productName)
        }
        if isChifleMariImportName(importName) {
            return namesMatch(productName, canonicalChifleMariProductName)
                || isChifleMariImportName(productName)
        }
        if isDonerVitaTocatImportName(importName) {
            return namesMatch(productName, canonicalDonerVitaTocatProductName)
                || isDonerVitaTocatImportName(productName)
        }
        if isBaitSnitelImportName(importName) {
            return namesMatch(productName, canonicalBaitSnitelProductName)
                || namesMatch(productName, legacyBaitSnitelProductName)
                || isBaitSnitelImportName(productName)
        }
        if isCondimixImportName(importName) {
            return namesMatch(productName, canonicalCondimixProductName)
                || namesMatch(productName, legacyCondimixProductName)
                || isCondimixImportName(productName)
        }
        if isCrustaCrispyImportName(importName) {
            return namesMatch(productName, canonicalCrustaCrispyProductName)
                || namesMatch(productName, legacyCrustaCrispyProductName)
                || isCrustaCrispyImportName(productName)
        }
        if isFalafel450ImportName(importName) {
            return namesMatch(productName, canonicalFalafel450ProductName)
                || namesMatch(productName, legacyFalafel450ProductName)
                || isFalafel450ImportName(productName)
        }
        if isHotMarinadeImportName(importName) {
            return namesMatch(productName, canonicalHotMarinadeProductName)
                || namesMatch(productName, legacyHotMarinadeProductName)
                || isHotMarinadeImportName(productName)
        }
        if isLemonImportName(importName) {
            return namesMatch(productName, canonicalLemonProductName)
                || namesMatch(productName, legacyLemonProductName)
                || isLemonImportName(productName)
        }
        if isLaysSareImportName(importName) {
            return namesMatch(productName, canonicalLaysSareProductName)
                || namesMatch(productName, legacyLaysSareProductName)
                || isLaysSareImportName(productName)
        }
        if isLipieTipC750ImportName(importName) {
            return namesMatch(productName, canonicalLipieTipC750ProductName)
                || isLipieTipC750ImportName(productName)
        }
        if isMiniBagheta120ImportName(importName) {
            return namesMatch(productName, canonicalMiniBagheta120ProductName)
                || isMiniBagheta120ImportName(productName)
        }
        if isPatrunjelImportName(importName) {
            return namesMatch(productName, canonicalPatrunjelProductName)
                || isPatrunjelImportName(productName)
        }
        if isPieptPuiDezImportName(importName) {
            return namesMatch(productName, canonicalPieptPuiDezProductName)
                || isPieptPuiDezImportName(productName)
        }
        if isPulpePuiDezImportName(importName) {
            return namesMatch(productName, canonicalPulpePuiDezProductName)
                || isPulpePuiDezImportName(productName)
        }
        if isPitaImportName(importName) {
            return namesMatch(productName, canonicalPitaProductName)
                || isPitaImportName(productName)
        }
        if isPortocaleSucImportName(importName) || isPortocaleImportName(importName) {
            return namesMatch(productName, canonicalPortocaleProductName)
                || namesMatch(productName, legacyPortocaleProductName)
                || isPortocaleImportName(productName)
                || isPortocaleSucImportName(productName)
        }
        if isSalataVerdeImportName(importName) {
            return namesMatch(productName, canonicalSalataVerdeProductName)
                || isSalataVerdeImportName(productName)
        }
        if isCarlsberg033ImportName(importName) {
            return namesMatch(productName, canonicalCarlsberg033ProductName)
                || isCarlsberg033ImportName(productName)
        }
        if isCarlsberg05DozaImportName(importName) {
            return namesMatch(productName, canonicalCarlsberg05DozaProductName)
                || isCarlsberg05DozaImportName(productName)
        }
        if isBereBucur035ImportName(importName) {
            return namesMatch(productName, canonicalBereBucur035ProductName)
                || isBereBucur035ImportName(productName)
        }
        if isTuborg05DozaImportName(importName) {
            return namesMatch(productName, canonicalTuborg05DozaProductName)
                || isTuborg05DozaImportName(productName)
        }
        if isTuborg033ImportName(importName) {
            return namesMatch(productName, canonicalTuborg033ProductName)
                || isTuborg033ImportName(productName)
        }
        if isGranini033ImportName(importName) {
            return namesMatch(productName, canonicalGranini033ProductName)
                || isGranini033ImportName(productName)
        }
        if isLiptonLamaie05ImportName(importName) {
            return namesMatch(productName, canonicalLiptonLamaie05ProductName)
                || isLiptonLamaie05ImportName(productName)
        }
        if isLiptonPiersici05ImportName(importName) {
            return namesMatch(productName, canonicalLiptonPiersici05ProductName)
                || isLiptonPiersici05ImportName(productName)
        }
        if isMirindaOrange05ImportName(importName) {
            return namesMatch(productName, canonicalMirindaOrange05ProductName)
                || isMirindaOrange05ImportName(productName)
        }
        if isMirindaOrange033DozaImportName(importName) {
            return namesMatch(productName, canonicalMirindaOrange033DozaProductName)
                || isMirindaOrange033DozaImportName(productName)
        }
        if isMountainDew05ImportName(importName) {
            return namesMatch(productName, canonicalMountainDew05ProductName)
                || isMountainDew05ImportName(productName)
        }
        if isPepsiCola05ImportName(importName) {
            return namesMatch(productName, canonicalPepsiCola05ProductName)
                || isPepsiCola05ImportName(productName)
        }
        if isPepsiCola033DozaImportName(importName) {
            return namesMatch(productName, canonicalPepsiCola033DozaProductName)
                || isPepsiCola033DozaImportName(productName)
        }
        if isPepsiTwist05ImportName(importName) {
            return namesMatch(productName, canonicalPepsiTwist05ProductName)
                || isPepsiTwist05ImportName(productName)
        }
        if isPepsiZero05ImportName(importName) {
            return namesMatch(productName, canonicalPepsiZero05ProductName)
                || isPepsiZero05ImportName(productName)
        }
        if isPepsiZeroVanilie033ImportName(importName) {
            return namesMatch(productName, canonicalPepsiZeroVanilie033ProductName)
                || isPepsiZeroVanilie033ImportName(productName)
        }
        if isSevenUp05ImportName(importName) {
            return namesMatch(productName, canonicalSevenUp05ProductName)
                || isSevenUp05ImportName(productName)
        }
        if isAquaMinerala05ImportName(importName) {
            return namesMatch(productName, canonicalAquaMinerala05ProductName)
                || isAquaMinerala05ImportName(productName)
        }
        if isAquaPlata05ImportName(importName) {
            return namesMatch(productName, canonicalAquaPlata05ProductName)
                || isAquaPlata05ImportName(productName)
        }
        if isAyranImportName(importName) {
            return namesMatch(productName, canonicalAyranProductName)
                || isAyranImportName(productName)
        }
        if isSunflowerOilImportName(importName) {
            return namesMatch(productName, canonicalSunflowerOilProductName)
                || isSunflowerOilImportName(productName)
        }
        if isUrsusCooler05ImportName(importName) {
            return namesMatch(productName, canonicalUrsusCooler05ProductName)
                || isUrsusCooler05ImportName(productName)
        }
        if isBoiaDulceImportName(importName) {
            return namesMatch(productName, canonicalBoiaDulceProductName)
                || namesMatch(productName, legacyBoiaDulceProductName)
                || isBoiaDulceImportName(productName)
        }
        if isFainaImportName(importName) {
            return namesMatch(productName, canonicalFainaProductName)
                || namesMatch(productName, legacyFainaProductName)
                || isFainaImportName(productName)
        }
        if isPiperNegruMacinatImportName(importName) {
            return namesMatch(productName, canonicalPiperNegruMacinatProductName)
                || namesMatch(productName, legacyPiperNegruMacinatProductName)
                || isPiperNegruMacinatImportName(productName)
        }
        if isKetchupDulceImportName(importName) {
            return namesMatch(productName, canonicalKetchupDulceProductName)
                || namesMatch(productName, legacyKetchupDulceProductName)
                || isKetchupDulceImportName(productName)
        }
        if isOreganoImportName(importName) {
            return namesMatch(productName, canonicalOreganoProductName)
                || namesMatch(productName, legacyOreganoProductName)
                || isOreganoImportName(productName)
        }
        if isZaharImportName(importName) {
            return namesMatch(productName, canonicalZaharProductName)
                || namesMatch(productName, legacyZaharProductName)
                || isZaharImportName(productName)
        }
        if isTortillaCurcumaImportName(importName) {
            return namesMatch(productName, canonicalTortillaCurcumaProductName)
                || isTortillaCurcumaImportName(productName)
        }
        if isVarzaRosieImportName(importName) {
            return namesMatch(productName, canonicalVarzaRosieProductName)
                || isVarzaRosieImportName(productName)
        }
        if isVarzaAlbaImportName(importName) {
            return namesMatch(productName, canonicalVarzaAlbaProductName)
                || namesMatch(productName, legacyVarzaAlbaProductName)
                || isVarzaAlbaImportName(productName)
        }
        if isSareImportName(importName) {
            return namesMatch(productName, canonicalSareProductName)
                || namesMatch(productName, legacySareProductName)
                || isSareImportName(productName)
        }
        if isUsturoiImportName(importName) {
            return namesMatch(productName, canonicalUsturoiProductName)
                || namesMatch(productName, legacyUsturoiProductName)
                || isUsturoiImportName(productName)
        }
        if isOtetImportName(importName) {
            return namesMatch(productName, canonicalOtetProductName)
                || namesMatch(productName, legacyOtetProductName)
                || isOtetImportName(productName)
        }
        if isCurryImportName(importName) {
            return namesMatch(productName, canonicalCurryProductName)
                || namesMatch(productName, legacyCurryProductName)
                || isCurryImportName(productName)
        }
        if isScortisoaraImportName(importName) {
            return namesMatch(productName, canonicalScortisoaraProductName)
                || namesMatch(productName, legacyScortisoaraProductName)
                || isScortisoaraImportName(productName)
        }
        if isDelikatImportName(importName) {
            return namesMatch(productName, canonicalDelikatProductName)
                || namesMatch(productName, legacyDelikatProductName)
                || isDelikatImportName(productName)
        }
        if isBulionImportName(importName) {
            return namesMatch(productName, canonicalBulionProductName)
                || namesMatch(productName, legacyBulionProductName)
                || isBulionImportName(productName)
        }
        if isMaslineVerziGogosariImportName(importName) {
            return namesMatch(productName, canonicalMaslineVerziGogosariProductName)
                || namesMatch(productName, legacyMaslineVerziGogosariProductName)
                || isMaslineVerziGogosariImportName(productName)
        }
        if isPakmayaDrojdieImportName(importName) {
            return namesMatch(productName, canonicalPakmayaDrojdieProductName)
                || namesMatch(productName, legacyPakmayaDrojdieProductName)
                || isPakmayaDrojdieImportName(productName)
        }
        if isSolAragazSprayImportName(importName) {
            return namesMatch(productName, canonicalSolAragazSprayProductName)
                || isSolAragazSprayImportName(productName)
        }
        if isSolutieAragazImportName(importName) {
            return namesMatch(productName, canonicalSolutieAragazProductName)
                || isSolutieAragazImportName(productName)
        }
        if isDetergentVaseImportName(importName) {
            return namesMatch(productName, canonicalDetergentVaseProductName)
                || isDetergentVaseImportName(productName)
        }
        if isMaionezaImportName(importName) {
            return namesMatch(productName, canonicalMaionezaProductName)
                || namesMatch(productName, legacyMaionezaProductName)
                || isMaionezaImportName(productName)
        }
        if isIaurtImportName(importName) {
            return namesMatch(productName, canonicalIaurtProductName)
                || namesMatch(productName, legacyIaurtProductName)
                || isIaurtImportName(productName)
        }
        if isSosSamuraiImportName(importName) {
            return namesMatch(productName, canonicalSosSamuraiProductName)
                || namesMatch(productName, legacySosSamuraiProductName)
                || isSosSamuraiImportName(productName)
        }
        if isSosCedarImportName(importName) {
            return namesMatch(productName, canonicalSosCedarProductName)
                || namesMatch(productName, legacySosCedarProductName)
                || isSosCedarImportName(productName)
        }
        if isUleiPalmierImportName(importName) {
            return namesMatch(productName, canonicalUleiPalmierProductName)
                || namesMatch(productName, legacyUleiPalmierProductName)
                || isUleiPalmierImportName(productName)
        }
        if isArdeiIuteImportName(importName) {
            return namesMatch(productName, canonicalArdeiIuteProductName)
                || isArdeiIuteImportName(productName)
        }
        if isAripiPuiImportName(importName) {
            return namesMatch(productName, canonicalAripiPuiProductName)
                || namesMatch(productName, legacyAripiPuiProductName)
                || isAripiPuiImportName(productName)
        }
        return false
    }

    private static func resolveCanonicalNamedProduct(
        companyId: UUID,
        canonicalName: String,
        isFamily: (String) -> Bool,
        products: inout [Product]
    ) async throws -> Product? {
        // Produsele finite nu se importă — doar categorii de stoc / cheltuială.
        if let match = products.first(where: {
            isImportEligibleProduct($0) && namesMatch($0.denumire, canonicalName)
        }) {
            return match
        }
        if let match = try await findProductByName(companyId: companyId, denumire: canonicalName),
           isImportEligibleProduct(match) {
            remember(match, in: &products)
            return match
        }
        if let match = products.first(where: {
            isImportEligibleProduct($0) && isFamily($0.denumire)
        }) {
            return match
        }
        return nil
    }

    nonisolated static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(
                rhs.trimmingCharacters(in: .whitespacesAndNewlines)
            ) == .orderedSame
    }

    /// Import factură / NIR: nu legăm și nu creăm pe produs finit (catalog / rețete).
    nonisolated static func isImportEligibleProduct(_ product: Product) -> Bool {
        product.tip != .produsFinit
    }

    private static func findProductByBarcodeAnyStatus(companyId: UUID, barcode: String) async throws -> Product? {
        let rows: [Product] = try await client
            .from("products")
            .select()
            .eq("company_id", value: companyId.uuidString)
            .eq("cod_bare", value: barcode)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private static func remember(_ product: Product, in products: inout [Product]) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        } else {
            products.append(product)
        }
    }

    private static func normalizedUnit(_ value: String) -> String {
        EFacturaUnitCode.normalize(value)
    }

    private static func normalizedBarcode(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: " ", with: "")
    }

    private static func isBlank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    private static func enrichProductFromImport(
        product: Product,
        codBare: String?,
        products: inout [Product]
    ) async throws -> Product {
        guard isBlank(product.codBare), let codBare = emptyToNil(codBare) else {
            return product
        }

        let payload = ProductImportEnrichment(codBare: codBare)
        do {
            let rows: [Product] = try await client
                .from("products")
                .update(payload)
                .eq("id", value: product.id.uuidString)
                .select()
                .execute()
                .value
            guard let updated = rows.first else { return product }
            remember(updated, in: &products)
            return updated
        } catch {
            if isProductUniqueConstraintViolation(error) {
                return product
            }
            throw error
        }
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
