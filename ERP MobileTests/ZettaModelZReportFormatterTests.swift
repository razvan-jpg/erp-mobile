import Foundation
import Testing
@testable import ERPMobile

struct ZettaModelZReportFormatterTests {
    @Test func digitalModelTextKeepsZNumberAndPayments() {
        let sample = """
        COMPLEX MAGNOLIA
        Z report Număr 293
        Locaţia \tPLOIESTI
        Până la \t21/07/2026 18:53:11
        Metode de Plată
        Numerar \t618,10 RON
        Credit cards \t121,00 RON
        Plata moderna \t429,00 RON
        Total \t1.168,10 RON
        TVA
        BRUT A TVA 21% \t69,43
        Total vânzări \t1.168,10
        """
        var report = ZParser.parse(ocrText: sample)
        report.ocrText = sample
        let text = ZettaModelZReportFormatter.modelText(for: report)
        #expect(text.contains("Z report Număr"))
        #expect(text.contains("293"))
        #expect(text.uppercased().contains("NUMERAR"))
        #expect(text.contains("PLOIESTI") || text.contains("Ploiești") || text.contains("Ploiesti"))
    }

    @Test func parsedFieldsFallbackIncludesBankDepositStyleTotals() {
        var report = ZReportData()
        report.firma = "TEST SRL"
        report.zNumber = 10
        report.locatieLabel = "PLOIESTI"
        report.numerar = 100
        report.card = 50
        report.plataModerna = 25
        report.totalVanzari = 175
        report.vanzari21 = 121
        report.tva21 = 21
        report.ocrText = ""
        let text = ZettaModelZReportFormatter.modelText(for: report)
        #expect(text.contains("Z report Număr 10"))
        #expect(text.contains("TEST SRL"))
        #expect(text.contains("Metode de Plată"))
        #expect(text.contains("Total vânzări"))
    }

    @Test func exportUsesFirmFromScannedZNotAnotherCompany() {
        let sample = """
        COMPLEX MAGNOLIA
        Z report Număr 293
        Locaţia \tPLOIESTI
        Până la \t21/07/2026 18:53:11
        Metode de Plată
        Numerar \t618,10 RON
        Total \t618,10 RON
        """
        let parsed = ZParser.parse(ocrText: sample)
        let display = FirmaRegistry.displayName(for: parsed)
        let fileName = ZettaScanReportBinder.exportBaseName(for: [parsed])
        #expect(display.uppercased().contains("NECTARIE") || display.uppercased().contains("MAGNOLIA"))
        #expect(!display.uppercased().contains("BUNATATI"))
        #expect(fileName.uppercased().contains("NECTARIE") || fileName.uppercased().contains("MAGNOLIA"))
        #expect(!fileName.uppercased().contains("BUNATATI"))
        let pdf = ZettaModelZReportFormatter.rebuiltModelText(for: parsed, companyName: nil, addressLine: nil)
        #expect(pdf.uppercased().contains("NECTARIE") || pdf.uppercased().contains("MAGNOLIA"))
        #expect(!pdf.uppercased().contains("BUNATATI"))
        #expect(pdf.contains("Z report Număr"))
        let datePart = CashRegisterJournalFormatting.fileDate(parsed.date)
        #expect(fileName.contains(datePart) || fileName.contains("2026-07-21"))
    }
}
