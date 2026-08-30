import Foundation

/// Snapshot JSONB pentru `company_z_reports.payload`.
struct ZReportSnapshot: Codable, Sendable {
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
    @SupabaseDecimal var vanzari21: Decimal
    @SupabaseDecimal var tva21: Decimal
    @SupabaseDecimal var vanzari11: Decimal
    @SupabaseDecimal var tva11: Decimal
    @SupabaseDecimal var vanzari11C: Decimal
    @SupabaseDecimal var tva11C: Decimal
    @SupabaseDecimal var vanzari0: Decimal
    @SupabaseDecimal var numerar: Decimal
    @SupabaseDecimal var card: Decimal
    @SupabaseDecimal var plataModerna: Decimal
    @SupabaseDecimal var altePlati: Decimal
    @SupabaseDecimal var totalVanzari: Decimal
    var ocrText: String
    var sourceFileName: String
    var parseSource: ZReportData.ParseSource

    init(from report: ZReportData) {
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

    func toReport() -> ZReportData {
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
