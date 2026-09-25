import Foundation
import Testing
@testable import ERPMobile

struct HRJournalNotePDFParserTests {
    @Test func parsesHRListingRows() {
        let lines = [
            "BUNATATI LA MARIA S.R.L.",
            "CUI: 12345678",
            "Notă contabilă",
            "09 / 2026",
            "Nr. Jurnal Cont D/C Marca Explicație Valoare",
            "1 OD 641 D 1001 Salarii datorate — Ion Pop 5.000,00 lei",
            "1 OD 421 C 1001 Salarii datorate — Ion Pop 5.000,00 lei",
            "1 OD 421 D 1001 CAS reținut — Ion Pop 100,00 lei",
            "1 OD 431 C 1001 CAS reținut — Ion Pop 100,00 lei"
        ]
        let parsed = HRJournalNotePDFParser.parse(lines: lines, defaultNoteNumber: 21)
        #expect(parsed.entries.count == 4)
        #expect(parsed.entries[0].account == "641")
        #expect(parsed.entries[0].debitCredit == "D")
        #expect(parsed.entries[0].employeeCode == "1001")
        #expect(parsed.entries[0].amount == 5000)
        #expect(parsed.entries[1].account == "421")
        #expect(parsed.entries[1].debitCredit == "C")
        #expect(parsed.companyName?.contains("BUNATATI") == true)
        #expect(parsed.dateYYYYMMDD == 20260901)
    }

    @Test func parsesGenericDebitCreditTokens() {
        let lines = [
            "Nota contabila nr. 21 din 15.06.2015",
            "Jurnal: OD",
            "641 D 5764,00",
            "421 C 5764,00"
        ]
        let parsed = HRJournalNotePDFParser.parse(lines: lines)
        #expect(parsed.entries.count == 2)
        #expect(parsed.entries[0].account == "641")
        #expect(parsed.entries[1].account == "421")
        #expect(parsed.dateYYYYMMDD == 20150615)
        #expect(parsed.journal == "OD")
    }

    @Test func parsesSagaDebitCreditColumnsAndCompoundPercent() {
        let lines = """
        GENIC TEAM INTERNATIONAL SRL   c.f. RO30165469   r.c. J40/5256/2012  Capital social 200
        BUCURESTI sect. 2 str. B-dul CHISINAU nr. 15
        Nota contabila
        31.08.2026
        Nr. crt. Explicatie Cont debitor Cont creditor Suma Nr. doc Tip
        1 Cheltuieli cu salariile 641 421 66 660.00 91 Salarii
        2 Retineri - salariati 421 % 26 225.00 91 Salarii
        3 Impozit - salarii 444 3 095.00 91 Salarii
        4 CAS individuala - salariati 4315 16 521.00 91 Salarii
        5 CASS individuala - salariati 4316 6 609.00 91 Salarii
        6 CAM 6461 436 1 486.00 91 Salarii
        Total: 94 371.00
        Pagina 1/1 SagaWEB
        """.components(separatedBy: .newlines)
        let parsed = HRJournalNotePDFParser.parse(lines: lines, defaultNoteNumber: 1)
        #expect(parsed.companyName == "GENIC TEAM INTERNATIONAL SRL")
        #expect(parsed.dateYYYYMMDD == 20260831)
        #expect(parsed.entries.count == 10)
        #expect(parsed.entries.map(\.account) == ["641", "421", "421", "444", "421", "4315", "421", "4316", "6461", "436"])
        #expect(parsed.entries.map(\.debitCredit) == ["D", "C", "D", "C", "D", "C", "D", "C", "D", "C"])
        #expect(parsed.entries.map(\.amount) == [66660, 66660, 3095, 3095, 16521, 16521, 6609, 6609, 1486, 1486])
        #expect(parsed.entries.allSatisfy { $0.documentNumber == "91" })
        let debit = parsed.entries.filter { $0.debitCredit == "D" }.reduce(0) { $0 + $1.amount }
        let credit = parsed.entries.filter { $0.debitCredit == "C" }.reduce(0) { $0 + $1.amount }
        #expect(debit == credit)
        #expect(debit == 94371)
    }

    @Test func parsesRealSagaPDFWhenAvailable() throws {
        let url = URL(
            fileURLWithPath: "/Users/razvanivan/Razvan Dropbox/Razvan Team Folder/listari/GENIC TEAM INTERNATIONAL SRL - 30165469/hr genic team international srl/State salarii/2026/08/nota_contabila_08.09.2026_01.22.30.pdf"
        )
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let parsed = try HRJournalNotePDFParser.parse(pdfData: try Data(contentsOf: url))
        #expect(parsed.entries.count == 10)
        #expect(parsed.dateYYYYMMDD == 20260831)
        #expect(parsed.entries.contains { $0.account == "641" && $0.debitCredit == "D" && $0.amount == 66660 })
        #expect(parsed.entries.contains { $0.account == "421" && $0.debitCredit == "D" && $0.amount == 16521 })
        #expect(parsed.entries.contains { $0.account == "4315" && $0.debitCredit == "C" && $0.amount == 16521 })
        #expect(!parsed.entries.contains { $0.account == "421" && $0.debitCredit == "D" && $0.amount == 26225 })
    }

    @Test func remapsNoteNumbersKeepingPairs() {
        let entries = [
            HRJournalEntry(number: 1, journal: "OD", dateYYYYMMDD: 20260901, documentNumber: "1", account: "641", accountTitle: "", explanation: "S", amount: 10, debitCredit: "D", employeeCode: "1"),
            HRJournalEntry(number: 1, journal: "OD", dateYYYYMMDD: 20260901, documentNumber: "1", account: "421", accountTitle: "", explanation: "S", amount: 10, debitCredit: "C", employeeCode: "1"),
            HRJournalEntry(number: 2, journal: "OD", dateYYYYMMDD: 20260901, documentNumber: "2", account: "641", accountTitle: "", explanation: "S", amount: 20, debitCredit: "D", employeeCode: "2"),
            HRJournalEntry(number: 2, journal: "OD", dateYYYYMMDD: 20260901, documentNumber: "2", account: "421", accountTitle: "", explanation: "S", amount: 20, debitCredit: "C", employeeCode: "2")
        ]
        let remapped = HRJournalNotePDFParser.remapped(entries, startingAt: 1543)
        #expect(remapped.map(\.number) == [1543, 1543, 1544, 1544])
        #expect(remapped[0].documentNumber == "1543")
    }

    @Test func collectedUniqueAccountAddsDebitAnd4311AfterWithholdings() {
        let lines = """
        GENIC TEAM INTERNATIONAL SRL   c.f. RO30165469
        Nota contabila
        31.08.2026
        Nr. crt. Explicatie Cont debitor Cont creditor Suma Nr. doc Tip
        1 Cheltuieli cu salariile 641 421 66 660.00 91 Salarii
        2 Retineri - salariati 421 % 26 225.00 91 Salarii
        3 Impozit - salarii 444 3 095.00 91 Salarii
        4 CAS individuala - salariati 4315 16 521.00 91 Salarii
        5 CASS individuala - salariati 4316 6 609.00 91 Salarii
        6 CAM 6461 436 1 486.00 91 Salarii
        """.components(separatedBy: .newlines)
        let parsed = HRJournalNotePDFParser.parse(lines: lines, defaultNoteNumber: 1)
        let simple = HRPayrollNCUniqueAccountCollector.exportEntries(parsed.entries, style: .simple)
        #expect(simple.count == 10)
        let collected = HRPayrollNCUniqueAccountCollector.exportEntries(parsed.entries, style: .collectedUniqueAccount)
        #expect(collected.map(\.account) == [
            "641", "421",
            "421", "444", "444", "4311",
            "421", "4315", "4315", "4311",
            "421", "4316", "4316", "4311",
            "6461", "436", "436", "4311"
        ])
        #expect(collected.map(\.debitCredit) == [
            "D", "C",
            "D", "C", "D", "C",
            "D", "C", "D", "C",
            "D", "C", "D", "C",
            "D", "C", "D", "C"
        ])
        #expect(collected.map(\.amount) == [
            66660, 66660,
            3095, 3095, 3095, 3095,
            16521, 16521, 16521, 16521,
            6609, 6609, 6609, 6609,
            1486, 1486, 1486, 1486
        ])
        let debit = collected.filter { $0.debitCredit == "D" }.reduce(0) { $0 + $1.amount }
        let credit = collected.filter { $0.debitCredit == "C" }.reduce(0) { $0 + $1.amount }
        #expect(debit == credit)
        #expect(!collected.contains { $0.account == "4311" && $0.debitCredit == "D" })
    }
}
