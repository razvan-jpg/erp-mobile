import Foundation

/// Citire Z-uri scanate: o pagină = un Z; un fișier = o firmă.
enum ZettaScanPageReader {
    /// Text digital POS din PDF (BINA), nu strat OCR de scanner.
    nonisolated static func isTrustedDigitalEmbedded(_ text: String, parsed: ZReportData) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 250 else { return false }
        guard ZParser.isDigitalPOSZReport(trimmed) else { return false }
        return parsed.zNumber > 0 && parsed.totalVanzari > 0 && parsed.isBalanced
    }

    /// Întreaga pagină, fără tăiere în mai multe Z-uri.
    nonisolated static func parsePage(text: String, fileName: String) -> ZReportData {
        let normalized = BinaPosZReportTextNormalizer.prepareOCRTextForZParser(text)
        var parsed = ZParser.parse(ocrText: normalized)
        parsed.ocrText = normalized
        parsed.sourceFileName = fileName
        if ZParser.isDigitalPOSZReport(normalized) {
            parsed.parseSource = .digitalPDF
        }
        return withoutFalseAmounts(parsed)
    }

    /// Fără număr Z nu păstrăm sumele — sunt resturi din stratul scannerului, nu un Z citit.
    nonisolated static func withoutFalseAmounts(_ report: ZReportData) -> ZReportData {
        guard isWeak(report) else { return report }
        var copy = report
        copy.numerar = 0
        copy.card = 0
        copy.plataModerna = 0
        copy.altePlati = 0
        copy.totalVanzari = 0
        copy.vanzari21 = 0
        copy.vanzari11 = 0
        copy.vanzari11C = 0
        copy.vanzari0 = 0
        copy.tva21 = 0
        copy.tva11 = 0
        copy.tva11C = 0
        return copy
    }

    nonisolated static func pickBetter(_ lhs: ZReportData, _ rhs: ZReportData) -> ZReportData {
        score(lhs) >= score(rhs) ? lhs : rhs
    }

    nonisolated static func isWeak(_ report: ZReportData) -> Bool {
        report.zNumber == 0
    }

    nonisolated static func stubPage(fileName: String) -> ZReportData {
        var data = ZReportData()
        data.sourceFileName = fileName
        return data
    }

    /// Toate Z-urile din același fișier/încărcare sunt aceeași firmă.
    nonisolated static func unifyFirm(_ reports: [ZReportData]) -> [ZReportData] {
        guard let identity = firmIdentity(from: reports) else { return reports }
        return reports.map { report in
            var copy = report
            copy.firma = identity.firma
            copy.cui = identity.cui
            copy.isNectarieFirma = identity.isNectarie
            return copy
        }
    }

    nonisolated private static func score(_ report: ZReportData) -> Int {
        var value = ZParser.ocrCandidateScore(report, ocrText: report.ocrText).overall
        if report.zNumber > 0 { value += 80 }
        if report.totalVanzari > 0 { value += 30 }
        if report.numerar > 0 || report.card > 0 { value += 15 }
        if report.isBalanced { value += 20 }
        if FirmaRegistry.profile(for: report) != nil { value += 10 }
        return value
    }

    nonisolated private static func firmIdentity(
        from reports: [ZReportData]
    ) -> (firma: String, cui: String, isNectarie: Bool)? {
        let ranked = reports.sorted { lhs, rhs in
            let leftKnown = FirmaRegistry.profile(for: lhs) != nil
            let rightKnown = FirmaRegistry.profile(for: rhs) != nil
            if leftKnown != rightKnown { return leftKnown && !rightKnown }
            if lhs.cui.isEmpty != rhs.cui.isEmpty { return !lhs.cui.isEmpty && rhs.cui.isEmpty }
            if (lhs.zNumber > 0) != (rhs.zNumber > 0) { return lhs.zNumber > 0 }
            return score(lhs) > score(rhs)
        }
        guard let best = ranked.first else { return nil }
        if let profile = FirmaRegistry.profile(for: best) {
            return (profile.displayName, profile.cui, profile.isNectarie)
        }
        let firma = best.firma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firma.isEmpty || !best.cui.isEmpty else { return nil }
        return (firma, best.cui, best.isNectarieFirma)
    }
}
