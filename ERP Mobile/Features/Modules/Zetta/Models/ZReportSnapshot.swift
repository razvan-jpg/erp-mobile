import Foundation

/// Snapshot JSONB pentru `company_z_reports.payload`.
nonisolated struct ZReportSnapshot: Codable, Sendable {
    var id: UUID
    var punctLucru: PunctLucru
    var locatieLabel: String
    var zNumber: Int
    var firma: String
    var cui: String
    var isNectarieFirma: Bool
    var date: Date
    var printDateTime: Date?
    var isNightShift: Bool
    var vanzari21: Decimal
    var tva21: Decimal
    var vanzari11: Decimal
    var tva11: Decimal
    var vanzari11C: Decimal
    var tva11C: Decimal
    var vanzari0: Decimal
    var numerar: Decimal
    var card: Decimal
    var plataModerna: Decimal
    var altePlati: Decimal
    var totalVanzari: Decimal
    var ocrText: String
    var sourceFileName: String
    var parseSource: ZReportData.ParseSource

    enum CodingKeys: String, CodingKey {
        case id, punctLucru, locatieLabel, zNumber, firma, cui, isNectarieFirma
        case date, printDateTime, isNightShift
        case vanzari21, tva21, vanzari11, tva11, vanzari11C, tva11C, vanzari0
        case numerar, card, plataModerna, altePlati, totalVanzari
        case ocrText, sourceFileName, parseSource
    }

    nonisolated init(from report: ZReportData) {
        id = report.id
        punctLucru = report.punctLucru
        locatieLabel = report.locatieLabel
        zNumber = report.zNumber
        firma = report.firma
        cui = report.cui
        isNectarieFirma = report.isNectarieFirma
        date = report.date
        printDateTime = report.printDateTime
        isNightShift = report.isNightShift
        vanzari21 = report.vanzari21
        tva21 = report.tva21
        vanzari11 = report.vanzari11
        tva11 = report.tva11
        vanzari11C = report.vanzari11C
        tva11C = report.tva11C
        vanzari0 = report.vanzari0
        numerar = report.numerar
        card = report.card
        plataModerna = report.plataModerna
        altePlati = report.altePlati
        totalVanzari = report.totalVanzari
        ocrText = report.ocrText
        sourceFileName = report.sourceFileName
        parseSource = report.parseSource
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        punctLucru = try c.decode(PunctLucru.self, forKey: .punctLucru)
        locatieLabel = try c.decode(String.self, forKey: .locatieLabel)
        zNumber = try c.decode(Int.self, forKey: .zNumber)
        firma = try c.decode(String.self, forKey: .firma)
        cui = try c.decode(String.self, forKey: .cui)
        isNectarieFirma = try c.decode(Bool.self, forKey: .isNectarieFirma)
        date = try c.decode(Date.self, forKey: .date)
        printDateTime = try c.decodeIfPresent(Date.self, forKey: .printDateTime)
        isNightShift = try c.decode(Bool.self, forKey: .isNightShift)
        vanzari21 = try c.decode(SupabaseDecimal.self, forKey: .vanzari21).wrappedValue
        tva21 = try c.decode(SupabaseDecimal.self, forKey: .tva21).wrappedValue
        vanzari11 = try c.decode(SupabaseDecimal.self, forKey: .vanzari11).wrappedValue
        tva11 = try c.decode(SupabaseDecimal.self, forKey: .tva11).wrappedValue
        vanzari11C = try c.decode(SupabaseDecimal.self, forKey: .vanzari11C).wrappedValue
        tva11C = try c.decode(SupabaseDecimal.self, forKey: .tva11C).wrappedValue
        vanzari0 = try c.decode(SupabaseDecimal.self, forKey: .vanzari0).wrappedValue
        numerar = try c.decode(SupabaseDecimal.self, forKey: .numerar).wrappedValue
        card = try c.decode(SupabaseDecimal.self, forKey: .card).wrappedValue
        plataModerna = try c.decode(SupabaseDecimal.self, forKey: .plataModerna).wrappedValue
        altePlati = try c.decode(SupabaseDecimal.self, forKey: .altePlati).wrappedValue
        totalVanzari = try c.decode(SupabaseDecimal.self, forKey: .totalVanzari).wrappedValue
        ocrText = try c.decode(String.self, forKey: .ocrText)
        sourceFileName = try c.decode(String.self, forKey: .sourceFileName)
        parseSource = try c.decode(ZReportData.ParseSource.self, forKey: .parseSource)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(punctLucru, forKey: .punctLucru)
        try c.encode(locatieLabel, forKey: .locatieLabel)
        try c.encode(zNumber, forKey: .zNumber)
        try c.encode(firma, forKey: .firma)
        try c.encode(cui, forKey: .cui)
        try c.encode(isNectarieFirma, forKey: .isNectarieFirma)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(printDateTime, forKey: .printDateTime)
        try c.encode(isNightShift, forKey: .isNightShift)
        try c.encode(SupabaseDecimal(wrappedValue: vanzari21), forKey: .vanzari21)
        try c.encode(SupabaseDecimal(wrappedValue: tva21), forKey: .tva21)
        try c.encode(SupabaseDecimal(wrappedValue: vanzari11), forKey: .vanzari11)
        try c.encode(SupabaseDecimal(wrappedValue: tva11), forKey: .tva11)
        try c.encode(SupabaseDecimal(wrappedValue: vanzari11C), forKey: .vanzari11C)
        try c.encode(SupabaseDecimal(wrappedValue: tva11C), forKey: .tva11C)
        try c.encode(SupabaseDecimal(wrappedValue: vanzari0), forKey: .vanzari0)
        try c.encode(SupabaseDecimal(wrappedValue: numerar), forKey: .numerar)
        try c.encode(SupabaseDecimal(wrappedValue: card), forKey: .card)
        try c.encode(SupabaseDecimal(wrappedValue: plataModerna), forKey: .plataModerna)
        try c.encode(SupabaseDecimal(wrappedValue: altePlati), forKey: .altePlati)
        try c.encode(SupabaseDecimal(wrappedValue: totalVanzari), forKey: .totalVanzari)
        try c.encode(ocrText, forKey: .ocrText)
        try c.encode(sourceFileName, forKey: .sourceFileName)
        try c.encode(parseSource, forKey: .parseSource)
    }

    nonisolated func toReport() -> ZReportData {
        var report = ZReportData()
        report.id = id
        report.punctLucru = punctLucru
        report.locatieLabel = locatieLabel
        report.zNumber = zNumber
        report.firma = firma
        report.cui = cui
        report.isNectarieFirma = isNectarieFirma
        report.date = date
        report.printDateTime = printDateTime
        report.isNightShift = isNightShift
        report.vanzari21 = vanzari21
        report.tva21 = tva21
        report.vanzari11 = vanzari11
        report.tva11 = tva11
        report.vanzari11C = vanzari11C
        report.tva11C = tva11C
        report.vanzari0 = vanzari0
        report.numerar = numerar
        report.card = card
        report.plataModerna = plataModerna
        report.altePlati = altePlati
        report.totalVanzari = totalVanzari
        report.ocrText = ocrText
        report.sourceFileName = sourceFileName
        report.parseSource = parseSource
        return report
    }
}
