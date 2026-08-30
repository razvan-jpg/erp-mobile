import Foundation

struct ZReportData: Identifiable, Equatable, Sendable {
    nonisolated init() {}

    var id = UUID()
    var punctLucru: PunctLucru = .agro
    /// Locația de pe bon (rândul „Locația …”), ex. AGRONOMIEI / PLOIESTI.
    var locatieLabel: String = ""
    var zNumber: Int = 0
    /// Denumirea firmei de pe primul/primele rânduri ale Raportului Z.
    var firma: String = ""
    /// CUI/CIF (cifre, fără RO) — identificare firmă pentru NC și export.
    var cui: String = ""
    /// true = NECTARIE 20XXV → schema completă (10 rânduri, casă 5311.1/5311.2 + viramente).
    var isNectarieFirma: Bool = false
    /// Data notei contabile (ziua vânzărilor). Pentru tura de noapte = ziua dinaintea tipăririi.
    var date: Date = Date()
    /// Data/ora tipăririi de pe subsolul bonului Z (DATA + ORA).
    var printDateTime: Date?
    /// Tura noapte: ora tipăririi între 03:00 și 10:00.
    var isNightShift: Bool = false
    /// VAL. TOTAL VANZ - A (brut cu TVA 21%)
    var vanzari21: Decimal = 0
    /// TOTAL TVA A - 21%
    var tva21: Decimal = 0
    /// VAL. TOTAL VANZ - B (brut cu TVA 11%)
    var vanzari11: Decimal = 0
    /// TOTAL TVA B - 11%
    var tva11: Decimal = 0
    /// VAL. TOTAL VANZ - C (brut cu TVA 11% — produse finite, schema bacșiș)
    var vanzari11C: Decimal = 0
    /// TOTAL TVA C - 11%
    var tva11C: Decimal = 0
    /// VAL. TOTAL VANZ - D (0% / bacșiș)
    var vanzari0: Decimal = 0
    var numerar: Decimal = 0
    var card: Decimal = 0
    var plataModerna: Decimal = 0
    /// Alte metode de plată (tichete, voucher, plată modernă etc.) — schema bacșiș, rând 5113.
    var altePlati: Decimal = 0
    var totalVanzari: Decimal = 0
    var ocrText: String = ""
    var sourceFileName: String = ""
    /// Import din PDF POS cu text încorporat (citire fiabilă pe etichete).
    var parseSource: ParseSource = .fiscalOCR

    nonisolated enum ParseSource: Equatable, Sendable, Codable {
        case digitalPDF
        case fiscalOCR
    }

    var net11: Decimal { vanzari11 - tva11 }
    var net21: Decimal { vanzari21 - tva21 }
    var net11C: Decimal { vanzari11C - tva11C }

    /// Firmă cu schema bacșiș (GENIC, Hotel Impex): 4 cote TVA posibile + repartizare 10%.
    nonisolated var usesBacsisSchema: Bool {
        FirmaRegistry.profile(for: self)?.scutitUsesBacsis == true
    }

    nonisolated var sumaVanzariCategorii: Decimal {
        vanzari21 + vanzari11 + vanzari11C + vanzari0
    }

    var sumaVanzariNC: Decimal {
        if usesBacsisSchema {
            return tva21 + net21 + tva11 + net11 + tva11C + net11C + vanzari0
        }
        return tva11 + net11 + tva21 + net21 + vanzari0
    }

    nonisolated var sumaPlatiEfective: Decimal {
        if usesBacsisSchema {
            if altePlati > 0 { return numerar + card + altePlati }
            let residual = totalVanzari - numerar - card
            return numerar + card + max(0, residual)
        }
        return numerar + card + plataModerna
    }

    var sumaPlatiNC: Decimal { sumaPlatiEfective }

    /// Hotel Impex / GENIC: control Numerar + Card + alte plăți (fără câmp separat plată modernă în UI).
    var usesCashCardOnlyPayments: Bool { usesBacsisSchema }

    /// Control: (A+B+C+D) = Total vânzări = încasări.
    nonisolated var isBalanced: Bool {
        guard zNumber > 0, totalVanzari > 0 else { return false }
        guard sumaVanzariCategorii > 0 else { return false }
        guard sumaPlatiEfective > 0 else { return false }
        let tol = balanceTolerance
        let categoriesOK = abs(sumaVanzariCategorii - totalVanzari) <= tol
        let paymentsOK = abs(sumaPlatiEfective - totalVanzari) <= tol
        return categoriesOK && paymentsOK
    }

    /// Orice sursă — badge „Diferență!” deschide detaliul liniilor de control.
    var canExplainBalanceGap: Bool {
        zNumber > 0 && totalVanzari > 0
    }

    nonisolated private var balanceTolerance: Decimal {
        max(Decimal(string: "0.50")!, totalVanzari * Decimal(string: "0.008")!)
    }

    struct BalanceCheckLine: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let isOK: Bool
    }

    /// Liniile de control afișate când apeși „Diferență!”.
    var balanceCheckLines: [BalanceCheckLine] {
        balanceToleranceLines
    }

    private var balanceToleranceLines: [BalanceCheckLine] {
        guard zNumber > 0, totalVanzari > 0 else {
            return [BalanceCheckLine(title: "Date incomplete", detail: "Lipsesc nr. Z sau total vânzări.", isOK: false)]
        }
        let tol = balanceTolerance
        let catSum = sumaVanzariCategorii
        let paySum = sumaPlatiEfective
        let catDelta = catSum - totalVanzari
        let payDelta = paySum - totalVanzari

        var lines: [BalanceCheckLine] = [
            BalanceCheckLine(
                title: "Vânzări A (21%)",
                detail: vanzari21.moneyString,
                isOK: vanzari21 > 0 || catSum == 0
            ),
            BalanceCheckLine(
                title: "Vânzări B (11%)",
                detail: vanzari11.moneyString,
                isOK: vanzari11 > 0 || catSum == 0
            ),
        ]
        if usesBacsisSchema || vanzari11C > 0 {
            lines.append(BalanceCheckLine(
                title: "Vânzări C (11%)",
                detail: vanzari11C.moneyString,
                isOK: vanzari11C > 0 || catSum == 0
            ))
        }
        lines.append(BalanceCheckLine(
            title: "Vânzări D (0% / bacșiș)",
            detail: vanzari0.moneyString,
            isOK: true
        ))
        let catLabel = usesBacsisSchema || vanzari11C > 0 ? "A + B + C + D" : "A + B + D"
        lines.append(BalanceCheckLine(
            title: "\(catLabel) = Total vânzări",
            detail: "\(catSum.moneyString) vs \(totalVanzari.moneyString) · Δ \(signedMoney(catDelta))",
            isOK: abs(catDelta) <= tol
        ))
        lines.append(BalanceCheckLine(
            title: "Numerar",
            detail: numerar.moneyString,
            isOK: numerar > 0 || paySum == 0
        ))
        lines.append(BalanceCheckLine(
            title: "Card",
            detail: card.moneyString,
            isOK: card > 0 || paySum == 0
        ))
        if usesBacsisSchema {
            let alte = altePlati > 0 ? altePlati : max(0, totalVanzari - numerar - card)
            lines.append(BalanceCheckLine(
                title: "Alte plăți (tichete, voucher, modernă…)",
                detail: alte.moneyString,
                isOK: true
            ))
            lines.append(BalanceCheckLine(
                title: "Numerar + Card + Alte = Total vânzări",
                detail: "\(paySum.moneyString) vs \(totalVanzari.moneyString) · Δ \(signedMoney(payDelta))",
                isOK: abs(payDelta) <= tol
            ))
        } else {
            if !usesCashCardOnlyPayments {
                lines.append(BalanceCheckLine(
                    title: "Plată modernă",
                    detail: plataModerna.moneyString,
                    isOK: true
                ))
            }
            let payLabel = "Numerar + Card + Modernă"
            lines.append(BalanceCheckLine(
                title: "\(payLabel) = Total vânzări",
                detail: "\(paySum.moneyString) vs \(totalVanzari.moneyString) · Δ \(signedMoney(payDelta))",
                isOK: abs(payDelta) <= tol
            ))
        }
        return lines
    }

    private func signedMoney(_ value: Decimal) -> String {
        if value == 0 { return "0,00" }
        let prefix = value > 0 ? "+" : ""
        return prefix + value.moneyString
    }

    var documentNumber: String {
        if isNectarieFirma {
            return punctLucru.formatDocumentNumber(zNumber)
        }
        // Alte firme: doar numărul Z, fără prefix punct
        return String(format: "%04d", zNumber)
    }

    var dateFormatted: String {
        DateFormats.displayDate(from: date)
    }

    var printDateTimeFormatted: String? {
        guard let printDateTime else { return nil }
        return DateFormats.displayDateTime(from: printDateTime)
    }

    /// Format NextUp NC.xls: YYYYMMDD ca număr
    var dateYYYYMMDD: Int {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return Int(f.string(from: date)) ?? 0
    }

    var turaLabel: String {
        isNightShift ? "Tura noapte" : "Tura zi"
    }

    var schemaLabel: String {
        if isNectarieFirma { return "Nectarie (10 rânduri)" }
        if usesBacsisSchema { return "Bacșiș (până la 11 rânduri)" }
        return "Altă firmă (8 rânduri)"
    }

    /// Afișare locație: etichetă de pe bon sau punct de lucru mapat.
    var locationDisplay: String {
        if !locatieLabel.isEmpty { return locatieLabel }
        if isNectarieFirma { return punctLucru.rawValue }
        return punctLucru.shortName
    }

    /// Cheie unică la import: firmă (+ loc Nectarie) + nr. Z.
    var importDedupKey: String? {
        guard zNumber > 0 else { return nil }
        let firm = FirmaRegistry.groupingKey(for: self)
        if isNectarieFirma {
            return "\(firm)|\(punctLucru.rawValue)|z:\(zNumber)"
        }
        return "\(firm)|z:\(zNumber)"
    }
}

extension Array where Element == ZReportData {
    /// Ordine stabilă pentru Excel: dată NC → punct → nr. Z (indiferent de ordinea pozelor).
    func sortedForExport() -> [ZReportData] {
        sorted { a, b in
            let cal = Calendar.current
            let ad = cal.startOfDay(for: a.date)
            let bd = cal.startOfDay(for: b.date)
            if ad != bd { return ad < bd }
            if a.punctLucru.rawValue != b.punctLucru.rawValue {
                return a.punctLucru.rawValue < b.punctLucru.rawValue
            }
            return a.zNumber < b.zNumber
        }
    }

    /// Păstrează primul Z per cheie; restul (duplicate în batch sau deja în listă) sunt ignorate.
    func mergingImportedReports(_ incoming: [ZReportData]) -> (accepted: [ZReportData], skipped: [ZReportData]) {
        var seen = Set(compactMap(\.importDedupKey))
        var accepted: [ZReportData] = []
        var skipped: [ZReportData] = []

        for report in incoming {
            guard let key = report.importDedupKey else {
                accepted.append(report)
                continue
            }
            if seen.contains(key) {
                skipped.append(report)
            } else {
                seen.insert(key)
                accepted.append(report)
            }
        }
        return (accepted, skipped)
    }
}

/// Rând mapat pe coloanele din NC.xls (doar câmpurile pe care le completăm).
struct NotaContabilaRow: Identifiable, Equatable {
    var id = UUID()
    /// Același pe toate cele 10 linii ale unei note; se incrementează per Z.
    var nrInreg: Int
    var jurnal: String
    var dataYYYYMMDD: Int
    var numarDocument: String
    var contDebit: String
    var titluDebit: String
    var contCredit: String
    var titluCredit: String
    var explicatie: String = ""
    var valoare: Decimal
    var codPartener: String = ""
    var partenerCIF: String = ""
    var partenerNume: String = ""
    /// Coloana BZ — CUI intern pentru deduplicare (nu Partener CIF NextUp).
    var firmCUI: String = ""
    var angajatCNP: String = ""
    var angajatNume: String = ""
    var optiuneTva: String = ""
    /// Cota ca număr (11 / 21 / 0), ca în NC.xls
    var cotaTva: Decimal? = nil
    var codTvaSaft: String = ""
    var moneda: String = "RON"
}
