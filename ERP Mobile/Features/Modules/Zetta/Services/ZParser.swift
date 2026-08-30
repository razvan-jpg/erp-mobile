import Foundation

enum ZParser {
    /// Extrage datele din textul OCR al unui Raport Z (ignoră Raport X).
    nonisolated static func parse(ocrText: String, preferredLocation: PunctLucru? = nil) -> ZReportData {
        let normalizedText = BinaPosZReportTextNormalizer.normalizeIfNeeded(ocrText)
        if isDigitalPOSZReport(normalizedText) {
            return parseDigitalPOSZReport(ocrText: normalizedText, preferredLocation: preferredLocation)
        }

        var data = ZReportData()
        data.ocrText = normalizedText

        let focused = focusOnZReport(normalizedText)
        let lines = normalizeLines(focused)
        let upper = lines.joined(separator: "\n").uppercased()

        data.firma = Conturi.normalizedFirmaName(parseCompanyName(from: normalizedText, focused: focused))
        let parsedCUI = parseCUI(from: normalizedText) ?? parseCUI(from: focused)
        if let profile = FirmaRegistry.resolve(cuiFromParser: parsedCUI, ocrName: data.firma, ocrText: normalizedText) {
            data.firma = profile.displayName
            data.cui = profile.cui
            data.isNectarieFirma = profile.isNectarie
        } else {
            if FirmaRegistry.isReceiptHeaderLabel(data.firma) {
                data.firma = ""
            }
            data.cui = parsedCUI ?? ""
            data.isNectarieFirma = Conturi.isNectarieFirma(data.firma)
                || Conturi.isNectarieFirma(normalizedText)
        }

        data.punctLucru = preferredLocation
            ?? PunctLucru.detect(from: focused)
            ?? PunctLucru.detect(from: normalizedText)
            ?? .agro

        data.zNumber = parseZNumber(in: focused.uppercased())
            ?? parseZNumber(in: upper)
            ?? parseZNumber(in: normalizedText.uppercased())
            ?? 0

        let dateInfo = resolvePrintDateAndShift(in: focused, lines: lines, isNectarie: data.isNectarieFirma)
            ?? resolvePrintDateAndShift(in: normalizedText, lines: normalizeLines(normalizedText), isNectarie: data.isNectarieFirma)
        if let dateInfo {
            data.printDateTime = dateInfo.printed
            data.isNightShift = dateInfo.isNightShift
            data.date = dateInfo.businessDate
        }

        parseSalesAndVAT(into: &data, lines: lines)
        parsePayments(into: &data, lines: lines)
        reconcileVAT(&data)
        reconcileTotals(&data, lines: lines)
        // Fără completare artificială A/B/D din diferențe — doar ce e citit de pe etichete.

        return data
    }

    /// Bon Z tipărit — nu ecranul aplicației.
    nonisolated static func looksLikeZReceipt(_ ocrText: String) -> Bool {
        let upper = ocrText.uppercased()
        if isAppScreenshot(ocrText) { return false }
        return upper.contains("RAPORT FISCAL") || upper.contains("FISCAL ZILNIC")
            || upper.contains("Z REPORT") || upper.contains("Z REPORT NUMAR")
            || (upper.contains("LOCALIA") && upper.contains("METODE DE PLATA"))
            || (upper.contains("Z NR") && upper.contains("VANZ"))
            || (upper.contains("PENTRU Z:") && upper.contains("TOTAL VANZ"))
    }

    /// Număr de bonuri Z distincte detectate în textul OCR (header sau nr. Z unice).
    nonisolated static func countZReports(in ocrText: String) -> Int {
        max(splitOCRTextIntoReports(ocrText).count, 1)
    }

    /// Împarte text OCR cu mai multe bonuri Z — fiecare segment se parsează separat.
    nonisolated static func splitOCRTextIntoReports(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r", with: "\n")
        let upper = normalized.uppercased()
        let marker = "RAPORT FISCAL ZILNIC"

        var starts: [String.Index] = []
        var search = upper.startIndex
        while search < upper.endIndex,
              let range = upper.range(of: marker, range: search..<upper.endIndex) {
            starts.append(range.lowerBound)
            search = range.upperBound
        }

        if starts.count >= 2 {
            let segments = extractReportSegments(from: normalized, starts: starts)
            if segments.count >= 2 { return segments }
        }

        if let byZ = splitByDistinctZNumbers(normalized) {
            return byZ
        }

        return [normalized]
    }

    nonisolated private static func extractReportSegments(from text: String, starts: [String.Index]) -> [String] {
        var segments: [String] = []
        for i in 0..<starts.count {
            let start = starts[i]
            let end = i + 1 < starts.count ? starts[i + 1] : text.endIndex
            let slice = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slice.isEmpty else { continue }
            if looksLikeZReceipt(slice) || parseZNumber(in: slice.uppercased()) != nil {
                segments.append(slice)
            }
        }
        return segments
    }

    /// Fallback: mai multe „Z NR:xxxx” distincte în același OCR (bonuri alăturate fără header repetat).
    nonisolated private static func splitByDistinctZNumbers(_ text: String) -> [String]? {
        let upper = text.uppercased()
        guard let regex = try? NSRegularExpression(
            pattern: #"Z\s*NR\s*[:\.]?\s*0*(\d{1,4})(?!\d)"#,
            options: [.caseInsensitive]
        ) else { return nil }

        struct ZHit {
            var number: Int
            var range: Range<String.Index>
        }

        var hits: [ZHit] = []
        for match in regex.matches(in: upper, range: NSRange(upper.startIndex..., in: upper)) {
            guard match.numberOfRanges >= 2,
                  let fullRange = Range(match.range, in: upper),
                  let numRange = Range(match.range(at: 1), in: upper),
                  let n = Int(upper[numRange]), n > 0 else { continue }
            hits.append(ZHit(number: n, range: fullRange))
        }

        guard Set(hits.map(\.number)).count >= 2 else { return nil }

        var seen = Set<Int>()
        var uniqueHits: [ZHit] = []
        for hit in hits {
            if seen.insert(hit.number).inserted {
                uniqueHits.append(hit)
            }
        }
        uniqueHits.sort { $0.range.lowerBound < $1.range.lowerBound }

        var segments: [String] = []
        for (i, hit) in uniqueHits.enumerated() {
            let lookback = upper.index(hit.range.lowerBound, offsetBy: -700, limitedBy: upper.startIndex) ?? upper.startIndex
            let before = upper[lookback..<hit.range.lowerBound]
            let headerStart = before.range(of: "RAPORT FISCAL", options: .backwards)?.lowerBound
                ?? before.range(of: "FISCAL ZILNIC", options: .backwards)?.lowerBound
                ?? before.range(of: "CIF", options: .backwards)?.lowerBound
                ?? hit.range.lowerBound

            let end = i + 1 < uniqueHits.count ? uniqueHits[i + 1].range.lowerBound : text.endIndex
            let slice = String(text[headerStart..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !slice.isEmpty, looksLikeZReceipt(slice) || parseZNumber(in: slice.uppercased()) != nil {
                segments.append(slice)
            }
        }
        return segments.count >= 2 ? segments : nil
    }

    /// OCR pe screenshot Zetta (nu bon) — refuză importul.
    nonisolated static func isAppScreenshot(_ ocrText: String) -> Bool {
        let upper = ocrText.uppercased()
        let appMarkers = [
            "VERSIUNE:", "VÂNZĂRI 11% BRUT", "VANZARI 11% BRUT",
            "DOCUMENT: Z", "TURA NOAPTE (03:00", "PREVIZUALIZARE NOT",
            "EXPORTĂ", "EXPORTEAZA", "NR. Z  DATA", "NECTARIE (10 RANDURI)"
        ]
        let hits = appMarkers.filter { upper.contains($0) }.count
        if hits >= 2 { return true }
        if hits >= 1 && !upper.contains("RAPORT FISCAL") && !upper.contains("Z NR:") {
            return true
        }
        return false
    }

    /// Mesaj pentru utilizator când parse-ul e incomplet.
    nonisolated static func importQualityMessage(for data: ZReportData, ocrText: String) -> String? {
        if isAppScreenshot(ocrText) {
            return "Ai fotografiat ecranul aplicației. Fotografiază bonul Z tipărit (hârtie), nu telefonul."
        }
        if !looksLikeZReceipt(ocrText) {
            return retakeHint(for: data, base: "Nu recunosc un Raport Z — poză prea neclară sau tăiată. Include tot bonul, cu header și subsol (DATA/ORA).")
        }
        if data.zNumber == 0 {
            return retakeHint(for: data, base: "Nr. Z negăsit — verifică că se vede „Z NR:0144” sus pe bon.")
        }
        if data.cui.isEmpty,
           FirmaRegistry.profile(matchingName: data.firma) == nil,
           !Conturi.isNectarieFirma(data.firma) {
            return "Firmă necunoscută (CIF negăsit) — verifică denumirea sau corectează manual schema 8/10 rânduri."
        }
        // Bon echilibrat = datele numerice sunt consistente; nu mai verifica etichete OCR/PDF.
        if data.isBalanced { return nil }
        if data.parseSource == .digitalPDF { return nil }

        let missing = labelsWithMissingAmounts(in: validationLines(from: ocrText))
        if !missing.isEmpty {
            return retakeHint(
                for: data,
                base: "Sume negăsite (text fără cifre) lângă: \(missing.joined(separator: ", "))."
            )
        }
        return retakeHint(for: data, base: "Date incomplete (diferență la total) — corectează manual.")
    }

    nonisolated private static func retakeHint(for data: ZReportData, base: String) -> String {
        guard data.parseSource != .digitalPDF else { return base }
        return base + " Refă poza cu 2× zoom."
    }

    /// Parse suficient de bun → skip pass-ul OCR „accurate” (mai rapid).
    nonisolated static func isConfidentParse(_ data: ZReportData, ocrText: String) -> Bool {
        ocrCandidateScore(data, ocrText: ocrText).trusted
    }

    struct OCRCandidateScore {
        var overall: Int
        var trusted: Bool
    }

    /// Scor pentru alegerea celui mai bun pass OCR (mai mare = mai bun).
    nonisolated static func ocrCandidateScore(_ data: ZReportData, ocrText: String) -> OCRCandidateScore {
        let lines = validationLines(from: ocrText)
        let missing = labelsWithMissingAmounts(in: lines)
        var score = parseScore(data, ocrText: ocrText)
        if data.isBalanced { score += 10 }
        if missing.isEmpty { score += 8 }
        let trusted = looksLikeZReceipt(ocrText)
            && data.zNumber > 0
            && data.totalVanzari > 0
            && data.isBalanced
            && missing.isEmpty
            && requiredNumericFieldsPresent(data, ocrText: ocrText)
        if trusted { score += 15 }
        return OCRCandidateScore(overall: score, trusted: trusted)
    }

    /// Linii normalizate pentru validare (focus pe segmentul Raport Z).
    nonisolated static func validationLines(from ocrText: String) -> [String] {
        normalizeLines(focusOnZReport(ocrText))
    }

    /// Etichete de pe bon care apar fără sumă numerică lângă ele (OCR a citit text, nu cifre).
    nonisolated static func labelsWithMissingAmounts(in lines: [String]) -> [String] {
        var missing: [String] = []
        let upper = lines.joined(separator: "\n").uppercased()

        func mentioned(_ fragments: [String]) -> Bool {
            fragments.contains { upper.contains($0) }
        }

        func missingLabel(_ name: String, patterns: [String], hasAmount: Bool) {
            guard mentioned(patterns.map { $0.uppercased() }), !hasAmount else { return }
            missing.append(name)
        }

        let sameLine = extractSameLineVanzAmounts(in: lines)

        missingLabel(
            "Vânzări 21% (A)",
            patterns: ["VANZ - A", "VANZ A", "TOTAL VANZ - A"],
            hasAmount: !(sameLine["A"] ?? []).isEmpty
                || amountNearLabel([
                    "VAL. TOTAL VANZ - A", "VAL TOTAL VANZ - A", "TOTAL VANZ - A"
                ], in: lines) != nil
        )
        missingLabel(
            "Vânzări 11% (B)",
            patterns: ["VANZ - B", "VANZ B", "TOTAL VANZ - B"],
            hasAmount: !(sameLine["B"] ?? []).isEmpty
                || amountNearLabel([
                    "VAL. TOTAL VANZ - B", "VAL TOTAL VANZ - B", "TOTAL VANZ - B"
                ], in: lines) != nil
        )
        if mentioned(["VANZ - D", "VANZ D", "TOTAL VANZ - D"]) {
            missingLabel(
                "Vânzări 0% (D)",
                patterns: ["VANZ - D", "VANZ D"],
                hasAmount: !(sameLine["D"] ?? []).isEmpty
                    || amountNearLabel([
                        "VAL. TOTAL VANZ - D", "VAL TOTAL VANZ - D", "TOTAL VANZ - D"
                    ], in: lines) != nil
            )
        }
        missingLabel(
            "Total vânzări",
            patterns: ["TOTAL VANZARI", "VAL. TOTAL VANZARI"],
            hasAmount: readOCRTotalVanzari(from: lines) != nil
        )
        missingLabel(
            "Numerar",
            patterns: ["NUMERAR"],
            hasAmount: !paymentAmounts(
                labelPatterns: [#"\bNUMERAR\b"#],
                in: lines,
                skipIfMatchContains: ["RETRAGERI", "AVANS", "SERTAR"]
            ).filter { $0 > 0 }.isEmpty
        )
        missingLabel(
            "Card",
            patterns: ["CREDIT CARD", "CREDIT CARDS", "CARD"],
            hasAmount: cardAmountPresent(in: lines)
        )
        if mentioned(["PLATA MODERN", "PLATA MODERNA"]) {
            missingLabel(
                "Plată modernă",
                patterns: ["PLATA MODERN"],
                hasAmount: !paymentAmounts(
                    labelPatterns: [#"PLATA\s+MODERN[AĂ]?"#],
                    in: lines,
                    skipIfMatchContains: []
                ).filter { $0 >= 0 }.isEmpty
            )
        }

        return missing
    }

    /// Card POS digital: „Credit cards” cu sumă; ignoră „Card masă” / tichete fără sumă.
    nonisolated private static func cardAmountPresent(in lines: [String]) -> Bool {
        paymentAmounts(
            labelPatterns: [#"\bCREDIT\s+CARDS?\b"#],
            in: lines,
            skipIfMatchContains: []
        ).contains(where: { $0 > 0 })
            || paymentAmounts(
                labelPatterns: [#"\bCARD\b"#],
                in: lines,
                skipIfMatchContains: ["MASA", "TICHET", "CREDIT"]
            ).contains(where: { $0 > 0 })
    }

    /// Categoriile menționate pe bon au valori numerice în model (nu doar etichete OCR).
    nonisolated private static func requiredNumericFieldsPresent(_ data: ZReportData, ocrText: String) -> Bool {
        let upper = ocrText.uppercased()
        if upper.contains("VANZ - A") || upper.contains("VANZ A"), data.vanzari21 <= 0 { return false }
        if upper.contains("VANZ - B") || upper.contains("VANZ B"), data.vanzari11 <= 0 { return false }
        if upper.contains("VANZ - C") || upper.contains("VANZ C"), data.vanzari11C <= 0 { return false }
        if data.numerar + data.card + data.plataModerna + data.altePlati <= 0 { return false }
        if data.sumaVanzariCategorii <= 0 { return false }
        return true
    }

    /// Scor calitate parse (pentru alegerea între pass rapid vs. accurate).
    nonisolated static func parseScore(_ data: ZReportData, ocrText: String) -> Int {
        let upper = ocrText.uppercased()
        var score = 0
        if data.zNumber > 0 { score += 2 }
        if data.totalVanzari > 0 { score += 2 }
        if data.numerar + data.card + data.plataModerna + data.altePlati > 0 { score += 1 }
        if data.sumaVanzariCategorii > 0 { score += 1 }
        if data.isBalanced { score += 2 }
        if upper.contains("DATA") || data.printDateTime != nil { score += 1 }
        if upper.contains("VAL") && upper.contains("VANZ") { score += 1 }
        return score
    }

    // MARK: - Sales / TVA

    private struct SalesResolved {
        var a: Decimal = 0
        var b: Decimal = 0
        var c: Decimal = 0
        var d: Decimal = 0
        var tvaA: Decimal = 0
        var tvaB: Decimal = 0
        var tvaC: Decimal = 0
        var total: Decimal = 0

        nonisolated init(
            a: Decimal = 0,
            b: Decimal = 0,
            c: Decimal = 0,
            d: Decimal = 0,
            tvaA: Decimal = 0,
            tvaB: Decimal = 0,
            tvaC: Decimal = 0,
            total: Decimal = 0
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.tvaA = tvaA
            self.tvaB = tvaB
            self.tvaC = tvaC
            self.total = total
        }
    }

    nonisolated private static func parseSalesAndVAT(into data: inout ZReportData, lines: [String]) {
        let resolved = parseDirectFromZLabels(lines: lines)
            ?? parseOrderedSalesBlock(lines: lines)
            ?? resolveSalesAndVAT(from: lines)
        data.vanzari21 = resolved.a
        data.vanzari11 = resolved.b
        data.vanzari11C = resolved.c
        data.vanzari0 = resolved.d
        data.tva21 = resolved.tvaA
        data.tva11 = resolved.tvaB
        data.tva11C = resolved.tvaC
        if resolved.total > 0 {
            data.totalVanzari = resolved.total
        }
    }

    /// Citește sumele strict de pe etichetele fixe de pe bonul Z (aceeași linie / linia următoare).
    nonisolated private static func parseDirectFromZLabels(lines: [String]) -> SalesResolved? {
        let tol = { (ref: Decimal) in max(Decimal(string: "0.50")!, ref * Decimal(string: "0.008")!) }

        var a: Decimal?
        var b: Decimal?
        var c: Decimal?
        var zeroCat: Decimal?

        for line in lines {
            let u = line.uppercased()
            if u.contains("IN SERTAR") || u.contains("CLIENTI COD") { continue }

            if u.contains("SCUTIT") && (u.contains("- S") || u.contains("TVA S") || u.contains("DE TUR")) {
                if let v = decimals(in: line).last { zeroCat = v }
                continue
            }

            let isVanzCatLine = u.contains("VANZ -") || u.contains("VANZ-") || u.contains("TOTAL VANZ -")
                || u.contains("VAL. TOTAL VANZ")
                || u.range(of: #"(?:URN[ZM2]|VANZ|VEN2|EM2|AN2|LEN2)\s*-\s*[ABCDSR8]"#, options: .regularExpression) != nil
            if isVanzCatLine {
                if u.contains("- E") || u.contains("ALTE TAXE") { continue }
                if u.contains("- A") || u.contains("- R") || u.contains("VANZ A")
                    || u.range(of: #"(?:VANZ|VEC|VEN2|EM2|AN2|AM2|LEN2|URN2)\s*-\s*A"#, options: .regularExpression) != nil {
                    if let v = amountFromVanzCategoryLine(line) { a = v }
                } else if u.contains("- B") || u.contains("VANZ B") || u.contains("LANZ - B")
                    || u.contains("VANZ - 8") || u.contains("TOTAL VANZ - 8")
                    || u.range(of: #"(?:VANZ|VEC|VEN2|EM2|AN2|AM2|LEN2|VFN2|URN[ZM2])\s*-\s*[B8]"#, options: .regularExpression) != nil
                    || u.range(of: #"\s-\s*B\s"#, options: .regularExpression) != nil {
                    if let v = decimals(in: line).last { b = v }
                } else if u.contains("- C") || u.contains("VANZ C")
                    || u.range(of: #"(?:VANZ|VEC|VEN2|EM2|AN2|AM2|LEN2|URN2)\s*-\s*C"#, options: .regularExpression) != nil {
                    if let v = amountFromVanzCategoryLine(line) ?? decimals(in: line).last { c = v }
                } else if u.contains("- D") {
                    // Impex: categoria 0% e pe SCUTIT - S; linia D e adesea zgomot OCR (ex. 8.00).
                    if zeroCat == nil, let v = decimals(in: line).last, v > 50 { zeroCat = v }
                } else if u.contains("- S") || (u.contains("SCUTIT") && u.contains(" S")) {
                    if let v = decimals(in: line).last, v > 0 { zeroCat = v }
                }
            }
            if u.contains("SCUTIT") && (u.contains("- S") || u.contains("TVA S") || u.contains("DE TUR") || u.contains("DE IVA") || u.contains("DE TUA")) {
                if let v = decimals(in: line).last, v > 0 { zeroCat = v }
            }
        }

        a = a ?? readLabeledAmount(
            ["VAL. TOTAL VANZ - A", "TOTAL VANZ - A", "VANZ - A"],
            in: lines
        )
        b = b ?? readLabeledAmount(
            ["VAL. TOTAL VANZ - B", "TOTAL VANZ - B", "VANZ - B", "TOTAL LANZ - B", "VANZ - 8", "TOTAL VANZ - 8"],
            in: lines
        )
        let cVal = c ?? readLabeledAmount(
            ["VAL. TOTAL VANZ - C", "TOTAL VANZ - C", "VANZ - C"],
            in: lines
        ) ?? 0
        let zeroCatVal: Decimal = {
            if let zeroCat { return zeroCat }
            if let read = readLabeledAmount(
                [
                    "VAL. TOTAL SCUTIT", "TOTAL SCUTIT", "SCUTIT DE TUR", "SCUTIT DE IVA",
                    "VAL. TOTAL VANZ - S", "TOTAL VANZ - S", "VANZ - S"
                ],
                in: lines
            ) { return read }
            if !lines.contains(where: { $0.uppercased().contains("SCUTIT") }),
               let d = readLabeledAmount(["VAL. TOTAL VANZ - D", "TOTAL VANZ - D"], in: lines) {
                return d
            }
            return 0
        }()

        guard let total = readLabeledAmount(
            ["VAL. TOTAL VANZARI", "TOTAL VANZARI", "VFL. TOTAL VANZARI", "VANZAR:", "VANZAR"],
            in: lines,
            excludeLineContains: ["CLIENTI", "COD FISCAL"]
        ), total > 0 else { return nil }

        let aVal: Decimal = {
            if let a, a >= 100 { return a }
            if let bVal = b, bVal > 0, zeroCatVal > 0 {
                let inferred = total - bVal - zeroCatVal
                if inferred >= 100 { return inferred }
            }
            return a ?? Decimal.zero
        }()
        var bVal = b ?? 0
        var dVal = zeroCatVal

        // OCR „054.20” în loc de 654.20 — completează B din Total − A − C − S.
        if aVal > 0, dVal > 0, total > 0 {
            let inferredB = total - aVal - cVal - dVal
            if inferredB >= 100,
               (bVal == 0 || bVal < 100 || abs(aVal + bVal + cVal + dVal - total) > tol(total)),
               abs(inferredB + aVal + cVal + dVal - total) <= tol(total) {
                bVal = inferredB
            }
        }

        // Completează categoria 0% din total + A + B + C când OCR a citit greșit SCUTIT.
        if aVal > 0, bVal > 0, total > 0 {
            let inferredD = total - aVal - bVal - cVal
            if inferredD >= 0,
               abs(aVal + bVal + cVal + dVal - total) > Decimal(string: "0.03")!,
               abs(inferredD + aVal + bVal + cVal - total) <= tol(total) {
                dVal = inferredD
            }
        }

        guard aVal > 0 || bVal > 0 || cVal > 0 || dVal > 0 else { return nil }

        let sum = aVal + bVal + cVal + dVal
        guard abs(sum - total) <= tol(total) else { return nil }

        var resolved = SalesResolved(a: aVal, b: bVal, c: cVal, d: dVal, total: total)

        if aVal > 0 {
            if let tvaA = readLabeledAmount(["TOTAL TVA A", "TOTA. TVA A", "TVA A - 21", "L TVA A"], in: lines),
               tvaA > 30, isPlausibleVAT(sales: aVal, vat: tvaA, rate: 0.21) {
                resolved.tvaA = tvaA
            } else {
                resolved.tvaA = expectedVAT(sales: aVal, rate: 0.21)
            }
        }
        if bVal > 0 {
            if let tvaB = readLabeledAmount(["TOTAL TVA B", "TVH B", "TVA B - 11"], in: lines),
               tvaB > 10, isPlausibleVAT(sales: bVal, vat: tvaB, rate: 0.11) {
                resolved.tvaB = tvaB
            } else {
                resolved.tvaB = expectedVAT(sales: bVal, rate: 0.11)
            }
        }
        if cVal > 0 {
            if let tvaC = readLabeledAmount(["TOTAL TVA C", "TVA C - 11"], in: lines),
               tvaC > 10, isPlausibleVAT(sales: cVal, vat: tvaC, rate: 0.11) {
                resolved.tvaC = tvaC
            } else {
                resolved.tvaC = expectedVAT(sales: cVal, rate: 0.11)
            }
        }
        return resolved
    }

    /// Sumă de pe linia cu eticheta (nu din combinatorică / alte coloane OCR).
    nonisolated private static func readLabeledAmount(
        _ labels: [String],
        in lines: [String],
        excludeLineContains: [String] = []
    ) -> Decimal? {
        let labelsU = labels.map { $0.uppercased() }
        for line in lines {
            let u = line.uppercased()
            if excludeLineContains.contains(where: { u.contains($0) }) { continue }
            guard labelsU.contains(where: { u.contains($0) || fuzzyContains(u, $0) }) else { continue }
            if u.contains("%") && (u.contains("TVA A") || u.contains("TVA B")) && !u.contains("TOTAL TVA") {
                let vals = decimals(in: line)
                if vals.isEmpty || vals.allSatisfy({ $0 <= 30 }) { continue }
            }
            let vals = decimals(in: line)
            if let last = vals.last { return last }
        }
        return amountNearLabel(labels, in: lines, skipIfLineContains: excludeLineContains)
    }

    /// Bon Impex / layout fix: A, B, S, Total, TVA A, TVA B ca linii consecutive (OCR fără etichete clare).
    nonisolated private static func parseOrderedSalesBlock(lines: [String]) -> SalesResolved? {
        var amounts: [Decimal] = []
        var inBlock = false

        for line in lines {
            let u = line.uppercased()
            if u.contains("TVA A") && u.contains("%") && !u.contains("TOTAL TVA") {
                inBlock = true
                continue
            }
            if u.contains("VAL. TOTAL VANZ") || u.contains("TOTAL VANZ -") || u.contains("VANZ -") {
                inBlock = true
            }
            if u.contains("NUMERAR") || u.contains("CLIENTI COD") || u.contains("NR. BONURI") {
                if amounts.count >= 4 { break }
            }
            if !inBlock { continue }

            if u.contains("NUMERAR") || u.contains("CARD") || u.contains("PLATA MODERN") {
                if amounts.count >= 4 { break }
            }

            let vals = decimals(in: line)
            if vals.count == 1 {
                amounts.append(vals[0])
            } else if vals.count > 1, u.contains("VANZ") || u.contains("TVA") || u.contains("TOTAL") {
                amounts.append(vals.last!)
            }
        }

        guard amounts.count >= 4 else { return nil }
        let hasScutitLabel = lines.contains { $0.uppercased().contains("SCUTIT") }

        for start in 0..<(amounts.count - 3) {
            let a = amounts[start]
            let b = amounts[start + 1]
            let third = amounts[start + 2]
            let total = amounts[start + 3]
            guard a > 10, b > 10, total > 10 else { continue }
            if hasScutitLabel, third < 50 { continue }

            let tol = max(Decimal(string: "1")!, total * Decimal(string: "0.015")!)
            if abs(a + b + third - total) <= tol {
                var resolved = SalesResolved(a: a, b: b, d: third, total: total)
                if start + 4 < amounts.count {
                    resolved.tvaA = amounts[start + 4]
                }
                if start + 5 < amounts.count {
                    resolved.tvaB = amounts[start + 5]
                }
                if resolved.tvaA == 0, a > 0 { resolved.tvaA = expectedVAT(sales: a, rate: 0.21) }
                if resolved.tvaB == 0, b > 0 { resolved.tvaB = expectedVAT(sales: b, rate: 0.11) }
                return resolved
            }
        }
        return nil
    }

    nonisolated private static func parseOrderedPayments(from lines: [String], salesTotal: Decimal) -> PayTriple? {
        guard salesTotal > 0 else { return nil }
        let tol = max(Decimal(string: "0.50")!, salesTotal * Decimal(string: "0.008")!)

        var labeled: PayTriple?
        let numerarL = readLabeledAmount(["NUMERAR"], in: lines, excludeLineContains: ["RETRAGERI", "SERTAR"])
        let cardL = readLabeledAmount(["CARD"], in: lines)
        let modernaL = readLabeledAmount(["PLATA MODERN"], in: lines) ?? 0
        if let numerarL, let cardL, abs(numerarL + cardL + modernaL - salesTotal) <= tol {
            labeled = PayTriple(numerar: numerarL, card: cardL, moderna: modernaL)
        } else if let numerarL, abs(numerarL + (cardL ?? 0) + modernaL - salesTotal) <= tol {
            labeled = PayTriple(numerar: numerarL, card: cardL ?? 0, moderna: modernaL)
        }
        if let labeled { return labeled }

        var amounts: [Decimal] = []
        for line in lines {
            let u = line.uppercased()
            if u.contains("NUMERAR") || u.contains("CARD") || u.contains("PLATA MODERN") {
                if let v = decimals(in: line).last { amounts.append(v) }
                continue
            }
            let vals = decimals(in: line)
            if vals.count == 1, line.filter({ $0.isLetter }).count <= 2 {
                amounts.append(vals[0])
            }
        }

        for i in 0..<amounts.count {
            for j in (i + 1)..<amounts.count {
                let n = amounts[i], c = amounts[j]
                if n >= 0, c >= 0, abs(n + c - salesTotal) <= tol {
                    return PayTriple(numerar: n, card: c, moderna: 0)
                }
            }
        }
        if amounts.count == 1, abs(amounts[0] - salesTotal) <= tol {
            return PayTriple(numerar: 0, card: amounts[0], moderna: 0)
        }
        return nil
    }

    /// Alege A/B/D + TVA prin candidați OCR + scor (total + cote TVA), nu prin ordinea liniilor.
    nonisolated private static func resolveSalesAndVAT(from lines: [String]) -> SalesResolved {
        // 1) Preferă „VAL. TOTAL VANZ - A  177.50” pe aceeași linie (cel mai fiabil pe Z).
        let sameLine = extractSameLineVanzAmounts(in: lines)
        let paired = collectPairedVanzAmounts(in: lines)

        // Bloc clar A/B/D pe linii separate — folosit direct (evită inferența greșită în D).
        if let trusted = parseTrustedSalesBlock(
            sameLine: sameLine, paired: paired, lines: lines
        ) {
            return trusted
        }

        var aCands = sameLine["A"] ?? []
        var bCands = sameLine["B"] ?? []
        var dCands = sameLine["D"] ?? []

        aCands += paired["A"] ?? []
        bCands += paired["B"] ?? []
        dCands += paired["D"] ?? []

        aCands += amountsNearAllLabels([
            "VAL. TOTAL VANZ - A", "VAL TOTAL VANZ - A", "VAL. TOTAL VANZ A", "TOTAL VANZ - A"
        ], in: lines, maxAhead: 4)
        bCands += amountsNearAllLabels([
            "VAL. TOTAL VANZ - B", "VAL TOTAL VANZ - B", "VAL. TOTAL VANZ B", "TOTAL VANZ - B"
        ], in: lines, maxAhead: 4)
        dCands += amountsNearAllLabels([
            "VAL. TOTAL VANZ - D", "VAL TOTAL VANZ - D", "VAL. TOTAL VANZ D", "TOTAL VANZ - D",
            "VAL. TOTAL VANZ - S", "VAL TOTAL VANZ - S", "VAL. TOTAL VANZ S", "TOTAL VANZ - S"
        ], in: lines, maxAhead: 4)

        var totalCands = extractSameLineLabeledAmounts(
            patterns: [
                #"VAL\.?\s*TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#,
                #"TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#
            ],
            in: lines
        )
        totalCands += amountsNearAllLabels(["TOTAL VANZARI", "VAL. TOTAL VANZARI"], in: lines, maxAhead: 3)

        var tvaACands = extractSameLineLabeledAmounts(
            patterns: [#"TOTAL\s+TVA\s*A(?:\s*-\s*21%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines
        )
        var tvaBCands = extractSameLineLabeledAmounts(
            patterns: [#"TOTAL\s+TVA\s*B(?:\s*-\s*11%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines
        )
        tvaACands += amountsNearAllLabels(["TOTAL TVA A"], in: lines, maxAhead: 5)
        tvaBCands += amountsNearAllLabels(["TOTAL TVA B"], in: lines, maxAhead: 5)
        tvaACands = filterVATRateNoise(uniqueDecimals(tvaACands), nominalRate: 21)
        tvaBCands = filterVATRateNoise(uniqueDecimals(tvaBCands), nominalRate: 11)

        // Bloc clasic A→B→D (când etichetele apar în ordine) — doar ca sursă de candidați.
        if let block = parseLabeledBlock(
            labels: ["VAL. TOTAL VANZ - A", "VAL. TOTAL VANZ - B", "VAL. TOTAL VANZ - D"],
            in: lines,
            valueCount: 10
        ), block.count >= 8 {
            aCands.append(block[0])
            bCands.append(block[1])
            dCands.append(block[2])
            if block.count > 5 { totalCands.append(block[5]) }
            tvaACands.append(block[6])
            tvaBCands.append(block[7])
        }

        tvaACands = filterVATRateNoise(uniqueDecimals(tvaACands), nominalRate: 21)
        tvaBCands = filterVATRateNoise(uniqueDecimals(tvaBCands), nominalRate: 11)

        aCands = uniqueDecimals(aCands)
        bCands = uniqueDecimals(bCands)
        dCands = uniqueDecimals(dCands)
        totalCands = uniqueDecimals(totalCands).filter { $0 > 1 }
        // TVA nu poate fi ≈ totalul vânzărilor (OCR lipește greșit 1770.81 lângă TVA A).
        let maxTotal = totalCands.max() ?? 0
        tvaACands = uniqueDecimals(tvaACands).filter { v in
            v >= 0 && (maxTotal <= 0 || v < maxTotal * Decimal(string: "0.30")!)
        }
        tvaBCands = uniqueDecimals(tvaBCands).filter { v in
            v >= 0 && (maxTotal <= 0 || v < maxTotal * Decimal(string: "0.30")!)
        }

        // Inferă vânzări din TVA doar dacă TVA nu e procentul (21.00 / 11.00 citit greșit din header).
        for tva in tvaACands where tva > 25 && tva < 5_000 {
            aCands.append(round2(tva * Decimal(string: "1.21")! / Decimal(string: "0.21")!))
        }
        for tva in tvaBCands where tva > 15 && tva < 5_000 {
            bCands.append(round2(tva * Decimal(string: "1.11")! / Decimal(string: "0.11")!))
        }
        aCands = uniqueDecimals(aCands)
        bCands = uniqueDecimals(bCands)

        var best = pickBestSales(
            a: aCands, b: bCands, d: dCands,
            totals: totalCands, tvaA: tvaACands, tvaB: tvaBCands,
            preferA: sameLine["A"] ?? [],
            preferB: sameLine["B"] ?? [],
            preferD: (sameLine["D"] ?? []) + (sameLine["S"] ?? [])
        )

        if let trusted = parseTrustedSalesBlock(
            sameLine: sameLine, paired: paired, lines: lines
        ) {
            best.a = trusted.a
            best.b = trusted.b
            best.d = trusted.d
            best.tvaA = trusted.tvaA
            best.tvaB = trusted.tvaB
            best.total = trusted.total
        }

        // Preferă valorile de pe aceeași linie cu eticheta.
        if let a = sameLine["A"]?.last { best.a = a }
        if let b = sameLine["B"]?.last { best.b = b }
        if let d = sameLine["D"]?.last { best.d = d }
        else if let s = sameLine["S"]?.last { best.d = s }
        else if let d = paired["D"]?.last { best.d = d }
        else if let s = paired["S"]?.last { best.d = s }

        // TVA final: preferă candidat plauzibil, altfel calculează.
        if best.a > 0 {
            if let match = closestAmount(in: tvaACands, to: expectedVAT(sales: best.a, rate: 0.21), maxDiff: max(1, best.a * Decimal(string: "0.04")!)) {
                best.tvaA = match
            } else {
                best.tvaA = expectedVAT(sales: best.a, rate: 0.21)
            }
        }
        if best.b > 0 {
            if let match = closestAmount(in: tvaBCands, to: expectedVAT(sales: best.b, rate: 0.11), maxDiff: max(1, best.b * Decimal(string: "0.04")!)) {
                best.tvaB = match
            } else {
                best.tvaB = expectedVAT(sales: best.b, rate: 0.11)
            }
        }

        if best.total == 0 || abs(best.total - (best.a + best.b + best.d)) <= 1 {
            best.total = best.a + best.b + best.d
        }

        return best
    }

    /// Când A/B (și eventual D) apar pe linii dedicate și bat totalul — nu ghici din combinatorică.
    nonisolated private static func parseTrustedSalesBlock(
        sameLine: [String: [Decimal]],
        paired: [String: [Decimal]],
        lines: [String]
    ) -> SalesResolved? {
        guard let a = sameLine["A"]?.last ?? paired["A"]?.last,
              let b = sameLine["B"]?.last ?? paired["B"]?.last,
              a > 0, b > 0 else { return nil }

        let d: Decimal = {
            if let v = sameLine["S"]?.last { return v }
            if let v = paired["S"]?.last { return v }
            if let v = readLabeledAmount(["VAL. TOTAL VANZ - S", "TOTAL VANZ - S"], in: lines) { return v }
            if let v = sameLine["D"]?.last { return v }
            if let v = paired["D"]?.last { return v }
            if let v = amountNearLabel([
                "VAL. TOTAL VANZ - D", "VAL TOTAL VANZ - D", "VAL. TOTAL VANZ D", "TOTAL VANZ - D"
            ], in: lines) { return v }
            return 0
        }()

        var totalCands = extractSameLineLabeledAmounts(
            patterns: [
                #"VAL\.?\s*TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#,
                #"TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#
            ],
            in: lines
        )
        totalCands += amountsNearAllLabels(["TOTAL VANZARI", "VAL. TOTAL VANZARI"], in: lines, maxAhead: 2)
        totalCands = uniqueDecimals(totalCands).filter { $0 > 1 }

        let sum = a + b + d
        let total: Decimal
        if let t = totalCands.first(where: { abs($0 - sum) <= max(Decimal(string: "1")!, $0 * Decimal(string: "0.02")!) }) {
            total = t
        } else if let t = totalCands.max(), abs(t - sum) <= max(Decimal(string: "2")!, t * Decimal(string: "0.03")!) {
            total = t
        } else if totalCands.isEmpty {
            total = sum
        } else {
            return nil
        }

        var tvaACands = extractSameLineLabeledAmounts(
            patterns: [#"TOTAL\s+TVA\s*A(?:\s*-\s*21%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines
        )
        var tvaBCands = extractSameLineLabeledAmounts(
            patterns: [#"TOTAL\s+TVA\s*B(?:\s*-\s*11%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines
        )
        tvaACands += amountsNearAllLabels(["TOTAL TVA A"], in: lines, maxAhead: 3)
        tvaBCands += amountsNearAllLabels(["TOTAL TVA B"], in: lines, maxAhead: 3)
        tvaACands = filterVATRateNoise(uniqueDecimals(tvaACands), nominalRate: 21)
        tvaBCands = filterVATRateNoise(uniqueDecimals(tvaBCands), nominalRate: 11)
        tvaACands = uniqueDecimals(tvaACands).filter { $0 < total * Decimal(string: "0.30")! }
        tvaBCands = uniqueDecimals(tvaBCands).filter { $0 < total * Decimal(string: "0.30")! }

        var resolved = SalesResolved(a: a, b: b, d: d, total: total)
        if a > 0 {
            resolved.tvaA = closestAmount(
                in: tvaACands,
                to: expectedVAT(sales: a, rate: 0.21),
                maxDiff: max(Decimal(string: "1")!, a * Decimal(string: "0.05")!)
            ) ?? expectedVAT(sales: a, rate: 0.21)
        }
        if b > 0 {
            resolved.tvaB = closestAmount(
                in: tvaBCands,
                to: expectedVAT(sales: b, rate: 0.11),
                maxDiff: max(Decimal(string: "1")!, b * Decimal(string: "0.05")!)
            ) ?? expectedVAT(sales: b, rate: 0.11)
        }
        return resolved
    }

    /// Asociază etichete VANZ A/B/D cu sumele care urmează (chiar dacă ordinea e B,A,D).
    nonisolated private static func collectPairedVanzAmounts(in lines: [String]) -> [String: [Decimal]] {
        var pending: [String] = []
        var out: [String: [Decimal]] = ["A": [], "B": [], "D": [], "S": []]
        var expectClass = false

        for line in lines {
            let u = normalizeOCRLine(line).uppercased()

            if u == "TOTAL VANZ" || u == "VAL. TOTAL VANZ" || u == "VAL TOTAL VANZ"
                || u == "VAL."
                || (u.hasSuffix("TOTAL VANZ") && !u.contains("-") && !u.contains("VANZARI")) {
                // OCR uneori: „VAL. TOTAL VANZ  27.50” fără „- D” pe aceeași linie.
                if !u.contains("- A"), !u.contains("- B"), !u.contains("- D"),
                   let value = decimals(in: line).last, value > 0 {
                    out["D", default: []].append(value)
                    continue
                }
                expectClass = true
                continue
            }

            if let kind = vanzKind(from: u, allowBareClass: expectClass) {
                expectClass = false
                pending.append(kind)
                if let value = decimals(in: line).last {
                    out[kind, default: []].append(value)
                    if pending.last == kind { pending.removeLast() }
                }
                continue
            }
            expectClass = false

            if u.contains("CLIENTI") || u.contains("NUMAR BONURI") {
                pending.removeAll()
                continue
            }

            let nums = decimals(in: line)
            if nums.count == 1, let kind = pending.first {
                out[kind, default: []].append(nums[0])
                pending.removeFirst()
            }
        }
        return out
    }

    nonisolated private static func vanzKind(from upper: String, allowBareClass: Bool) -> String? {
        let u = upper
        if u.contains("ALTE") && u.contains("TAX") { return nil }
        if u.contains("SCUTIT") { return nil }
        if u.contains("VANZARI") && !u.contains("VANZ -") { return nil }

        // Evită liniile unde OCR a lipit A și B pe același rând.
        let classHits = ["- A", "- B", "- D", "- S"].filter { u.contains($0) }.count
        if classHits > 1 { return nil }

        let hasVanz = u.contains("VAL. TOTAL VANZ") || u.contains("VAL TOTAL VANZ")
            || u.contains("TOTAL VANZ -") || u.contains("TOTAL VANZ A")
            || u.contains("TOTAL VANZ B") || u.contains("TOTAL VANZ D")
            || u.contains("TOTAL VANZ S") || u.contains("VANZ - S")
            || u.contains("VANZ - A") || u.contains("VANZ - B") || u.contains("VANZ - D")

        let bare = allowBareClass && (
            u == "- A" || u == "- B" || u == "- D" || u == "- S"
                || u == "A" || u == "B" || u == "D" || u == "S"
                || u.hasPrefix("- A") || u.hasPrefix("- B") || u.hasPrefix("- D") || u.hasPrefix("- S")
        )

        guard hasVanz || bare else { return nil }

        if u.contains("- A") || u.hasSuffix(" A") || u.contains("VANZ A") || u == "A" || u == "- A" { return "A" }
        if u.contains("- B") || u.hasSuffix(" B") || u.contains("VANZ B") || u == "B" || u == "- B" { return "B" }
        if u.contains("- S") || u.hasSuffix(" S") || u.contains("VANZ S") || u == "S" || u == "- S" { return "S" }
        if u.contains("- D") || u.hasSuffix(" D") || u.contains("VANZ D") || u == "D" || u == "- D" { return "D" }
        return nil
    }

    nonisolated private static func pickBestSales(
        a: [Decimal], b: [Decimal], d: [Decimal],
        totals: [Decimal], tvaA: [Decimal], tvaB: [Decimal],
        preferA: [Decimal] = [], preferB: [Decimal] = [], preferD: [Decimal] = []
    ) -> SalesResolved {
        let aOpts = Array((a.isEmpty ? [Decimal(0)] : a).prefix(8))
        let bOpts = Array((b.isEmpty ? [Decimal(0)] : b).prefix(8))
        let dOpts = Array((d.isEmpty ? [Decimal(0)] : d).prefix(8))
        let totalOpts: [Decimal?] = totals.isEmpty ? [nil] : totals.map { Optional($0) }
        let prefA = Set(preferA.map { "\($0)" })
        let prefB = Set(preferB.map { "\($0)" })
        let prefD = Set(preferD.map { "\($0)" })

        var best = SalesResolved()
        var bestScore = Int.min

        for aV in aOpts {
            for bV in bOpts {
                for dV in dOpts {
                    let sum = aV + bV + dV
                    if sum == 0 { continue }

                    for totalOpt in totalOpts {
                        let totalV = totalOpt ?? sum
                        var score = 0

                        let diff = abs(sum - totalV)
                        if diff <= Decimal(string: "0.05")! {
                            score += 12
                        } else if diff <= max(Decimal(string: "0.50")!, totalV * Decimal(string: "0.02")!) {
                            score += 8
                        } else if diff <= max(2, totalV * Decimal(string: "0.05")!) {
                            score += 3
                        } else if totalOpt != nil {
                            score -= 10
                        }

                        let expA = expectedVAT(sales: aV, rate: 0.21)
                        let expB = expectedVAT(sales: bV, rate: 0.11)
                        let tvaAPick = closestAmount(in: tvaA, to: expA, maxDiff: max(1, aV * Decimal(string: "0.05")!)) ?? expA
                        let tvaBPick = closestAmount(in: tvaB, to: expB, maxDiff: max(1, bV * Decimal(string: "0.05")!)) ?? expB

                        if aV > 0 {
                            score += isPlausibleVAT(sales: aV, vat: tvaAPick, rate: 0.21) ? 6 : -4
                        }
                        if bV > 0 {
                            score += isPlausibleVAT(sales: bV, vat: tvaBPick, rate: 0.11) ? 6 : -4
                        }

                        if aV > 0, aV == bV, totalV > aV * 3 { score -= 6 }
                        if dV > 0, bV > 0, abs(dV - bV) < Decimal(string: "0.05")!, totalV > dV {
                            score -= 5
                        }
                        if aV > 0, bV == 0, totalV > aV * 2 { score -= 2 }
                        if prefA.contains("\(aV)") { score += 4 }
                        if prefB.contains("\(bV)") { score += 4 }
                        if prefD.contains("\(dV)") { score += 4 }

                        if score > bestScore {
                            bestScore = score
                            best = SalesResolved(
                                a: aV, b: bV, d: dV,
                                tvaA: tvaAPick, tvaB: tvaBPick,
                                total: totalV
                            )
                        }
                    }
                }
            }
        }

        return best
    }

    /// Ex: `VAL. TOTAL VANZ - A  177.50` — toleră OCR: TOTRL, lipsește punct, etc.
    nonisolated private static func extractSameLineVanzAmounts(in lines: [String]) -> [String: [Decimal]] {
        var out: [String: [Decimal]] = ["A": [], "B": [], "D": [], "S": []]
        let pattern = #"(?:VAL\.?\s*)?TOT[A-Z]{2,6}\s+VANZ\s*-\s*([ABDS])(?!\s*-\s*[ABDS])\s*[=:]?\s*(-?\d+\.\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return out
        }
        for line in lines {
            let normalized = normalizeOCRLine(line)
            let u = normalized.uppercased()
            let classCount = ["- A", "- B", "- D"].filter { u.contains($0) }.count
            if classCount > 1 { continue }

            let matches = regex.matches(in: u, range: NSRange(u.startIndex..., in: u))
            for match in matches where match.numberOfRanges >= 3 {
                guard let kr = Range(match.range(at: 1), in: u),
                      let vr = Range(match.range(at: 2), in: u),
                      let value = Decimal(string: String(u[vr])) else { continue }
                out[String(u[kr]), default: []].append(value)
            }
        }
        return out
    }

    nonisolated private static func extractSameLineLabeledAmounts(patterns: [String], in lines: [String]) -> [Decimal] {
        var result: [Decimal] = []
        for line in lines {
            let normalized = normalizeOCRLine(line).uppercased()
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                for match in regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
                where match.numberOfRanges > 1 {
                    guard let r = Range(match.range(at: 1), in: normalized),
                          let value = Decimal(string: String(normalized[r])) else { continue }
                    result.append(value)
                }
            }
        }
        return result
    }

    nonisolated private static func expectedVAT(sales: Decimal, rate: Decimal) -> Decimal {
        guard sales > 0 else { return 0 }
        return round2(sales * rate / (1 + rate))
    }

    nonisolated private static func amountsNearAllLabels(
        _ labels: [String],
        in lines: [String],
        maxAhead: Int
    ) -> [Decimal] {
        var result: [Decimal] = []
        let labelsU = labels.map { $0.uppercased() }
        for (i, line) in lines.enumerated() {
            let u = line.uppercased()
            if u.contains("%") && (u.contains("TVA A") || u.contains("TVA B")) && !u.contains("TOTAL TVA") {
                continue
            }
            guard labelsU.contains(where: { u.contains($0) || fuzzyContains(u, $0) }) else { continue }
            result.append(contentsOf: decimals(in: line))
            var taken = 0
            for j in (i + 1)..<min(i + 1 + maxAhead, lines.count) {
                let next = lines[j]
                let nu = next.uppercased()
                if (nu.contains("VAL. TOTAL VANZ") || nu.contains("TOTAL VANZ -") || nu.contains("TOTAL TVA")
                    || nu.contains("TOTAL VANZARI") || nu.contains("NUMERAR"))
                    && decimals(in: next).isEmpty {
                    break
                }
                let vals = decimals(in: next)
                if vals.count == 1 {
                    result.append(vals[0])
                    taken += 1
                    if taken >= 3 { break }
                }
            }
        }
        return result
    }

    nonisolated private static func uniqueDecimals(_ values: [Decimal]) -> [Decimal] {
        var seen = Set<String>()
        var out: [Decimal] = []
        for v in values {
            let key = "\(v)"
            if seen.insert(key).inserted {
                out.append(v)
            }
        }
        return out
    }

    nonisolated private static func closestAmount(in values: [Decimal], to target: Decimal, maxDiff: Decimal) -> Decimal? {
        guard !values.isEmpty else { return nil }
        var best: Decimal?
        var bestDiff = maxDiff
        for v in values {
            let d = abs(v - target)
            if d <= bestDiff {
                bestDiff = d
                best = v
            }
        }
        return best
    }

    /// TVA din brut cu cotă inclusă: vat ≈ sales * rate/(1+rate)
    nonisolated private static func isPlausibleVAT(sales: Decimal, vat: Decimal, rate: Decimal) -> Bool {
        guard sales > 0 else { return vat == 0 }
        let expected = sales * rate / (1 + rate)
        let diff = abs(expected - vat)
        return diff <= max(Decimal(string: "0.50")!, sales * Decimal(string: "0.03")!)
    }

    nonisolated private static func reconcileVAT(_ data: inout ZReportData) {
        // Nu recalcula TVA din A greșit (ex. A=121 → TVA=21 confundat cu procentul).
        if data.vanzari21 > 0,
           data.tva21 == 0 || !isPlausibleVAT(sales: data.vanzari21, vat: data.tva21, rate: 0.21),
           !isLikelyVATRateAmount(data.tva21, nominalRate: 21) {
            data.tva21 = round2(data.vanzari21 * Decimal(string: "0.21")! / Decimal(string: "1.21")!)
        }
        if data.vanzari11 > 0,
           data.tva11 == 0 || !isPlausibleVAT(sales: data.vanzari11, vat: data.tva11, rate: 0.11),
           !isLikelyVATRateAmount(data.tva11, nominalRate: 11) {
            data.tva11 = round2(data.vanzari11 * Decimal(string: "0.11")! / Decimal(string: "1.11")!)
        }
        if data.vanzari11C > 0,
           data.tva11C == 0 || !isPlausibleVAT(sales: data.vanzari11C, vat: data.tva11C, rate: 0.11),
           !isLikelyVATRateAmount(data.tva11C, nominalRate: 11) {
            data.tva11C = round2(data.vanzari11C * Decimal(string: "0.11")! / Decimal(string: "1.11")!)
        }
        if data.vanzari21 == 0 { data.tva21 = 0 }
        if data.vanzari11 == 0 { data.tva11 = 0 }
        if data.vanzari11C == 0 { data.tva11C = 0 }
    }

    /// Completează categoria C când lipsește din OCR/PDF dar totalul și A/B/D sunt cunoscute.
    nonisolated private static func inferMissingCategoryC(into data: inout ZReportData, lines: [String] = []) {
        if data.vanzari11C == 0, !lines.isEmpty {
            if let read = readLabeledAmount(
                ["VAL. TOTAL VANZ - C", "TOTAL VANZ - C", "VANZ - C", "BRUT C TVA 11"],
                in: lines
            ), read > 0 {
                data.vanzari11C = read
            }
        }
        if data.tva11C == 0, !lines.isEmpty {
            if let read = readLabeledAmount(
                ["TOTAL TVA C", "TVA C - 11", "TVA C 11"],
                in: lines
            ), read > 0 {
                data.tva11C = read
            }
        }
        if data.vanzari11C == 0, data.totalVanzari > 0 {
            let partial = data.vanzari21 + data.vanzari11 + data.vanzari0
            if partial > 0, partial < data.totalVanzari {
                let inferred = data.totalVanzari - partial
                let tol = max(Decimal(string: "0.50")!, data.totalVanzari * Decimal(string: "0.008")!)
                if inferred > Decimal(string: "1")!,
                   abs(partial + inferred - data.totalVanzari) <= tol {
                    data.vanzari11C = inferred
                }
            }
        }
        if data.tva11C == 0, data.vanzari11C > 0 {
            data.tva11C = expectedVAT(sales: data.vanzari11C, rate: 0.11)
        }
    }

    /// Când A+B+D ≠ total OCR / încasări, corectează automat (ex. A=121 din TVA 21% confundat cu cotă).
    nonisolated private static func reconcileControl(into data: inout ZReportData, lines: [String]) {
        let payments = data.numerar + data.card + data.plataModerna
        let ocrTotal = readOCRTotalVanzari(from: lines) ?? 0

        let tol = { (ref: Decimal) in max(Decimal(string: "0.50")!, ref * Decimal(string: "0.005")!) }

        // Total de referință: preferă linia VAL. TOTAL VANZARI; altfel încasările dacă sunt coerente.
        var reference: Decimal?
        if ocrTotal > 0, payments > 0, abs(ocrTotal - payments) <= tol(ocrTotal) {
            reference = ocrTotal
        } else if ocrTotal > 0 {
            reference = ocrTotal
        } else if payments > 0 {
            reference = payments
        }

        guard let ref = reference, ref > 10 else { return }

        let tvaA = readTotalTVA(category: "A", lines: lines)
        let tvaB = readTotalTVA(category: "B", lines: lines)

        // TVA din linia TOTAL TVA A/B (mai sigură decât header „TVA A - 21.00%”).
        if let tvaA, !isLikelyVATRateAmount(tvaA, nominalRate: 21) {
            data.tva21 = tvaA
        }
        if let tvaB, !isLikelyVATRateAmount(tvaB, nominalRate: 11) {
            data.tva11 = tvaB
        }

        var a = data.vanzari21
        var b = data.vanzari11
        let d = data.vanzari0

        // A din TVA dacă e plauzibil și bate controlul.
        if let tvaA, tvaA > 25 {
            let aFromTVA = round2(tvaA * Decimal(string: "1.21")! / Decimal(string: "0.21")!)
            if isPlausibleVAT(sales: aFromTVA, vat: tvaA, rate: 0.21),
               abs(aFromTVA + b + d - ref) <= tol(ref) {
                a = aFromTVA
            }
        }

        // B din TVA dacă lipsește sau e suspect.
        if let tvaB, tvaB > 15, b == 0 || !isPlausibleVAT(sales: b, vat: tvaB, rate: 0.11) {
            let bFromTVA = round2(tvaB * Decimal(string: "1.11")! / Decimal(string: "0.11")!)
            if isPlausibleVAT(sales: bFromTVA, vat: tvaB, rate: 0.11) {
                b = bFromTVA
            }
        }

        let sum = a + b + d
        if abs(sum - ref) > tol(ref) {
            // B+D de obicei sunt citite bine — completează A din diferență.
            let bOk = b > 0 && isPlausibleVAT(sales: b, vat: data.tva11, rate: 0.11)
            let dOk = d >= 0 && d <= max(Decimal(string: "150")!, ref * Decimal(string: "0.08")!)
            if bOk {
                let inferredA = round2(ref - b - d)
                if inferredA >= 0, abs(inferredA + b + d - ref) <= tol(ref) {
                    // Preferă A din TVA dacă există și e aproape de diferență.
                    if let tvaA, tvaA > 25 {
                        let aFromTVA = round2(tvaA * Decimal(string: "1.21")! / Decimal(string: "0.21")!)
                        if isPlausibleVAT(sales: aFromTVA, vat: tvaA, rate: 0.21),
                           abs(aFromTVA + b + d - ref) <= tol(ref) {
                            a = aFromTVA
                        } else {
                            a = inferredA
                        }
                    } else {
                        a = inferredA
                    }
                }
            } else if payments > 0, abs(payments - ref) <= tol(ref), bOk || dOk {
                a = max(0, round2(ref - b - d))
            }
        }

        data.vanzari21 = a
        data.vanzari11 = b
        data.vanzari0 = d
        data.totalVanzari = ref

        // Rotunjiri TVA: A+B+D = ref exact dacă B/D sunt deja corecte.
        if b > 0 {
            let exactA = round2(ref - b - d)
            if exactA >= 0 {
                if let tvaA, isPlausibleVAT(sales: exactA, vat: tvaA, rate: 0.21) {
                    a = exactA
                    data.vanzari21 = exactA
                } else if abs(a + b + d - ref) > Decimal(string: "0.03")! {
                    data.vanzari21 = exactA
                    a = exactA
                }
            }
        }

        if a > 0, data.tva21 == 0 || !isPlausibleVAT(sales: a, vat: data.tva21, rate: 0.21) {
            if let tvaA, isPlausibleVAT(sales: a, vat: tvaA, rate: 0.21) {
                data.tva21 = tvaA
            } else {
                data.tva21 = expectedVAT(sales: a, rate: 0.21)
            }
        }
        if b > 0, data.tva11 == 0 || !isPlausibleVAT(sales: b, vat: data.tva11, rate: 0.11) {
            if let tvaB, isPlausibleVAT(sales: b, vat: tvaB, rate: 0.11) {
                data.tva11 = tvaB
            } else {
                data.tva11 = expectedVAT(sales: b, rate: 0.11)
            }
        }
    }

    nonisolated private static func readOCRTotalVanzari(from lines: [String]) -> Decimal? {
        let fromLine = extractSameLineLabeledAmounts(
            patterns: [
                #"VAL\.?\s*TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#,
                #"TOTAL\s+VANZARI\s*[=:]?\s*(-?\d+\.\d{2})"#
            ],
            in: lines
        ).last
        if let fromLine { return fromLine }
        return amountNearLabel(["VAL. TOTAL VANZARI", "TOTAL VANZARI"], in: lines)
    }

    /// Doar linia „TOTAL TVA A - 21%”, nu headerul „TVA A - 21.00%”.
    nonisolated private static func readTotalTVA(category: String, lines: [String]) -> Decimal? {
        let pattern: String
        switch category {
        case "A":
            pattern = #"TOTAL\s+TVA\s*A(?:\s*-\s*21%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#
        case "B":
            pattern = #"TOTAL\s+TVA\s*B(?:\s*-\s*11%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#
        case "C":
            pattern = #"TOTAL\s+TVA\s*C(?:\s*-\s*11%?)?\s*[=:]?\s*(-?\d+\.\d{2})"#
        default:
            return nil
        }
        let amounts = extractSameLineLabeledAmounts(patterns: [pattern], in: lines)
        return filterVATRateNoise(amounts, nominalRate: category == "A" ? 21 : 11).last
    }

    /// Elimină 21.00 / 11.00 citite din „TVA A - 21.00%” (nu sumă TVA).
    nonisolated private static func filterVATRateNoise(_ values: [Decimal], nominalRate: Int) -> [Decimal] {
        values.filter { !isLikelyVATRateAmount($0, nominalRate: nominalRate) }
    }

    nonisolated private static func isLikelyVATRateAmount(_ value: Decimal, nominalRate: Int) -> Bool {
        let rate = Decimal(nominalRate)
        if abs(value - rate) <= Decimal(string: "0.02")! { return true }
        // 21 lei TVA pe bon real ar fi ~121 vânzări — prea mic față de tipic; dar 21.00 exact = cotă.
        if nominalRate == 21, value <= Decimal(string: "22")! { return true }
        if nominalRate == 11, value <= Decimal(string: "12")! && value >= Decimal(string: "10.5")! { return true }
        return false
    }

    nonisolated private static func reconcileTotals(_ data: inout ZReportData, lines: [String]) {
        let sumCategories = data.vanzari21 + data.vanzari11 + data.vanzari11C + data.vanzari0
        // Nu rescrie totalul OCR cu A+B+D greșit — păstrează VAL. TOTAL VANZARI dacă există.
        let ocrTotal = readOCRTotalVanzari(from: lines) ?? 0
        if ocrTotal > 0 {
            data.totalVanzari = ocrTotal
        } else if sumCategories > 0, data.totalVanzari == 0 {
            data.totalVanzari = sumCategories
        } else if sumCategories > 0,
                  abs(data.totalVanzari - sumCategories) <= max(Decimal(string: "0.50")!, sumCategories * Decimal(string: "0.02")!) {
            data.totalVanzari = sumCategories
        }

        // Plăți: nu rescrie dacă parseDirectPayments le-a setat deja.
        let payTarget = data.totalVanzari > 10 ? data.totalVanzari : (ocrTotal > 0 ? ocrTotal : sumCategories)
        if payTarget > 10, data.numerar + data.card + data.plataModerna + data.altePlati == 0 {
            let pays = resolvePayments(from: lines, salesTotal: payTarget)
            data.numerar = pays.numerar
            data.card = pays.card
            data.plataModerna = pays.moderna
        }
        finalizeBacsisPayments(into: &data, lines: lines)
        inferMissingCategoryC(into: &data, lines: lines)
    }

    // MARK: - Payments

    private struct PayTriple {
        var numerar: Decimal
        var card: Decimal
        var moderna: Decimal
    }

    nonisolated private static func parsePayments(into data: inout ZReportData, lines: [String]) {
        let sumCategories = data.vanzari21 + data.vanzari11 + data.vanzari11C + data.vanzari0
        let salesTotal = data.totalVanzari > 0 ? data.totalVanzari : sumCategories
        if let direct = parseDirectPayments(from: lines, salesTotal: salesTotal) {
            data.numerar = direct.numerar
            data.card = direct.card
            data.plataModerna = direct.moderna
            finalizeBacsisPayments(into: &data, lines: lines, salesTotal: salesTotal)
            return
        }
        if let ordered = parseOrderedPayments(from: lines, salesTotal: salesTotal) {
            data.numerar = ordered.numerar
            data.card = ordered.card
            data.plataModerna = ordered.moderna
            finalizeBacsisPayments(into: &data, lines: lines, salesTotal: salesTotal)
            return
        }
        let pays = resolvePayments(from: lines, salesTotal: salesTotal)
        data.numerar = pays.numerar
        data.card = pays.card
        data.plataModerna = pays.moderna
        finalizeBacsisPayments(into: &data, lines: lines, salesTotal: salesTotal)
    }

    /// Schema bacșiș: alte plăți (tichete, voucher, modernă…) → câmp `altePlati`, rând 5113.
    nonisolated private static func finalizeBacsisPayments(
        into data: inout ZReportData,
        lines: [String] = [],
        salesTotal: Decimal? = nil
    ) {
        guard data.usesBacsisSchema else { return }
        let total = salesTotal ?? (data.totalVanzari > 0 ? data.totalVanzari : data.sumaVanzariCategorii)
        guard total > 0 else { return }

        var alte = parseOtherPaymentSum(from: lines)
        if alte == 0 {
            alte = data.plataModerna
        }
        let residual = total - data.numerar - data.card - alte
        if alte == 0, residual > Decimal(string: "0.01")! {
            alte = residual
        } else if abs(residual) <= max(Decimal(string: "0.50")!, total * Decimal(string: "0.008")!) {
            // alte deja include plataModerna
        } else if alte == 0 {
            alte = max(0, total - data.numerar - data.card)
        }
        data.altePlati = alte
        data.plataModerna = 0
    }

    nonisolated private static func parseOtherPaymentSum(from lines: [String]) -> Decimal {
        let labels = [
            "TICHETE MASA", "TICHETE VALORICE", "VOUCHER", "PLATA MODERN", "PLATA MIDERNA",
            "AVANS IN NUMERAR", "ALTE METODE", "CREDIT"
        ]
        var sum: Decimal = 0
        for line in lines {
            let u = line.uppercased()
            if u.contains("IN SERTAR") { continue }
            if u.contains("NUMERAR") && !u.contains("AVANS") { continue }
            if u.contains("CREDIT") && u.contains("CARD") { continue }
            if u.contains("CARD") && !u.contains("TICHET") && !u.contains("VOUCHER") { continue }
            guard labels.contains(where: { u.contains($0) }) else { continue }
            if let v = decimals(in: line).filter({ $0 > 0 }).last {
                sum += v
            }
        }
        return sum
    }

    nonisolated private static func parseDirectPayments(from lines: [String], salesTotal: Decimal) -> PayTriple? {
        guard salesTotal > 0 else { return nil }
        let tol = max(Decimal(string: "0.50")!, salesTotal * Decimal(string: "0.008")!)

        if let sertar = parseSertarBlockPayments(from: lines, salesTotal: salesTotal, tolerance: tol) {
            return sertar
        }

        var numerar: Decimal?
        var card: Decimal?
        var moderna: Decimal?

        for line in lines {
            let u = line.uppercased()
            if u.contains("IN SERTAR") || u.contains("AVANS") { continue }

            if u.contains("NUMERAR") || u.hasPrefix("ERAR") || u.contains(" NMERAR") || u.contains("FRAR") {
                let vals = decimals(in: line).filter { $0 > 0 }
                if let v = vals.first { numerar = v }
                continue
            }
            if u.contains("CARD") || u.contains("CREDIT") || u.hasPrefix("DIT") || u.hasPrefix("LARD") {
                let vals = decimals(in: line).filter { $0 > 1 }
                if let v = vals.max() {
                    if card == nil || v > card! { card = v }
                }
                continue
            }
            if u.contains("PLATA MODERN") || u.contains("PLATA MIDERNA")
                || (u.contains("MODERNA") && !u.contains("CREDIT")) {
                if let v = decimals(in: line).last {
                    moderna = v
                } else {
                    moderna = 0
                }
            }
        }

        // OCR WhatsApp: sumă card pe linie următoare fără etichetă (ex. „3664.85  VFL” după ERAR).
        if card == nil {
            for (i, line) in lines.enumerated() {
                let u = line.uppercased()
                guard u.hasPrefix("ERAR") || u.contains("NUMERAR") || u.hasPrefix("FRAR") else { continue }
                for j in (i + 1)..<min(i + 5, lines.count) {
                    let next = lines[j].uppercased()
                    if next.contains("VANZ") || next.contains("TOTAL") || next.contains("TVA") { break }
                    let vals = decimals(in: lines[j]).filter { $0 > 100 }
                    if vals.count == 1 {
                        card = vals[0]
                        break
                    }
                }
                if card != nil { break }
            }
        }

        numerar = numerar ?? readLabeledAmount(
            ["NUMERAR", "ERAR"], in: lines, excludeLineContains: ["SERTAR", "AVANS", "IN SERTAR"]
        )
        card = card ?? readLabeledAmount(["CARD", "CREDIT", "DIT"], in: lines)
        let modernaVal = moderna ?? readLabeledAmount(["PLATA MODERN"], in: lines) ?? 0

        guard let cardVal = card else {
            return parseOrderedPayments(from: lines, salesTotal: salesTotal)
        }

        let n = numerar ?? 0
        guard abs(n + cardVal + modernaVal - salesTotal) <= tol else {
            return parseOrderedPayments(from: lines, salesTotal: salesTotal)
        }
        return PayTriple(numerar: n, card: cardVal, moderna: modernaVal)
    }

    /// Bon Impex / OCR fără etichete CARD: sume pe linii după „IN SERTAR” (ex. 312.00 apoi 1056.20).
    nonisolated private static func parseSertarBlockPayments(
        from lines: [String],
        salesTotal: Decimal,
        tolerance: Decimal
    ) -> PayTriple? {
        var amounts: [Decimal] = []
        var inBlock = false

        for line in lines {
            let u = line.uppercased()
            if u.contains("SERTAR") || u.contains("REDUCERI") {
                inBlock = true
                if let v = decimals(in: line).filter({ $0 > 0 }).first { amounts.append(v) }
                continue
            }
            if u.contains("VANZ") || u.contains("URN2") || u.contains("URNZ") || u.contains("SCUTIT")
                || u.contains("TVA A") || u.contains("TOTAL TVA") {
                if inBlock, amounts.count >= 2 { break }
                if inBlock, !amounts.isEmpty { break }
                inBlock = false
                continue
            }
            if !inBlock { continue }
            let vals = decimals(in: line).filter { $0 > 0 }
            if vals.count == 1 { amounts.append(vals[0]) }
        }

        var unique: [Decimal] = []
        for value in amounts where value > 0 {
            if unique.last != value { unique.append(value) }
        }

        guard !unique.isEmpty else { return nil }

        if unique.count >= 2 {
            for i in 0..<unique.count {
                for j in (i + 1)..<unique.count {
                    let n = min(unique[i], unique[j])
                    let c = max(unique[i], unique[j])
                    if abs(n + c - salesTotal) <= tolerance {
                        return PayTriple(numerar: n, card: c, moderna: 0)
                    }
                }
            }
            if abs(unique[0] + unique[1] - salesTotal) <= tolerance {
                return PayTriple(numerar: unique[0], card: unique[1], moderna: 0)
            }
        }
        if unique.count == 1, abs(unique[0] - salesTotal) <= tolerance {
            return PayTriple(numerar: 0, card: unique[0], moderna: 0)
        }
        return nil
    }

    /// Extrage candidați pe etichetă (aceeași linie) și alege combinația care bate totalul vânzărilor.
    nonisolated private static func resolvePayments(from lines: [String], salesTotal: Decimal) -> PayTriple {
        // Candidați „curați”: etichetă urmată imediat de sumă (ex. „NUMERAR  688.00”).
        let numerarClean = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"\bNUMERAR\b\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines,
            skipIfMatchContains: ["RETRAGERI", "AVANS", "SERTAR"],
            captureGroup: 1
        ))
        let cardClean = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"\bCARD\b\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines,
            skipIfMatchContains: [],
            captureGroup: 1
        ))
        let modernaClean = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"PLATA\s+MODERN[AĂ]?\s*[=:]?\s*(-?\d+\.\d{2})"#],
            in: lines,
            skipIfMatchContains: [],
            captureGroup: 1
        ))

        // Candidați laxi (OCR cu etichete lipite pe același rând).
        let numerarLoose = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"\bNUMERAR\b"#],
            in: lines,
            skipIfMatchContains: ["RETRAGERI", "AVANS", "SERTAR"]
        ))
        let cardLoose = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"\bCARD\b"#],
            in: lines,
            skipIfMatchContains: []
        ))
        let modernaLoose = uniqueDecimals(paymentAmounts(
            labelPatterns: [#"PLATA\s+MODERN[AĂ]?"#],
            in: lines,
            skipIfMatchContains: []
        ))

        let numerar = uniqueDecimals(numerarClean + numerarLoose).filter { $0 > 0 }
        let card = uniqueDecimals(cardClean + cardLoose).filter { $0 > 0 }
        let moderna = uniqueDecimals(modernaClean + modernaLoose).filter { $0 > 0 }

        if let best = pickBestPayments(
            numerar: numerar, card: card, moderna: moderna,
            total: salesTotal,
            preferNumerar: numerarClean,
            preferCard: cardClean,
            preferModerna: modernaClean
        ) {
            return best
        }

        return PayTriple(
            numerar: numerarClean.first ?? numerar.first(where: { $0 > 0 }) ?? 0,
            card: cardClean.first ?? card.first(where: { $0 > 0 }) ?? 0,
            moderna: modernaClean.first ?? moderna.first(where: { $0 > 0 }) ?? 0
        )
    }

    nonisolated private static func paymentAmounts(
        labelPatterns: [String],
        in lines: [String],
        skipIfMatchContains: [String],
        captureGroup: Int? = nil
    ) -> [Decimal] {
        var result: [Decimal] = []
        for line in lines {
            let normalized = line
                .replacingOccurrences(of: #"(\d)\.\s+(\d{2})\b"#, with: "$1.$2", options: .regularExpression)
            let u = normalized.uppercased()

            for pattern in labelPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
                let matches = regex.matches(in: u, range: NSRange(u.startIndex..., in: u))
                for match in matches {
                    guard let labelRange = Range(match.range, in: u) else { continue }
                    // Doar contextul dinaintea etichetei (după pot apărea alte coloane OCR).
                    let ctxStart = u.index(labelRange.lowerBound, offsetBy: -22, limitedBy: u.startIndex) ?? u.startIndex
                    let before = String(u[ctxStart..<labelRange.lowerBound])
                    if skipIfMatchContains.contains(where: { before.contains($0) }) { continue }
                    // „NUMERAR IN SERTAR…” — respinge dacă imediat după etichetă vine SERTAR.
                    let afterHead = String(u[labelRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if skipIfMatchContains.contains(where: { afterHead.hasPrefix($0) || afterHead.hasPrefix("IN \($0)") }) {
                        continue
                    }

                    if let captureGroup,
                       match.numberOfRanges > captureGroup,
                       let cap = Range(match.range(at: captureGroup), in: u),
                       let value = Decimal(string: String(u[cap])) {
                        result.append(value)
                        continue
                    }

                    let after = String(normalized[labelRange.upperBound...])
                    // Sar peste alte etichete de plată lipite imediat după (ex. „NUMERAR CARD  313.50”).
                    let afterU = after.uppercased().trimmingCharacters(in: .whitespaces)
                    if afterU.hasPrefix("CARD") || afterU.hasPrefix("CREDIT") || afterU.hasPrefix("TICHETE")
                        || afterU.hasPrefix("VOUCHER") || afterU.hasPrefix("PLATA") {
                        let amounts = decimals(in: after)
                        // Pe rânduri „NUMERAR CARD  a  b” ia primul număr ca numerar doar dacă există ≥2 sume.
                        if afterU.hasPrefix("CARD"), amounts.count >= 2 {
                            result.append(amounts[0])
                        }
                        continue
                    }
                    if let first = decimals(in: after).first {
                        result.append(first)
                        continue
                    }
                    if let intVal = firstIntegerAmount(in: after) {
                        result.append(intVal)
                    }
                }
            }
        }
        return result
    }

    nonisolated private static func firstIntegerAmount(in text: String) -> Decimal? {
        guard let regex = try? NSRegularExpression(pattern: #"[=:]?\s*(\d{2,6})\b"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(match.range(at: 1), in: text),
              let n = Int(text[r]), n > 0 else { return nil }
        return Decimal(n)
    }

    nonisolated private static func pickBestPayments(
        numerar: [Decimal], card: [Decimal], moderna: [Decimal], total: Decimal,
        preferNumerar: [Decimal] = [], preferCard: [Decimal] = [], preferModerna: [Decimal] = []
    ) -> PayTriple? {
        let nOpts = Array((numerar.isEmpty ? [Decimal(0)] : numerar).prefix(8))
        let cOpts = Array((card.isEmpty ? [Decimal(0)] : card).prefix(8))
        let mOpts = Array((moderna.isEmpty ? [Decimal(0)] : moderna).prefix(8))
        let preferN = Set(preferNumerar.map { "\($0)" })
        let preferC = Set(preferCard.map { "\($0)" })
        let preferM = Set(preferModerna.map { "\($0)" })

        var best: PayTriple?
        var bestScore = Int.min

        for n in nOpts where n > 0 {
            for c in cOpts where c >= 0 {
                for m in mOpts where m >= 0 {
                    let sum = n + c + m
                    if sum == 0 { continue }
                    var score = 0
                    if total > 0 {
                        let diff = abs(sum - total)
                        if diff <= Decimal(string: "0.05")! {
                            score += 20
                        } else if diff <= max(Decimal(string: "0.50")!, total * Decimal(string: "0.02")!) {
                            score += 12
                        } else if diff <= max(2, total * Decimal(string: "0.05")!) {
                            score += 4
                        } else {
                            score -= 8
                        }
                    }
                    if total > 50 {
                        if n > 0 { score += 1 }
                        if c > 0 { score += 1 }
                        if m > 0 { score += 1 }
                    }
                    if n > 0, n == c, total > n { score -= 4 }
                    if preferN.contains("\(n)") { score += 3 }
                    if preferC.contains("\(c)") { score += 3 }
                    if preferM.contains("\(m)") { score += 3 }

                    if score > bestScore {
                        bestScore = score
                        best = PayTriple(numerar: n, card: c, moderna: m)
                    }
                }
            }
        }

        if let best, bestScore >= 4 { return best }
        if total <= 0, let best, bestScore > Int.min { return best }
        return bestScore >= 12 ? best : nil
    }

    // MARK: - Firmă

    nonisolated private static func parseCUI(from text: String) -> String? {
        let patterns = [
            #"CIF\s*[:\.]?\s*R?\s*O?\s*(\d{6,10})"#,
            #"CUI\s*[:\.]?\s*R?\s*O?\s*(\d{6,10})"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            if let normalized = FirmaRegistry.normalizeCUI(String(text[range])) {
                return normalized
            }
        }
        return nil
    }

    nonisolated private static func parseCompanyName(from fullText: String, focused: String) -> String {
        if let named = matchCompanyPattern(in: fullText) ?? matchCompanyPattern(in: focused) {
            return named
        }

        let source = fullText
        let upper = source.uppercased()
        if let raport = upper.range(of: "RAPORT FISCAL ZILNIC") {
            let before = String(source[..<raport.lowerBound])
            let headerLines = normalizeLines(before).suffix(8)
            var parts: [String] = []
            for line in headerLines.reversed() {
                let u = line.uppercased()
                if u.contains("CIF") { continue }
                if u.contains("STR.") || u.contains("JUD.") || u.contains("SECTOR")
                    || u.contains("MUNICIP") || u.contains("ALEEA") || u.contains("P-TA")
                    || u.contains("BUCURESTI") || u.contains("PLOIESTI") {
                    continue
                }
                if looksLikeGarbageOCR(line) { continue }
                if line.count >= 3 { parts.insert(line, at: 0) }
                if parts.joined(separator: " ").count > 8 { break }
            }
            let name = parts.joined(separator: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !looksLikeGarbageOCR(name) { return name }
        }

        for line in normalizeLines(focused).prefix(5) {
            let u = line.uppercased()
            if looksLikeGarbageOCR(line) { continue }
            if FirmaRegistry.isReceiptHeaderLabel(line) { continue }
            if u.contains("S.R.L") || u.contains("SRL") || u.contains("S.A") {
                return line
            }
        }
        return normalizeLines(focused).first(where: {
            !looksLikeGarbageOCR($0) && !FirmaRegistry.isReceiptHeaderLabel($0)
        }) ?? ""
    }

    nonisolated private static func looksLikeGarbageOCR(_ line: String) -> Bool {
        let u = line.uppercased()
        if u.count <= 2 { return true }
        // Ex: "11. &GT(11 I:", "GT &I"
        let letters = u.filter { $0.isLetter }.count
        let symbols = u.filter { !"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .-&".contains($0) }.count
        if letters < 3 { return true }
        if symbols >= 3 { return true }
        if u.contains("&GT") || u.contains("GT(") { return true }
        return false
    }

    nonisolated private static func matchCompanyPattern(in text: String) -> String? {
        let patterns = [
            #"(NECTARIE[\s\n]{0,20}20XX[VUWY]?[\s\n]{0,10}S\.?\s*R\.?\s*L\.?)"#,
            #"(HOTEL[\s\n]{0,12}IMPE[XY][\s\n]{0,12}(?:S\.?\s*R\.?\s*L\.?|SRL)?)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text) else { continue }
            return Conturi.normalizedFirmaName(
                String(text[range])
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return nil
    }

    // MARK: - Focus Z

    nonisolated private static func focusOnZReport(_ text: String) -> String {
        let upper = text.uppercased()

        // 1) Segment care conține atât RAPORT FISCAL ZILNIC cât și VAL. TOTAL VANZ
        if let vanz = upper.range(of: "VAL. TOTAL VANZ") ?? upper.range(of: "VAL TOTAL VANZ") {
            let before = upper[..<vanz.lowerBound]
            if let raport = before.range(of: "RAPORT FISCAL ZILNIC", options: .backwards) {
                return String(text[raport.lowerBound...])
            }
            // ia ~1200 caractere înainte de vânzări (header + plăți)
            let startIdx = upper.index(vanz.lowerBound, offsetBy: -1200, limitedBy: upper.startIndex) ?? upper.startIndex
            return String(text[startIdx...])
        }

        if let zNR = upper.range(of: #"Z\s*NR\s*[:\.]?\s*\d+"#, options: .regularExpression) {
            let beforeZ = upper[..<zNR.lowerBound]
            let start = beforeZ.range(of: "RAPORT FISCAL ZILNIC", options: .backwards)?.lowerBound
                ?? beforeZ.range(of: "FISCAL ZILNIC", options: .backwards)?.lowerBound
                ?? zNR.lowerBound
            return String(text[start...])
        }
        if let zRange = upper.range(of: "RAPORT FISCAL ZILNIC")
            ?? upper.range(of: "FISCAL ZILNIC") {
            return String(text[zRange.lowerBound...])
        }
        return text
    }

    nonisolated private static func normalizeLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { normalizeOCRLine($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
    }

    /// Corectează greșeli OCR frecvente pe bonurile Z.
    nonisolated private static func normalizeOCRLine(_ line: String) -> String {
        var s = line
            .replacingOccurrences(of: #"(\d)\.\s+(\d{2})\b"#, with: "$1.$2", options: .regularExpression)
        let typos: [(String, String)] = [
            ("TOTRL", "TOTAL"), ("TOTHL", "TOTAL"), ("TOTAl", "TOTAL"),
            ("VANZARI", "VANZARI"), ("REPORT", "RAPORT"), ("PLOTESTI", "PLOIESTI")
        ]
        for (from, to) in typos {
            s = s.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        return s
    }

    nonisolated private static func parseZNumber(in upper: String) -> Int? {
        struct Candidate {
            var score: Int
            var value: Int
        }

        var candidates: [Candidate] = []
        let normalized = foldedUpper(upper)
            .replacingOccurrences(of: "Л", with: "7")
            .replacingOccurrences(of: "N2:", with: "NR:")
            .replacingOccurrences(of: "N2 ", with: "NR ")
            .replacingOccurrences(of: "Z N2", with: "Z NR")

        func addMatches(pattern: String, score: Int, in text: String) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard match.numberOfRanges >= 2,
                      let r = Range(match.range(at: 1), in: text),
                      let n = Int(text[r]), n > 0, n <= 9999 else { continue }
                candidates.append(Candidate(score: score, value: n))
            }
        }

        // Z NR din header (fereastră mică după RAPORT FISCAL ZILNIC).
        if let range = normalized.range(of: "RAPORT FISCAL ZILNIC")
            ?? normalized.range(of: "FISCAL ZILNIC")
            ?? normalized.range(of: "FISCAL ZINC") {
            let window = String(normalized[range.lowerBound...].prefix(500))
            addMatches(pattern: #"Z\s*NR\s*[:\.]?\s*0*(\d{1,4})(?!\d)"#, score: 100, in: window)
            addMatches(pattern: #"NR\s*[:\.]?\s*0*(\d{3,4})(?!\d)"#, score: 92, in: window)
        }

        // Subsol SHA-256 — foarte fiabil (ex. PENTRU Z:0144).
        addMatches(pattern: #"PENTRU\s+Z\s*[:\.]?\s*0*(\d{1,4})(?!\d)"#, score: 95, in: normalized)
        addMatches(pattern: #"PENTRU\s+Z\s*[:\.]?\s*(\d{1,4})"#, score: 93, in: normalized)
        addMatches(pattern: #"Z\s*[:\-]\s*0*(\d{3,4})(?!\d)"#, score: 90, in: normalized)
        addMatches(pattern: #"Z\s*REPORT\s*NO\.?\s*(\d{1,4})"#, score: 106, in: normalized)
        addMatches(pattern: #"Z\s*REPORT\s*NUMAR\s*(\d{1,4})"#, score: 105, in: normalized)
        addMatches(pattern: #"Z\s*NR\s*[:\.]?\s*0*(\d{1,4})(?!\d)"#, score: 80, in: normalized)

        guard !candidates.isEmpty else { return nil }

        // Preferă cea mai bună scor; la egalitate, preferă valoarea mai mică (0144→144, nu 1441).
        let bestScore = candidates.map(\.score).max() ?? 0
        let top = candidates.filter { $0.score == bestScore }
        return top.min(by: { $0.value < $1.value })?.value
    }

    // MARK: - Amount near label

    nonisolated private static func amountNearLabel(
        _ labels: [String],
        in lines: [String],
        skipIfLineContains: [String] = []
    ) -> Decimal? {
        let labelsU = labels.map { $0.uppercased() }
        for (i, line) in lines.enumerated() {
            let u = line.uppercased()
            if skipIfLineContains.contains(where: { u.contains($0) }) { continue }
            guard labelsU.contains(where: { u.contains($0) || fuzzyContains(u, $0) }) else { continue }

            // Aceeași linie
            if let v = decimals(in: line).last { return v }
            // Următoarele linii: ia primul număr „singur” pe linie (layout tipic Z)
            for j in (i + 1)..<min(i + 8, lines.count) {
                let next = lines[j]
                let nu = next.uppercased()
                // Total secțiune plăți (ex. „Total 1.885,12 RON”) — nu e suma etichetei curente.
                if (nu.hasPrefix("TOTAL ") || nu == "TOTAL")
                    && !nu.contains("TVA") && !nu.contains("VANZARI") && !nu.contains("VANZ") {
                    break
                }
                // oprește dacă apare altă etichetă de vânzări/plăți
                if nu.contains("VAL. TOTAL") || nu.contains("TOTAL TVA") || nu.contains("TOTAL VANZARI") {
                    if decimals(in: next).isEmpty { break }
                }
                let vals = decimals(in: next)
                if vals.count == 1 { return vals[0] }
                if vals.count > 1, next.count < 18 { return vals[0] }
            }
        }
        return nil
    }

    // MARK: - Block parser

    nonisolated private static func parseLabeledBlock(
        labels: [String],
        in lines: [String],
        valueCount: Int,
        skipLineIfContains: [String] = []
    ) -> [Decimal]? {
        let labelsU = labels.map { $0.uppercased() }
        guard let start = findLabelSequence(labelsU, in: lines, skipLineIfContains: skipLineIfContains) else {
            return nil
        }

        var values: [Decimal] = []
        var i = start + labels.count
        while i < lines.count, values.count < valueCount {
            let line = lines[i]
            let u = line.uppercased()
            let nums = decimals(in: line)
            if nums.count == 1 {
                values.append(nums[0])
            } else if nums.count > 1, line.count < 24 {
                // o linie cu un singur număr „principal”
                values.append(nums[0])
            } else if u.contains("TOTAL") || u.contains("CLIENTI") || u.contains("NUMAR") {
                // etichete intercalate
            }
            i += 1
            if i > start + labels.count + 45 { break }
        }

        var startIdx = 0
        if values.count > valueCount {
            while startIdx < values.count - valueCount,
                  values[startIdx] == 0,
                  values[startIdx + 1] > 1 {
                startIdx += 1
            }
        }
        let slice = Array(values[startIdx...].prefix(valueCount))
        return slice.count >= min(3, valueCount) ? slice : nil
    }

    nonisolated private static func findLabelSequence(
        _ labels: [String],
        in lines: [String],
        skipLineIfContains: [String]
    ) -> Int? {
        guard !labels.isEmpty else { return nil }
        for i in 0..<lines.count {
            let u = lines[i].uppercased()
            if skipLineIfContains.contains(where: { u.contains($0) }) { continue }
            guard u.contains(labels[0]) || fuzzyContains(u, labels[0]) else { continue }

            var ok = true
            var cursor = i
            for (offset, label) in labels.enumerated() {
                var found = false
                for j in cursor..<min(cursor + 4, lines.count) {
                    let lu = lines[j].uppercased()
                    if skipLineIfContains.contains(where: { lu.contains($0) }) { continue }
                    if lu.contains(label) || fuzzyContains(lu, label) {
                        found = true
                        cursor = j + 1
                        break
                    }
                    if offset == 0 { break }
                }
                if !found {
                    ok = false
                    break
                }
            }
            if ok { return i }
        }
        return nil
    }

    nonisolated private static func fuzzyContains(_ line: String, _ label: String) -> Bool {
        let compact = label
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
        let lineC = line
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "TOTHL", with: "TOTAL")
            .replacingOccurrences(of: "TOTRL", with: "TOTAL")
            .replacingOccurrences(of: "VANZARI", with: "VANZ")
        return lineC.contains(compact)
    }

    // MARK: - Decimal extraction

    /// Extrage numere monetare dintr-o linie (suportă 1.234,56 / 1234.56 / 688. 00).
    /// OCR pe linia VANZ - A/R: „28/6.60” → 2876.60; altfel ultima sumă >= 100.
    nonisolated private static func amountFromVanzCategoryLine(_ line: String) -> Decimal? {
        let u = line.uppercased()
        if u.contains("/"), let repaired = repairSlashAmount(in: line), repaired >= 100 {
            return repaired
        }
        let vals = decimals(in: line)
        if let last = vals.last, last >= 100 { return last }
        if vals.count >= 2, let first = vals.first, first >= 100 { return first }
        return vals.last
    }

    /// „28/6.60” — slash OCR în loc de cifre din mijloc (ex. 2876.60).
    nonisolated private static func repairSlashAmount(in line: String) -> Decimal? {
        guard let re = try? NSRegularExpression(pattern: #"(\d{2,4})/(\d)(\.\d{2})"#) else { return nil }
        guard let match = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4,
              let r1 = Range(match.range(at: 1), in: line),
              let r2 = Range(match.range(at: 2), in: line),
              let r3 = Range(match.range(at: 3), in: line) else { return nil }
        let prefix = String(line[r1])
        let mid = String(line[r2])
        let suffix = String(line[r3])
        let candidates = [
            prefix + mid + suffix,
            prefix + "7" + mid + suffix,
            prefix + "76" + suffix,
            prefix + "8" + mid + suffix
        ]
        for raw in candidates {
            if let d = Decimal(string: raw), d >= 100 { return d }
        }
        return nil
    }

    nonisolated private static func decimals(in line: String) -> [Decimal] {
        var s = line
            .replacingOccurrences(of: #"(\d)[ ]+\."#, with: "$1.", options: .regularExpression)
            .replacingOccurrences(of: #"\.[ ]+(\d)"#, with: ".$1", options: .regularExpression)

        // 1.718.90 (OCR: separator mii cu punct) → 1718.90
        if let re = try? NSRegularExpression(pattern: #"(\d)\.(\d{3})\.(\d{2})"#) {
            let matches = re.matches(in: s, range: NSRange(s.startIndex..., in: s))
            for match in matches.reversed() {
                guard match.numberOfRanges >= 4,
                      let r = Range(match.range, in: s),
                      let r1 = Range(match.range(at: 1), in: s),
                      let r2 = Range(match.range(at: 2), in: s),
                      let r3 = Range(match.range(at: 3), in: s) else { continue }
                s.replaceSubrange(r, with: "\(s[r1])\(s[r2]).\(s[r3])")
            }
        }

        // 1.234,56 → 1234.56
        if let re = try? NSRegularExpression(pattern: #"\d{1,3}(\.\d{3})+,\d{2}"#) {
            let matches = re.matches(in: s, range: NSRange(s.startIndex..., in: s))
            for match in matches.reversed() {
                guard let r = Range(match.range, in: s) else { continue }
                let norm = s[r].replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                s.replaceSubrange(r, with: norm)
            }
        }

        // 1234,56 → 1234.56 (când virgula e zecimală)
        s = s.replacingOccurrences(of: #"(\d),(\d{2})(?!\d)"#, with: "$1.$2", options: .regularExpression)

        guard let regex = try? NSRegularExpression(pattern: #"(-?\d+\.\d{2})"#) else { return [] }
        let matches = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
        return matches.compactMap { match -> Decimal? in
            guard let r = Range(match.range(at: 1), in: s) else { return nil }
            return Decimal(string: String(s[r]))
        }
    }

    // MARK: - Dates

    private struct PrintDateInfo {
        var printed: Date?
        var businessDate: Date
        var isNightShift: Bool
    }

    /// Dată NC + tură din subsolul bonului (DATA / ORA). Rezolvă și OCR cu ORA pe linie separată sau „0RA”.
    nonisolated private static func resolvePrintDateAndShift(in text: String, lines: [String], isNectarie: Bool) -> PrintDateInfo? {
        let normalized = normalizeFooterForDateParsing(text)
        let footerLines = Array(lines.suffix(20)).map { normalizeFooterForDateParsing($0) }

        if let printed = parseLabeledFooterDateTime(from: footerLines)
            ?? parsePrintDateTime(from: normalized)
            ?? parsePrintDateTimeFromLines(footerLines)
            ?? parsePrintDateTimeLoose(from: footerLines) {
            let night = isNectarie && isNightShiftPrintTime(printed)
            return PrintDateInfo(
                printed: printed,
                businessDate: businessDate(for: printed, isNectarie: isNectarie),
                isNightShift: night
            )
        }

        guard let dateOnly = parseDateOnly(from: normalized) ?? parseDateOnlyFromLines(footerLines) else {
            return nil
        }

        // Fără oră validă pe linia DATA/CATA — folosim doar data (fără scădere de zi din ore OCR greșite).
        return PrintDateInfo(printed: nil, businessDate: Calendar.current.startOfDay(for: dateOnly), isNightShift: false)
    }

    /// Corectează greșeli OCR frecvente în subsol (0RA, OR A, CATA/GRA, 23:4x citit 02:4x).
    nonisolated private static func normalizeFooterForDateParsing(_ text: String) -> String {
        var s = text
        let fixes: [(String, String)] = [
            (#"(?i)\bCATA\b"#, "DATA"),
            (#"(?i)\bGRA\b"#, "ORA"),
            (#"(?i)\b0RR\b"#, "ORA"),
            (#"(?i)\bPATE\b"#, "DATA"),
            (#"(?i)7:\s*(\d{2}[-\./]\d{2}[-\./]\d{4})"#, "DATA: $1"),
            (#"(?i)\b0+\s*RA\b"#, "ORA"),
            (#"(?i)\bOR\s+A\b"#, "ORA"),
            (#"(?i)\bO\s+RA\b"#, "ORA"),
            (#"(?i)\bORI\b"#, "ORA"),
            (#"(?i)\bORJ\b"#, "ORA"),
            (#"(?i)2\s*3\s*[:\.](\d{2})"#, "23:$1"),
            (#"(?i)ORA\s+(\d{1,2}[:\.]\d{2})"#, "ORA: $1"),
            (#"(?i)DATA\s+(\d{2}[-\./]\d{2}[-\./]\d{4})"#, "DATA: $1")
        ]
        for (pattern, replacement) in fixes {
            s = s.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        return s
    }

    nonisolated static func isNightShift(printTime: Date) -> Bool {
        isNightShiftPrintTime(printTime)
    }

    nonisolated static func businessDate(forPrintTime printed: Date, isNectarie: Bool) -> Date {
        businessDate(for: printed, isNectarie: isNectarie)
    }

    nonisolated static func applyShift(to data: inout ZReportData) {
        if let printed = data.printDateTime {
            data.isNightShift = data.isNectarieFirma && isNightShiftPrintTime(printed)
            data.date = businessDate(for: printed, isNectarie: data.isNectarieFirma)
        }
    }

    /// DATA/CATA + ORA/GRA pe aceeași linie din subsol — sursa cea mai fiabilă (evită ore DMJE etc.).
    nonisolated private static func parseLabeledFooterDateTime(from lines: [String]) -> Date? {
        for rawLine in lines.reversed() {
            if let parts = extractFooterDateTimeFromLine(rawLine),
               let date = makeDateTime(
                   day: parts.day, month: parts.month, year: parts.year,
                   hour: parts.hour, minute: parts.minute, second: parts.second
               ), !isIgnoredMemoryDate(date) {
                return date
            }
        }
        return nil
    }

    private struct FooterDateTimeParts {
        var day: String
        var month: String
        var year: String
        var hour: Int
        var minute: Int
        var second: Int
    }

    /// Extrage data + cea mai plauzibilă oră de pe linia DATA/CATA (preferă ora de seară).
    nonisolated private static func extractFooterDateTimeFromLine(_ rawLine: String) -> FooterDateTimeParts? {
        let line = normalizeFooterForDateParsing(rawLine)
        guard let dateRegex = try? NSRegularExpression(
            pattern: #"(?i)(?:DAT[AR]|CATA|DATA)\s*[:\.]\s*(\d{2})[-\./](\d{2})[-\./](\d{4})"#
        ),
              let dateMatch = dateRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              dateMatch.numberOfRanges >= 4,
              let d = Range(dateMatch.range(at: 1), in: line),
              let m = Range(dateMatch.range(at: 2), in: line),
              let y = Range(dateMatch.range(at: 3), in: line) else {
            return extractFooterDateTimeFromLooseLine(rawLine, normalizedLine: line)
        }

        let day = String(line[d])
        let month = String(line[m])
        let year = normalizeReceiptYear(String(line[y]))

        guard let time = bestFooterTime(in: rawLine, normalizedLine: line) else { return nil }
        return FooterDateTimeParts(
            day: day, month: month, year: year,
            hour: time.hour, minute: time.minute, second: time.second
        )
    }

    /// Linie subsol fără etichetă DATA clară: „30-06-2126 0RR: 00:51” (exclude DMJE fără ORA).
    nonisolated private static func extractFooterDateTimeFromLooseLine(_ rawLine: String, normalizedLine: String) -> FooterDateTimeParts? {
        let u = normalizedLine.uppercased()
        if u.contains("DMJE") && !u.contains("ORA") { return nil }

        let pattern = #"(?i)(\d{2})[-\./](\d{2})[-\./](\d{4}).{0,50}(?:ORA|GRA|0RA|0RR)\s*[:\.]?\s*(\d{1,2})[:\.](\d{2})(?:[:\.](\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalizedLine, range: NSRange(normalizedLine.startIndex..., in: normalizedLine)),
              match.numberOfRanges >= 6,
              let d = Range(match.range(at: 1), in: normalizedLine),
              let m = Range(match.range(at: 2), in: normalizedLine),
              let y = Range(match.range(at: 3), in: normalizedLine),
              let hh = Range(match.range(at: 4), in: normalizedLine),
              let mm = Range(match.range(at: 5), in: normalizedLine) else { return nil }

        var hour = Int(normalizedLine[hh]) ?? 0
        let minute = Int(normalizedLine[mm]) ?? 0
        let second: Int
        if match.numberOfRanges > 6, match.range(at: 6).location != NSNotFound,
           let ss = Range(match.range(at: 6), in: normalizedLine) {
            second = Int(normalizedLine[ss]) ?? 0
        } else {
            second = 0
        }
        guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { return nil }
        (hour, _, _) = correctEveningHourMisread(hour: hour, minute: minute, second: second)
        if isSuspiciousFooterTime(hour: hour, minute: minute, second: second) { return nil }

        return FooterDateTimeParts(
            day: String(normalizedLine[d]),
            month: String(normalizedLine[m]),
            year: normalizeReceiptYear(String(normalizedLine[y])),
            hour: hour, minute: minute, second: second
        )
    }

    /// Alege ora de pe linia DATA/CATA: preferă ORA/GRA, apoi cea mai mare oră validă (evită 1:18 din OCR).
    nonisolated private static func bestFooterTime(in rawLine: String, normalizedLine: String) -> (hour: Int, minute: Int, second: Int)? {
        struct Candidate {
            var hour: Int
            var minute: Int
            var second: Int
            var score: Int
        }

        var candidates: [Candidate] = []
        let patterns = [
            #"(?i)(?:ORA|GRA|0RA|0RR)\s*[:\.]?\s*(\d{1,2})[:\.](\d{2})(?:[:\.](\d{2}))?"#,
            #"(?<![\d\-])(\d{1,2})[:\.](\d{2})[:\.](\d{2})(?![\d/])"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: normalizedLine, range: NSRange(normalizedLine.startIndex..., in: normalizedLine)) {
                guard match.numberOfRanges >= 3,
                      let hh = Range(match.range(at: 1), in: normalizedLine),
                      let mm = Range(match.range(at: 2), in: normalizedLine) else { continue }
                var hour = Int(normalizedLine[hh]) ?? 0
                let minute = Int(normalizedLine[mm]) ?? 0
                let second: Int
                if match.numberOfRanges > 3, match.range(at: 3).location != NSNotFound,
                   let ss = Range(match.range(at: 3), in: normalizedLine) {
                    second = Int(normalizedLine[ss]) ?? 0
                } else {
                    second = 0
                }
                guard (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else { continue }

                var score = 0
                if pattern.contains("ORA") { score += 100 }
                if hour >= 18 { score += 80 }
                else if hour >= 12 { score += 40 }
                score += hour
                if minute >= 40 { score += 20 }

                (hour, _, _) = correctEveningHourMisread(hour: hour, minute: minute, second: second)
                if let recovered = recoverTimeFromRawFooterLine(rawLine, parsedHour: hour, parsedMinute: minute, parsedSecond: second) {
                    hour = recovered.hour
                    score += 120
                }
                if isSuspiciousFooterTime(hour: hour, minute: minute, second: second) { score -= 200 }

                candidates.append(Candidate(hour: hour, minute: minute, second: second, score: score))
            }
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else { return nil }
        if isSuspiciousFooterTime(hour: best.hour, minute: best.minute, second: best.second) {
            return nil
        }
        return (best.hour, best.minute, best.second)
    }

    /// OCR: pe linia bonului a rămas fragment `:41:18` / `23:41` dar ora parsată e dimineață.
    nonisolated private static func recoverTimeFromRawFooterLine(
        _ rawLine: String,
        parsedHour: Int,
        parsedMinute: Int,
        parsedSecond: Int
    ) -> (hour: Int, minute: Int, second: Int)? {
        guard parsedHour < 6 else { return nil }
        if let regex = try? NSRegularExpression(pattern: #"(?i)(?:23|20)[:\.]?(4[0-9])[:\.](\d{2})"#),
           let match = regex.firstMatch(in: rawLine, range: NSRange(rawLine.startIndex..., in: rawLine)),
           match.numberOfRanges >= 3,
           let mm = Range(match.range(at: 1), in: rawLine),
           let ss = Range(match.range(at: 2), in: rawLine) {
            return (23, Int(rawLine[mm]) ?? parsedMinute, Int(rawLine[ss]) ?? parsedSecond)
        }
        if rawLine.range(of: #"(?i)41[:\.]18"#, options: .regularExpression) != nil {
            return (23, 41, 18)
        }
        return nil
    }

    /// Ore suspecte OCR (ex. 1:18:00) — nu le folosim; rămâne doar data de pe bon.
    nonisolated private static func isSuspiciousFooterTime(hour: Int, minute: Int, second: Int) -> Bool {
        hour >= 0 && hour < 6 && second == 0 && minute > 0 && minute < 30
    }

    /// OCR: 2026 → 2036 / 2326 / 2126 / 2006 etc.
    nonisolated private static func normalizeReceiptYear(_ yearText: String) -> String {
        guard let year = Int(yearText) else { return yearText }
        if (2020...2028).contains(year) { return yearText }
        if (2000...2019).contains(year) { return "2026" }
        if (2030...2045).contains(year) { return "2026" }
        if (2120...2135).contains(year) { return "2026" }
        if (2320...2335).contains(year) { return "2026" }
        if (2090...2105).contains(year) { return "2026" }
        if (2420...2435).contains(year) { return "2026" }
        return yearText
    }

    /// OCR: „23:41” citit „02:41” — doar orele 02–05 cu minute ≥ 41 (00:51 dimineața rămâne).
    nonisolated private static func correctEveningHourMisread(hour: Int, minute: Int, second: Int) -> (Int, Int, Int) {
        if (2...5).contains(hour), minute >= 41 {
            return (23, minute, second)
        }
        return (hour, minute, second)
    }

    nonisolated private static func parsePrintDateTime(from text: String) -> Date? {
        let patterns = [
            #"(?i)(?:DAT[AR]|CATA)\s*[:\.]\s*(\d{2})[-\./](\d{2})[-\./](\d{4})\s+(?:ORA|GRA|0RA)\s*[:\.]?\s*(\d{1,2})[:\.](\d{2})(?:[:\.](\d{2}))?"#,
            #"(?i)(?:DAT[AR]|CATA)\s*[:\.]\s*(\d{2})[-\./](\d{2})[-\./](\d{4})\s+(\d{1,2})[:\.](\d{2})(?:[:\.](\d{2}))?"#
        ]

        var best: Date?
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches where match.numberOfRanges >= 6 {
                guard let date = dateTimeFromMatch(match, in: text) else { continue }
                if isIgnoredMemoryDate(date) { continue }
                best = date
            }
        }
        return best
    }

    /// DATA pe aceeași linie cu ORA, sau ORA pe max. 2 linii imediat dedesubt.
    nonisolated private static func parsePrintDateTimeFromLines(_ lines: [String]) -> Date? {
        for rawLine in lines.reversed() {
            if let parts = extractFooterDateTimeFromLine(rawLine),
               let date = makeDateTime(
                   day: parts.day, month: parts.month, year: parts.year,
                   hour: parts.hour, minute: parts.minute, second: parts.second
               ), !isIgnoredMemoryDate(date) {
                return date
            }
        }

        let dateLinePattern = #"(?i)(?:DAT[AR]|CATA)\s*[:\.]?\s*(\d{2})[-\./](\d{2})[-\./](\d{4})"#
        let oraLinePattern = #"(?i)(?:ORA|GRA|0RA|0RR)\s*[:\.]?\s*(\d{1,2})[:\.](\d{2})(?:[:\.](\d{2}))?"#

        for index in lines.indices.reversed() {
            let line = normalizeFooterForDateParsing(lines[index])
            guard let dateRegex = try? NSRegularExpression(pattern: dateLinePattern),
                  let dateMatch = dateRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  dateMatch.numberOfRanges >= 4,
                  let d = Range(dateMatch.range(at: 1), in: line),
                  let m = Range(dateMatch.range(at: 2), in: line),
                  let y = Range(dateMatch.range(at: 3), in: line) else { continue }

            // Deja rezolvat pe aceeași linie
            if extractFooterDateTimeFromLine(lines[index]) != nil { continue }

            let tail = lines.dropFirst(index + 1).prefix(2).map { normalizeFooterForDateParsing($0) }
            for oraLine in tail {
                guard let oraRegex = try? NSRegularExpression(pattern: oraLinePattern),
                      let oraMatch = oraRegex.firstMatch(in: oraLine, range: NSRange(oraLine.startIndex..., in: oraLine)),
                      oraMatch.numberOfRanges >= 3,
                      let hh = Range(oraMatch.range(at: 1), in: oraLine),
                      let mm = Range(oraMatch.range(at: 2), in: oraLine) else { continue }

                var hour = Int(oraLine[hh]) ?? 0
                let minute = Int(oraLine[mm]) ?? 0
                let second: Int
                if oraMatch.numberOfRanges > 3, oraMatch.range(at: 3).location != NSNotFound,
                   let ss = Range(oraMatch.range(at: 3), in: oraLine) {
                    second = Int(oraLine[ss]) ?? 0
                } else {
                    second = 0
                }
                (hour, _, _) = correctEveningHourMisread(hour: hour, minute: minute, second: second)
                if isSuspiciousFooterTime(hour: hour, minute: minute, second: second) { continue }

                if let date = makeDateTime(
                    day: String(line[d]), month: String(line[m]), year: String(line[y]),
                    hour: hour, minute: minute, second: second
                ), !isIgnoredMemoryDate(date) {
                    return date
                }
            }
        }
        return nil
    }

    /// Ultimul „dd-mm-yyyy … hh:mm” din liniile subsolului cu DATA/CATA + ORA/GRA obligatoriu.
    nonisolated private static func parsePrintDateTimeLoose(from lines: [String]) -> Date? {
        for rawLine in lines.reversed() {
            if let parts = extractFooterDateTimeFromLine(rawLine),
               let date = makeDateTime(
                   day: parts.day, month: parts.month, year: parts.year,
                   hour: parts.hour, minute: parts.minute, second: parts.second
               ), !isIgnoredMemoryDate(date) {
                return date
            }
        }
        return nil
    }

    nonisolated private static func parseDateOnly(from text: String) -> Date? {
        let pattern = #"(?i)(?:DAT[AR]|CATA)\s*[:\.]\s*(\d{2})[-\./](\d{2})[-\./](\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches.reversed() {
            guard let date = dateFromMatch(match, in: text), !isIgnoredMemoryDate(date) else { continue }
            return date
        }
        return nil
    }

    nonisolated private static func parseDateOnlyFromLines(_ lines: [String]) -> Date? {
        for line in lines.reversed() {
            guard let regex = try? NSRegularExpression(pattern: #"(?i)(?:DAT[AR]|CATA)\s*[:\.]?\s*(\d{2})[-\./](\d{2})[-\./](\d{4})"#, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let date = dateFromMatch(match, in: line),
                  !isIgnoredMemoryDate(date) else { continue }
            return date
        }
        return nil
    }

    nonisolated private static func dateTimeFromMatch(_ match: NSTextCheckingResult, in text: String) -> Date? {
        guard match.numberOfRanges >= 6,
              let d = Range(match.range(at: 1), in: text),
              let m = Range(match.range(at: 2), in: text),
              let y = Range(match.range(at: 3), in: text),
              let hh = Range(match.range(at: 4), in: text),
              let mm = Range(match.range(at: 5), in: text) else { return nil }
        let hour = Int(text[hh]) ?? 0
        let minute = Int(text[mm]) ?? 0
        let second: Int
        if match.numberOfRanges > 6, match.range(at: 6).location != NSNotFound,
           let s = Range(match.range(at: 6), in: text) {
            second = Int(text[s]) ?? 0
        } else {
            second = 0
        }
        return makeDateTime(day: String(text[d]), month: String(text[m]), year: String(text[y]), hour: hour, minute: minute, second: second)
    }

    nonisolated private static func dateFromMatch(_ match: NSTextCheckingResult, in text: String) -> Date? {
        guard match.numberOfRanges >= 4,
              let d = Range(match.range(at: 1), in: text),
              let m = Range(match.range(at: 2), in: text),
              let y = Range(match.range(at: 3), in: text) else { return nil }
        return makeDateTime(day: String(text[d]), month: String(text[m]), year: String(text[y]), hour: 0, minute: 0, second: 0)
    }

    nonisolated private static func makeDateTime(day: String, month: String, year: String, hour: Int, minute: Int, second: Int) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
        let hh = String(format: "%02d", hour)
        let mm = String(format: "%02d", minute)
        let ss = String(format: "%02d", second)
        let normalizedYear = normalizeReceiptYear(year)
        return formatter.date(from: "\(day)-\(month)-\(normalizedYear) \(hh):\(mm):\(ss)")
    }

    nonisolated private static func isIgnoredMemoryDate(_ date: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: date) == 2026 && cal.component(.month, from: date) == 2
    }

    nonisolated private static func isNightShiftPrintTime(_ printed: Date) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: printed)
        let minute = cal.component(.minute, from: printed)
        let minutes = hour * 60 + minute
        // Nectarie: 03:00 … 10:00 → tura de noapte (data NC = ziua anterioară)
        return minutes >= 3 * 60 && minutes < 10 * 60
    }

    /// Firme fără 2 ture (ex. Hotel Impex): 00:00 … 05:59 → data NC = ziua anterioară; de la 06:00 rămâne aceeași zi.
    nonisolated private static func isEarlyMorningPrintTime(_ printed: Date) -> Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: printed)
        let minute = cal.component(.minute, from: printed)
        return hour * 60 + minute < 6 * 60
    }

    nonisolated private static func businessDate(for printed: Date, isNectarie: Bool) -> Date {
        let cal = Calendar.current
        let day = cal.startOfDay(for: printed)
        let usePreviousDay = isNectarie
            ? isNightShiftPrintTime(printed)
            : isEarlyMorningPrintTime(printed)
        if usePreviousDay {
            return cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return day
    }

    nonisolated private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }

    nonisolated private static func round2(_ value: Decimal) -> Decimal {
        var v = value
        var result = Decimal()
        NSDecimalRound(&result, &v, 2, .plain)
        return result
    }

    // MARK: - Raport Z digital (PDF POS — Nectarie etc.)

    /// Export PDF din POS: „Z report Numar …”, „Localia …”, „Metode de Plata”.
    nonisolated static func isDigitalPOSZReport(_ ocrText: String) -> Bool {
        let folded = foldedUpper(ocrText)
        guard folded.contains("Z REPORT") else { return false }
        return folded.contains("LOCATIA")
            || folded.contains("LOCALIA")
            || folded.contains("LOCATIE")
            || folded.contains("LOCATION")
            || folded.contains("METODE DE PLATA")
            || folded.contains("PAYMENT TYPES")
            || folded.contains("BRUT A TVA")
            || folded.contains("BRUT A VAT")
            || folded.contains("TOTAL SOLD")
            || folded.contains("CREDIT CARDS")
    }

    /// Uppercase fără diacritice — „Până la” → PANA LA, „Locația” → LOCATIA.
    nonisolated private static func foldedUpper(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO")).uppercased()
    }

    nonisolated private static func parseDigitalPOSZReport(ocrText: String, preferredLocation: PunctLucru?) -> ZReportData {
        var data = ZReportData()
        data.ocrText = ocrText
        data.parseSource = .digitalPDF
        let lines = normalizeLines(ocrText)
        let folded = foldedUpper(ocrText)

        data.zNumber = parseZNumber(in: folded) ?? 0
        data.locatieLabel = parseDigitalLocatieLabel(lines: lines) ?? ""
        data.punctLucru = preferredLocation
            ?? parseDigitalLocation(from: folded)
            ?? PunctLucru.detect(from: ocrText)
            ?? .agro

        if let profile = FirmaRegistry.resolve(
            cuiFromParser: parseCUI(from: ocrText),
            ocrName: normalizeLines(ocrText).first ?? "",
            ocrText: ocrText
        ) {
            data.firma = profile.displayName
            data.cui = profile.cui
            data.isNectarieFirma = profile.isNectarie
        } else {
            data.firma = normalizeLines(ocrText).first ?? "Firma necunoscuta"
        }

        if let closing = parseDigitalClosingDateTime(from: folded) {
            data.printDateTime = closing
            data.isNightShift = data.isNectarieFirma && isNightShiftPrintTime(closing)
            // Nectarie tura noapte (03:00–10:00): data NC = ziua tipăririi − 1; altfel ziua „Până la”.
            data.date = businessDate(for: closing, isNectarie: data.isNectarieFirma)
        }

        parseDigitalSalesAndVAT(into: &data, lines: lines)
        parseDigitalPayments(into: &data, lines: lines)

        if data.totalVanzari == 0 {
            let sum = data.vanzari21 + data.vanzari11 + data.vanzari11C + data.vanzari0
            if sum > 0 { data.totalVanzari = sum }
        }

        finalizeBacsisPayments(into: &data, lines: lines)

        return data
    }

    nonisolated private static func parseDigitalLocation(from folded: String) -> PunctLucru? {
        if folded.contains("LOCATIA") || folded.contains("LOCALIA") || folded.contains("LOCATION") {
            if folded.contains("PLOIESTI") || folded.contains("PLOIEŞTI") { return .ploiesti }
            if folded.contains("AGRONOMIEI") || folded.contains("AGRONOMIE") { return .agro }
        }
        if folded.contains("CASIER PLOIESTI") { return .ploiesti }
        if folded.contains("CASIER AGRONOMIEI") { return .agro }
        return nil
    }

    /// Text de pe rândul „Locația …” (ex. AGRONOMIEI, PLOIESTI).
    nonisolated private static func parseDigitalLocatieLabel(lines: [String]) -> String? {
        for line in lines {
            let folded = foldedUpper(line)
            guard folded.contains("LOCATIA") || folded.contains("LOCALIA") || folded.contains("LOCATION") else { continue }
            guard let regex = try? NSRegularExpression(pattern: #"(?:LOCATIA|LOCALIA|LOCATION)\s+(.+)$"#),
                  let match = regex.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)),
                  match.numberOfRanges >= 2,
                  let tail = Range(match.range(at: 1), in: folded) else { continue }
            let label = String(folded[tail]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { return label }
        }
        return nil
    }

    nonisolated private static func parseDigitalClosingDateTime(from folded: String) -> Date? {
        let normalized = folded.replacingOccurrences(of: "PANA LA", with: "PANA LA ")

        // Până la 04/07/2026 18:59:03
        if let closing = parseDigitalLabeledDateTime(from: normalized, label: "PANA LA") {
            return closing
        }

        if let closing = parseDigitalLabeledDateTime(from: normalized, label: "TO") {
            return closing
        }

        // Până la 0410712026 18:59:03 (dată OCR lipită + oră pe același rând)
        if let regex = try? NSRegularExpression(
            pattern: #"PANA\s+LA\s+(\d{6,10})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?"#
        ),
           let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
           match.numberOfRanges >= 4,
           let dr = Range(match.range(at: 1), in: normalized),
           let hr = Range(match.range(at: 2), in: normalized),
           let mr = Range(match.range(at: 3), in: normalized),
           let parts = parseGluedDigitalDate(String(normalized[dr])) {
            let sec = closingSeconds(from: match, in: normalized, index: 4)
            return makeDateTime(
                day: parts.day, month: parts.month, year: parts.year,
                hour: Int(normalized[hr]) ?? 0, minute: Int(normalized[mr]) ?? 0, second: sec
            )
        }

        return nil
    }

    /// DD/MM/YYYY din cifre lipite OCR (ex. 0410712026 → 04.07.2026).
    nonisolated private static func parseGluedDigitalDate(_ raw: String) -> (day: String, month: String, year: String)? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 8 else { return nil }

        let day = String(digits.prefix(2))
        let year = normalizeReceiptYear(String(digits.suffix(4)))

        if digits.count == 8 {
            let month = String(digits.dropFirst(2).prefix(2))
            guard let m = Int(month), (1...12).contains(m) else { return nil }
            return (day, month, year)
        }

        for offset in [3, 4, 2] {
            let start = digits.index(digits.startIndex, offsetBy: offset)
            guard digits.index(start, offsetBy: 2, limitedBy: digits.endIndex) != nil else { continue }
            let end = digits.index(start, offsetBy: 2)
            let month = String(digits[start..<end])
            if let m = Int(month), (1...12).contains(m) {
                return (day, month, year)
            }
        }

        if let monthYear = parseDigitalMonthYear(String(digits.dropFirst(2))) {
            return (day, monthYear.month, monthYear.year)
        }
        return nil
    }

    nonisolated private static func closingSeconds(from match: NSTextCheckingResult, in text: String, index: Int) -> Int {
        guard match.numberOfRanges > index,
              let sr = Range(match.range(at: index), in: text),
              let s = Int(text[sr]) else { return 0 }
        return s
    }

    nonisolated private static func parseDigitalSlashDate(after label: String, in text: String) -> (day: String, month: String, year: String)? {
        if let regex = try? NSRegularExpression(
            pattern: "\(label)\\s+(\\d{2})[/\\.-](\\d{2})[/\\.-](\\d{4})",
            options: [.caseInsensitive]
        ),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 4,
           let d = Range(match.range(at: 1), in: text),
           let m = Range(match.range(at: 2), in: text),
           let y = Range(match.range(at: 3), in: text) {
            return (String(text[d]), String(text[m]), normalizeReceiptYear(String(text[y])))
        }

        if let regex = try? NSRegularExpression(
            pattern: "\(label)\\s+(\\d{2})[/\\.-](\\d{6,8})",
            options: [.caseInsensitive]
        ),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           match.numberOfRanges >= 3,
           let d = Range(match.range(at: 1), in: text),
           let rest = Range(match.range(at: 2), in: text),
           let monthYear = parseDigitalMonthYear(String(text[rest])) {
            return (String(text[d]), monthYear.month, monthYear.year)
        }

        return nil
    }

    nonisolated private static func parseDigitalMonthYear(_ raw: String) -> (month: String, year: String)? {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 6 else { return nil }

        let year = normalizeReceiptYear(String(digits.suffix(4)))
        var monthPart = String(digits.dropLast(4))
        if monthPart.count > 2 {
            monthPart = String(monthPart.prefix(2))
        }
        guard monthPart.count == 2, let month = Int(monthPart), (1...12).contains(month) else { return nil }
        return (String(format: "%02d", month), year)
    }

    nonisolated private static func parseDigitalLabeledDateTime(from text: String, label: String) -> Date? {
        guard let parts = parseDigitalSlashDate(after: label, in: text) else { return nil }
        guard let regex = try? NSRegularExpression(
            pattern: "\(label)\\s+\\d{2}[/\\.-]\\d{2}\\D*\\d{4}\\s+(\\d{1,2}):(\\d{2})(?::(\\d{2}))?",
            options: [.caseInsensitive]
        ),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let h = Range(match.range(at: 1), in: text),
              let min = Range(match.range(at: 2), in: text) else { return nil }
        let sec = closingSeconds(from: match, in: text, index: 3)
        return makeDateTime(
            day: parts.day, month: parts.month, year: parts.year,
            hour: Int(text[h]) ?? 0, minute: Int(text[min]) ?? 0, second: sec
        )
    }

    nonisolated private static func parseDigitalSalesAndVAT(into data: inout ZReportData, lines: [String]) {
        for (index, line) in lines.enumerated() {
            let u = foldedDigitalLine(line)
            let next = index + 1 < lines.count ? lines[index + 1] : nil

            if let cat = digitalBrutCategory(u) {
                guard let v = digitalAmount(on: line, next: next, allowZero: cat == "D") else { continue }
                switch cat {
                case "A": data.vanzari21 = v
                case "B": data.vanzari11 = v
                case "C": data.vanzari11C = v
                case "D": data.vanzari0 = v
                default: break
                }
            } else if let cat = digitalTVACategory(u) {
                guard let v = digitalAmount(on: line, next: next, allowZero: cat == "D") else { continue }
                switch cat {
                case "A": data.tva21 = v
                case "B": data.tva11 = v
                case "C": data.tva11C = v
                default: break
                }
            } else if u.contains("TOTAL VANZARI")
                        || u.contains("TOTAL SOLD")
                        || (u.contains("TOTAL") && u.contains("VANZARI") && !u.contains("TOTAL TVA")) {
                if let v = digitalAmount(on: line, next: next) { data.totalVanzari = v }
            }
        }

        if data.totalVanzari == 0 {
            data.totalVanzari = readLabeledAmount(["TOTAL VANZARI", "Total vanzari"], in: lines) ?? 0
        }
        if data.tva21 == 0, data.vanzari21 > 0 {
            data.tva21 = expectedVAT(sales: data.vanzari21, rate: 0.21)
        }
        if data.tva11 == 0, data.vanzari11 > 0 {
            data.tva11 = expectedVAT(sales: data.vanzari11, rate: 0.11)
        }
        if data.tva11C == 0, data.vanzari11C > 0 {
            data.tva11C = expectedVAT(sales: data.vanzari11C, rate: 0.11)
        }
        inferMissingCategoryC(into: &data, lines: lines)
    }

    /// BRUT A/B/C/D din PDF POS — ordine: C înainte de B (ambele conțin „11”).
    nonisolated private static func digitalBrutCategory(_ folded: String) -> String? {
        guard folded.contains("BRUT") else { return nil }
        if folded.contains("BRUT A") || folded.contains("BRUTA ") || folded.hasPrefix("BRUTA") { return "A" }
        if folded.contains("BRUT C") || folded.contains("BRUTC ") || folded.hasPrefix("BRUTC") { return "C" }
        if folded.contains("BRUT B") || folded.contains("BRUTB ") || folded.hasPrefix("BRUTB") { return "B" }
        if folded.contains("BRUT D") || folded.contains("BRUTD") || folded.contains("BRUTDTVA") { return "D" }
        return nil
    }

    /// TVA A/B/C/D (fără linii BRUT / Total TVA).
    nonisolated private static func digitalTVACategory(_ folded: String) -> String? {
        guard !folded.contains("BRUT"), folded.contains("TVA") || folded.contains(" VAT") else { return nil }
        if folded.contains("TOTAL TVA") || folded.contains("TOTAL VANZ") { return nil }
        if folded.contains("TVA A") || folded.contains("TVAA") { return "A" }
        if folded.contains("TVA C") || folded.contains("TVAC") { return "C" }
        if folded.contains("TVA B") || folded.contains("TVAB") { return "B" }
        if folded.contains("TVA D") || folded.contains("TVAD") { return "D" }
        return nil
    }

    nonisolated private static func foldedDigitalLine(_ line: String) -> String {
        foldedUpper(line)
            .replacingOccurrences(of: "°", with: "%")
            .replacingOccurrences(of: "BRUTDTVAO", with: "BRUT D TVA 0")
    }

    nonisolated private static func digitalLineMatches(_ folded: String, patterns: [String]) -> Bool {
        patterns.contains { pattern in
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return folded.contains(pattern)
            }
            return re.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)) != nil
        }
    }

    /// Sumă pe același rând cu eticheta; dacă lipsește, pe rândul următor (PDF POS).
    nonisolated private static func digitalAmount(on line: String, next nextLine: String?, allowZero: Bool = false) -> Decimal? {
        let same = decimals(in: line)
        if let v = same.last, allowZero ? v >= 0 : v > 0 { return v }

        guard let nextLine else { return nil }
        let nu = foldedDigitalLine(nextLine)
        if nu.contains("BRUT") || nu.contains("TVA") || nu.contains(" VAT") || nu.contains("TOTAL")
            || nu.contains("NUMERAR") || nu.contains("CASH") || nu.contains("METODE") || nu.contains("CREDIT") {
            return nil
        }
        let nextVals = decimals(in: nextLine)
        if nextVals.count == 1 {
            let v = nextVals[0]
            return (allowZero ? v >= 0 : v > 0) ? v : nil
        }
        if let v = nextVals.last, allowZero ? v >= 0 : v > 0 { return v }
        return nil
    }

    nonisolated private static func parseDigitalPayments(into data: inout ZReportData, lines: [String]) {
        var inPayments = false
        for (index, line) in lines.enumerated() {
            let u = foldedUpper(line)
            let next = index + 1 < lines.count ? lines[index + 1] : nil

            if u.contains("METODE DE PLATA") || u.contains("METODE DE PLAT") || u.contains("PAYMENT TYPES") {
                inPayments = true
                continue
            }
            guard inPayments else { continue }

            if u.contains("BRUT") || u == "TVA" || (u.hasPrefix("TVA ") && !u.contains("PLATA")) {
                break
            }
            if u.contains("TOTAL VANZARI") { break }
            // Total din secțiunea „Metode de plată” — nu mai citi plăți după el.
            if (u.hasPrefix("TOTAL ") || u == "TOTAL") && !u.contains("TVA") && !u.contains("VANZARI") {
                break
            }

            if u.contains("NUMERAR") || u == "CASH" || u.hasPrefix("CASH "), let v = digitalAmount(on: line, next: next) {
                data.numerar = v
            } else if isDigitalCreditCardLine(u), let v = digitalAmount(on: line, next: next) {
                data.card = v
            } else if u.contains("PLATA MODERNA") || u.contains("PLATA MODERN") {
                // Etichetă fără sumă = 0 (nu folosi Totalul bonului).
                data.plataModerna = digitalAmount(on: line, next: next, allowZero: true) ?? 0
            }
        }
    }

    /// Încasare card POS digital: doar „Credit cards”, nu „Card masă” / alte carduri.
    nonisolated private static func isDigitalCreditCardLine(_ upperLine: String) -> Bool {
        guard upperLine.contains("CREDIT") && upperLine.contains("CARD") else { return false }
        return !isDigitalCardMasaLine(upperLine)
    }

    nonisolated private static func isDigitalCardMasaLine(_ upperLine: String) -> Bool {
        let folded = upperLine
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "ro_RO"))
        guard folded.contains("CARD") else { return false }
        return folded.contains("MASA") || folded.contains("DE MASA") || folded.contains("TICHET")
    }
}
