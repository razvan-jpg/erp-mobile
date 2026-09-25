import Foundation
import Testing
@testable import ERPMobile

struct ZettaScanPageReaderTests {
    @Test func onePageStaysOneReportEvenIfTwoZNumbersAppear() {
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
        Total vânzări \t1.168,10
        Z report Număr 294
        """
        let parsed = ZettaScanPageReader.parsePage(text: sample, fileName: "scan · p1.pdf")
        #expect(parsed.sourceFileName == "scan · p1.pdf")
        #expect(parsed.zNumber == 293 || parsed.zNumber == 294)
    }

    @Test func unifyFirmKeepsOneCompanyForTheWholeBatch() {
        let magnolia = """
        COMPLEX MAGNOLIA
        Z report Număr 293
        Locaţia \tPLOIESTI
        Până la \t21/07/2026 18:53:11
        Metode de Plată
        Numerar \t618,10 RON
        Total \t618,10 RON
        """
        let first = ZettaScanPageReader.parsePage(text: magnolia, fileName: "p1")
        var second = ZReportData()
        second.zNumber = 294
        second.totalVanzari = 100
        second.sourceFileName = "p2"
        let unified = ZettaScanPageReader.unifyFirm([first, second])
        #expect(unified.count == 2)
        #expect(Set(unified.map(\.cui)).count == 1)
        #expect(unified.allSatisfy { !$0.firma.isEmpty })
        #expect(unified.allSatisfy {
            $0.firma.uppercased().contains("NECTARIE") || $0.firma.uppercased().contains("MAGNOLIA")
        })
        #expect(!unified.contains { $0.firma.uppercased().contains("BUNATATI") })
    }

    @Test func scannerJunkIsNotTrustedDigitalEmbedded() {
        let junk = "pagina scanata 1\n123 45\nz 10"
        let parsed = ZettaScanPageReader.parsePage(text: junk, fileName: "p1")
        #expect(!ZettaScanPageReader.isTrustedDigitalEmbedded(junk, parsed: parsed))
    }

    @Test func amountsWithoutZNumberAreDiscarded() {
        let junk = """
        618,10
        121,00
        1.168,10 RON
        69,43
        """
        let parsed = ZettaScanPageReader.parsePage(text: junk, fileName: "p1")
        #expect(parsed.zNumber == 0)
        #expect(parsed.totalVanzari == 0)
        #expect(parsed.numerar == 0)
        #expect(parsed.card == 0)
    }

    @Test func twoColumnLabelValueLineKeepsZNumber() {
        let sample = """
        COMPLEX MAGNOLIA
        Z report Număr \t293
        Locaţia \tPLOIESTI
        Până la \t21/07/2026 18:53:11
        Metode de Plată
        Numerar \t618,10 RON
        Credit cards \t121,00 RON
        Plata moderna \t429,00 RON
        Total \t1.168,10 RON
        Total vânzări \t1.168,10
        """
        let parsed = ZettaScanPageReader.parsePage(text: sample, fileName: "p1")
        #expect(parsed.zNumber == 293)
        #expect(parsed.totalVanzari == Decimal(string: "1168.10") || parsed.numerar > 0)
    }
}
